package com.example.demo.auth;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import org.springframework.mail.MailAuthenticationException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.web.server.ResponseStatusException;

class AuthMailSenderTest {
    @Test
    void unconfiguredSenderFailsWithoutSending() {
        var mail = mock(JavaMailSender.class);
        var sender = new AuthMailSender(mail, "");
        assertEquals(HttpStatus.SERVICE_UNAVAILABLE,
                assertThrows(ResponseStatusException.class, () -> sender.sendCode("anna@example.com", "123456")).getStatusCode());
        verifyNoInteractions(mail);
    }

    @Test
    void smtpFailureDoesNotExposeDiagnostics() {
        var mail = mock(JavaMailSender.class);
        doThrow(new MailAuthenticationException("private SMTP diagnostic")).when(mail).send(any(SimpleMailMessage.class));
        var failure = assertThrows(ResponseStatusException.class,
                () -> new AuthMailSender(mail, "sender@gmail.com").sendCode("anna@example.com", "123456"));
        assertFalse(failure.getReason().contains("private"));
    }

    @Test
    void messageIsAddressedToRecipientWithExpiringCode() {
        var mail = mock(JavaMailSender.class);
        new AuthMailSender(mail, "sender@gmail.com").sendCode("anna@example.com", "123456");
        var message = ArgumentCaptor.forClass(SimpleMailMessage.class);
        verify(mail).send(message.capture());
        assertArrayEquals(new String[]{"anna@example.com"}, message.getValue().getTo());
        assertEquals("sender@gmail.com", message.getValue().getFrom());
        assertTrue(message.getValue().getText().contains("123456"));
        assertTrue(message.getValue().getText().contains("5 minutes"));
    }
}
