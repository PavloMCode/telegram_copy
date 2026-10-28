package com.example.demo.auth;

import jakarta.servlet.http.HttpSession;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.Clock;
import java.util.Date;
import java.util.Locale;
import java.util.UUID;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.FindAndModifyOptions;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.index.Index;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.Pbkdf2PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AuthService {
    private static final String PENDING = "auth.pending";
    private static final String ACCOUNT = "auth.account";
    private final MongoTemplate mongo;
    private final AuthMailSender mail;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();
    private final Pbkdf2PasswordEncoder encoder = Pbkdf2PasswordEncoder.defaultsForSpringSecurity_v5_8();
    private final String dummyHash = encoder.encode(UUID.randomUUID().toString());
    private volatile boolean indexed;

    @Autowired
    public AuthService(MongoTemplate mongo, AuthMailSender mail) {
        this(mongo, mail, Clock.systemUTC());
    }

    AuthService(MongoTemplate mongo, AuthMailSender mail, Clock clock) {
        this.mongo = mongo;
        this.mail = mail;
        this.clock = clock;
    }

    public record Registration(String phone, String name, String email, String password) {}
    public record Login(String email, String password) {}
    public record Verification(String challengeId, String code) {}
    public record Challenge(String challengeId, String email, int expiresIn, int resendAfter) {}
    public record Profile(String name, String phone, String email) {}

    static final class Pending {
        final String id = UUID.randomUUID().toString();
        final AuthAccount account;
        final String codeHash;
        final Instant expiresAt;
        final Instant resendAt;
        int attempts;
        Pending(AuthAccount account, String codeHash, Instant now) {
            this.account = account;
            this.codeHash = codeHash;
            this.expiresAt = now.plusSeconds(300);
            this.resendAt = now.plusSeconds(60);
        }
    }

    @Document(collection = "auth_rate_limits")
    static class RateLimit {
        @Id public String id;
        public int count;
        public Date expiresAt;
    }

    // Explicit indexes make uniqueness effective independently of auto-index settings.
    private synchronized void ensureIndexes() {
        if (indexed) return;
        mongo.indexOps(AuthAccount.class).ensureIndex(new Index().on("email", Sort.Direction.ASC).unique());
        mongo.indexOps(AuthAccount.class).ensureIndex(new Index().on("phone", Sort.Direction.ASC).unique());
        mongo.indexOps(RateLimit.class).ensureIndex(new Index().on("expiresAt", Sort.Direction.ASC).expire(0));
        indexed = true;
    }

    private void limit(String key, int max) {
        ensureIndexes();
        long bucket = Instant.now(clock).getEpochSecond() / 900;
        var query = Query.query(Criteria.where("_id").is(key + ":" + bucket));
        var update = new Update().inc("count", 1)
                .setOnInsert("expiresAt", Date.from(Instant.ofEpochSecond((bucket + 2) * 900)));
        var result = mongo.findAndModify(query, update,
                FindAndModifyOptions.options().upsert(true).returnNew(true), RateLimit.class);
        if (result == null || result.count > max) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
                    "Too many attempts. Please try again in 15 minutes.");
        }
    }

    private String email(String value) {
        String result = value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
        if (result.length() > 254 || !result.matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enter a valid email address.");
        }
        return result;
    }

    public Challenge register(Registration input, String ip, HttpSession session) {
        String email = email(input.email());
        String phone = input.phone() == null ? "" : input.phone().replaceAll("[ ()-]", "");
        String name = input.name() == null ? "" : input.name().trim();
        if (!phone.matches("^\\+[1-9][0-9]{6,14}$") || name.isBlank() || name.length() > 129
                || input.password() == null || input.password().length() < 12 || input.password().length() > 128) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Check your name, phone and password (12–128 characters).");
        }
        limit("register-ip:" + ip, 10);
        limit("mail:" + email, 5);
        if (mongo.exists(Query.query(new Criteria().orOperator(
                Criteria.where("email").is(email), Criteria.where("phone").is(phone))), AuthAccount.class)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "An account already exists. Please sign in.");
        }
        var account = new AuthAccount();
        account.email = email;
        account.phone = phone;
        account.name = name;
        account.passwordHash = encoder.encode(input.password());
        return issue(account, session);
    }

    public Challenge login(Login input, String ip, HttpSession session) {
        String email = email(input.email());
        limit("login-ip:" + ip, 30);
        limit("login-email:" + email, 10);
        var account = mongo.findOne(Query.query(Criteria.where("email").is(email)), AuthAccount.class);
        String password = input.password();
        if (password == null || password.length() > 128) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid email or password.");
        }
        boolean valid = encoder.matches(password, account == null ? dummyHash : account.passwordHash);
        if (account == null || !valid) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid email or password.");
        }
        limit("mail:" + email, 5);
        return issue(account, session);
    }

    private Challenge issue(AuthAccount account, HttpSession session) {
        synchronized (session) {
            var previous = (Pending) session.getAttribute(PENDING);
            if (previous != null && previous.resendAt.isAfter(Instant.now(clock))) {
                throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "Wait 60 seconds before requesting another code.");
            }
            String code = String.format(Locale.ROOT, "%06d", random.nextInt(1_000_000));
            var pending = new Pending(account, encoder.encode(code), Instant.now(clock));
            mail.sendCode(account.email, code);
            session.removeAttribute(ACCOUNT);
            session.setAttribute(PENDING, pending);
            return new Challenge(pending.id, account.email, 300, 60);
        }
    }

    public Challenge resend(String ip, HttpSession session) {
        synchronized (session) {
            Pending pending = pending(session);
            if (pending.resendAt.isAfter(Instant.now(clock))) {
                throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "Wait 60 seconds before requesting another code.");
            }
            limit("resend-ip:" + ip, 10);
            limit("mail:" + pending.account.email, 5);
            return issue(pending.account, session);
        }
    }

    private Pending pending(HttpSession session) {
        var pending = (Pending) session.getAttribute(PENDING);
        if (pending == null || !pending.expiresAt.isAfter(Instant.now(clock)) || pending.attempts >= 5) {
            session.removeAttribute(PENDING);
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Code expired or attempt limit reached. Sign in or register again.");
        }
        return pending;
    }

    public Profile verify(Verification input, HttpSession session) {
        synchronized (session) {
            var pending = pending(session);
            pending.attempts++;
            if (!pending.id.equals(input.challengeId()) || input.code() == null
                    || !input.code().matches("[0-9]{6}") || !encoder.matches(input.code(), pending.codeHash)) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid verification code.");
            }
            session.removeAttribute(PENDING); // A code is consumed once, before account/session creation.
            var account = pending.account;
            if (account.id == null) {
                try {
                    mongo.insert(account);
                } catch (DuplicateKeyException duplicate) {
                    throw new ResponseStatusException(HttpStatus.CONFLICT, "An account already exists. Please sign in.");
                }
            }
            session.setAttribute(ACCOUNT, account.id);
            return new Profile(account.name, account.phone, account.email);
        }
    }

    public Profile me(HttpSession session) {
        var id = (String) session.getAttribute(ACCOUNT);
        var account = id == null ? null : mongo.findById(id, AuthAccount.class);
        if (account == null) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in.");
        return new Profile(account.name, account.phone, account.email);
    }
}

