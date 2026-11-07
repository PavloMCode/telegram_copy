package com.example.demo.auth;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.time.Clock;
import java.time.Instant;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.mongodb.core.FindAndModifyOptions;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.index.IndexOperations;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.security.crypto.password.Pbkdf2PasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

class AuthServiceTest {
    MongoTemplate mongo;
    AuthMailSender mail;
    AuthService auth;
    MockHttpSession session;
    AtomicReference<Instant> now;
    AtomicReference<String> code;

    @BeforeEach
    void setup() {
        mongo = mock(MongoTemplate.class);
        mail = mock(AuthMailSender.class);
        session = new MockHttpSession();
        now = new AtomicReference<>(Instant.parse("2026-10-28T12:00:00Z"));
        code = new AtomicReference<>();
        Clock clock = mock(Clock.class);
        when(clock.instant()).thenAnswer(invocation -> now.get());
        when(mongo.indexOps(any(Class.class))).thenReturn(mock(IndexOperations.class));
        when(mongo.findAndModify(any(Query.class), any(Update.class), any(FindAndModifyOptions.class), eq(AuthService.RateLimit.class)))
                .thenAnswer(invocation -> { var rate = new AuthService.RateLimit(); rate.count = 1; return rate; });
        when(mongo.insert(any(AuthAccount.class))).thenAnswer(invocation -> {
            AuthAccount account = invocation.getArgument(0);
            account.id = "account-id";
            return account;
        });
        doAnswer(invocation -> { code.set(invocation.getArgument(1)); return null; })
                .when(mail).sendCode(anyString(), anyString());
        auth = new AuthService(mongo, mail, clock);
    }

    AuthService.Challenge register() {
        return auth.register(new AuthService.Registration("+380 99 123 45 67", "Anna", " Anna@Example.com ", "a-long-test-password"), "127.0.0.1", session);
    }

    @Test
    void registrationHashesSecretsAndOnlyCreatesAccountAfterSingleUseCode() {
        var challenge = register();
        assertEquals("anna@example.com", challenge.email());
        assertTrue(code.get().matches("[0-9]{6}"));
        verify(mongo, never()).insert(any(AuthAccount.class));
        assertThrows(ResponseStatusException.class, () -> auth.me(session));
        var pending = (AuthService.Pending) session.getAttribute("auth.pending");
        assertNotEquals(code.get(), pending.codeHash);
        assertNotEquals("a-long-test-password", pending.account.passwordHash);
        assertTrue(Pbkdf2PasswordEncoder.defaultsForSpringSecurity_v5_8().matches("a-long-test-password", pending.account.passwordHash));
        var profile = auth.verify(new AuthService.Verification(challenge.challengeId(), code.get()), session);
        assertEquals("+380991234567", profile.phone());
        assertEquals("account-id", session.getAttribute("auth.account"));
        assertThrows(ResponseStatusException.class,
                () -> auth.verify(new AuthService.Verification(challenge.challengeId(), code.get()), session));
        verify(mongo, times(1)).insert(any(AuthAccount.class));
    }

    @Test
    void fiveWrongAttemptsBlockEvenTheCorrectCode() {
        var challenge = register();
        for (int i = 0; i < 5; i++) {
            assertThrows(ResponseStatusException.class,
                    () -> auth.verify(new AuthService.Verification(challenge.challengeId(), "bad"), session));
        }
        assertThrows(ResponseStatusException.class,
                () -> auth.verify(new AuthService.Verification(challenge.challengeId(), code.get()), session));
        assertNull(session.getAttribute("auth.account"));
    }

    @Test
    void expiredCodeCannotCreateSession() {
        var challenge = register();
        now.set(now.get().plusSeconds(301));
        assertThrows(ResponseStatusException.class,
                () -> auth.verify(new AuthService.Verification(challenge.challengeId(), code.get()), session));
        assertNull(session.getAttribute("auth.account"));
    }

    @Test
    void resendEnforcesCooldownAndInvalidatesPreviousChallenge() {
        var first = register();
        String oldCode = code.get();
        assertEquals(HttpStatus.TOO_MANY_REQUESTS,
                assertThrows(ResponseStatusException.class, () -> auth.resend("127.0.0.1", session)).getStatusCode());
        now.set(now.get().plusSeconds(61));
        var next = auth.resend("127.0.0.1", session);
        assertNotEquals(first.challengeId(), next.challengeId());
        assertThrows(ResponseStatusException.class,
                () -> auth.verify(new AuthService.Verification(first.challengeId(), oldCode), session));
        assertEquals("Anna", auth.verify(new AuthService.Verification(next.challengeId(), code.get()), session).name());
    }

    @Test
    void emailFailureDoesNotLeaveUsableChallengeOrAccount() {
        doThrow(new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE)).when(mail).sendCode(anyString(), anyString());
        assertThrows(ResponseStatusException.class, this::register);
        assertNull(session.getAttribute("auth.pending"));
        assertNull(session.getAttribute("auth.account"));
        verify(mongo, never()).insert(any(AuthAccount.class));
    }

    @Test
    void wrongPasswordDoesNotSendEmail() {
        var account = new AuthAccount();
        account.id = "existing-id";
        account.passwordHash = Pbkdf2PasswordEncoder.defaultsForSpringSecurity_v5_8().encode("a-long-test-password");
        when(mongo.findOne(any(Query.class), eq(AuthAccount.class))).thenReturn(account);
        assertThrows(ResponseStatusException.class,
                () -> auth.login(new AuthService.Login("anna@example.com", "wrong-password"), "127.0.0.1", session));
        verifyNoInteractions(mail);
        assertNull(session.getAttribute("auth.account"));
    }

    @Test
    void loginStillRequiresSecondFactorAndDoesNotCreateAnotherAccount() {
        var account = new AuthAccount();
        account.id = "existing-id";
        account.email = "anna@example.com";
        account.phone = "+380991234567";
        account.name = "Anna";
        account.passwordHash = Pbkdf2PasswordEncoder.defaultsForSpringSecurity_v5_8().encode("a-long-test-password");
        when(mongo.findOne(any(Query.class), eq(AuthAccount.class))).thenReturn(account);
        var challenge = auth.login(new AuthService.Login(account.email, "a-long-test-password"), "127.0.0.1", session);
        assertNull(session.getAttribute("auth.account"));
        auth.verify(new AuthService.Verification(challenge.challengeId(), code.get()), session);
        assertEquals("existing-id", session.getAttribute("auth.account"));
        verify(mongo, never()).insert(any(AuthAccount.class));
    }

    @Test
    void rateLimitStopsEmailAndPasswordWork() {
        var rate = new AuthService.RateLimit(); rate.count = 100;
        when(mongo.findAndModify(any(Query.class), any(Update.class), any(FindAndModifyOptions.class), eq(AuthService.RateLimit.class))).thenReturn(rate);
        assertEquals(HttpStatus.TOO_MANY_REQUESTS,
                assertThrows(ResponseStatusException.class, this::register).getStatusCode());
        verifyNoInteractions(mail);
    }
}
