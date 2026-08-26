package com.notification.demo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import io.awspring.cloud.sqs.annotation.SqsListener;
import io.awspring.cloud.sqs.annotation.SqsListenerAcknowledgementMode;

@Component
public class OrderListener {

    private static final Logger log = LoggerFactory.getLogger(OrderListener.class);

    @SqsListener(value = "orders-queue", acknowledgementMode = SqsListenerAcknowledgementMode.ON_SUCCESS)
    public void onOrder(OrderEvent event) {
        log.info("Recibido de SQS: {}", event);

        // Simular fallo para probar la DLQ:
        if ("FAIL".equalsIgnoreCase(event.product())) {
            throw new IllegalStateException("Fallo simulado para " + event.orderId());
        }

        log.info("Notificación enviada para orden {}", event.orderId());
    }
}