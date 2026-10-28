package com.example.demo.auth;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping(value = "/api/auth", headers = "X-Messenger-Client=mobile")
public class AuthController {
    private final AuthService auth;
    public AuthController(AuthService auth) { this.auth = auth; }

    @PostMapping("/register")
    public ResponseEntity<AuthService.Challenge> register(@RequestBody AuthService.Registration body, HttpServletRequest request) {
        request.getSession();
        request.changeSessionId();
        return noCache(auth.register(body, request.getRemoteAddr(), request.getSession()));
    }

    @PostMapping("/login")
    public ResponseEntity<AuthService.Challenge> login(@RequestBody AuthService.Login body, HttpServletRequest request) {
        request.getSession();
        request.changeSessionId();
        return noCache(auth.login(body, request.getRemoteAddr(), request.getSession()));
    }

    @PostMapping("/verify")
    public ResponseEntity<AuthService.Profile> verify(@RequestBody AuthService.Verification body, HttpServletRequest request) {
        var result = auth.verify(body, request.getSession());
        request.changeSessionId();
        return noCache(result);
    }

    @PostMapping("/resend")
    public ResponseEntity<AuthService.Challenge> resend(HttpServletRequest request) {
        return noCache(auth.resend(request.getRemoteAddr(), request.getSession()));
    }

    @GetMapping("/me")
    public ResponseEntity<AuthService.Profile> me(HttpServletRequest request) {
        return noCache(auth.me(request.getSession()));
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(HttpServletRequest request) {
        var session = request.getSession(false);
        if (session != null) session.invalidate();
        return ResponseEntity.noContent().cacheControl(CacheControl.noStore()).build();
    }

    private <T> ResponseEntity<T> noCache(T body) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(body);
    }
}
