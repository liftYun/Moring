package com.dolijo.moring.ai.service;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.io.File;
import java.io.FileInputStream;
import java.util.Base64;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
class OcrService {

    public String encodeImageToBase64(String imagePath) throws Exception {
        File file = new File(imagePath);
        FileInputStream imageInFile = new FileInputStream(file);
        byte[] imageData = new byte[(int) file.length()];
        imageInFile.read(imageData);
        imageInFile.close();
        return Base64.getEncoder().encodeToString(imageData);
    }
}
