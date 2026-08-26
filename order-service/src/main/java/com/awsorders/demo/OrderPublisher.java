package com.awsorders.demo;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import io.awspring.cloud.s3.S3Template;
import io.awspring.cloud.sns.core.SnsTemplate;
import tools.jackson.databind.ObjectMapper;

// OrderPublisher.java — publica a SNS y sube a S3
@Service
public class OrderPublisher {

    private static final Logger log = LoggerFactory.getLogger(OrderPublisher.class);

    private final SnsTemplate snsTemplate; // autoconfigurado por el starter
    private final S3Template s3Template; // idem
    private final ObjectMapper objectMapper;

    @Value("${app.sns.orders-topic-arn}")
    private String topicArn;

    @Value("${app.s3.bucket}")
    private String bucket;

    public OrderPublisher(SnsTemplate snsTemplate, S3Template s3Template,
            ObjectMapper objectMapper) {
        this.snsTemplate = snsTemplate;
        this.s3Template = s3Template;
        this.objectMapper = objectMapper;
    }

    public void publish(OrderEvent event) {
        // 1. SNS: serializa el payload a JSON automáticamente
        snsTemplate.convertAndSend(topicArn, event);
        log.info("Publicado a SNS: {}", event.orderId());

        // 2. S3: guarda el JSON (esto disparará la Lambda)
        
            String json = objectMapper.writeValueAsString(event);
            String key = "orders/%s.json".formatted(event.orderId());
            s3Template.upload(bucket, key,
                    new ByteArrayInputStream(json.getBytes(StandardCharsets.UTF_8)));
            log.info("Subido a S3: s3://{}/{}", bucket, key);
        
    }
}