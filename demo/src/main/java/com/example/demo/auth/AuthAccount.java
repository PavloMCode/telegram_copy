package com.example.demo.auth;

import org.springframework.data.annotation.Id;
import com.fasterxml.jackson.annotation.JsonIgnore;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "auth_accounts")
public class AuthAccount {
    @Id public String id;
    public String email;
    public String phone;
    public String name;
    @JsonIgnore public String passwordHash;
}
