package com.example.demo.auth;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

@Component
public class AuthMailSender {
    private final JavaMailSender mail;
    private final String sender;

    public AuthMailSender(JavaMailSender mail, @Value("${spring.mail.username:}") String sender) {
        this.mail = mail;
        this.sender = sender;
    }

    public void sendCode(String email, String code) {
        if (sender.isBlank()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Email delivery is not configured. Contact the administrator.");
        }
        var message = new SimpleMailMessage();
        message.setFrom(sender);
        message.setTo(email);
        message.setSubject("Your Messenger verification code");
        message.setText("Your code is: " + code
                + "\n\nIt expires in 5 minutes. Do not share this code."
                + "\nIf you did not request it, ignore this message.");
        try {
            mail.send(message);
        } catch (org.springframework.mail.MailException failure) {
            // Do not return SMTP diagnostics or credentials to the client.
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Could not send the email. Please try again later.");
        }
    }
}
