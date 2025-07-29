package com.dolijo.moring.security.exception;

import io.jsonwebtoken.JwtException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

@ControllerAdvice
public class JwtExceptionHandler {
    @ExceptionHandler(JwtException.class)
    public ResponseEntity<?> handleJwtExpired(JwtException ex) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
    }
}
