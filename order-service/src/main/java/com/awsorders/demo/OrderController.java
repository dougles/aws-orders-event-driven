package com.awsorders.demo;

import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;
import java.time.Instant;
import java.util.UUID;
import java.math.BigDecimal;

// OrderController.java
@RestController
@RequestMapping("/orders")
public class OrderController {

    private final OrderPublisher publisher;

    public OrderController(OrderPublisher publisher) {
        this.publisher = publisher;
    }

    @PostMapping
    public ResponseEntity<OrderEvent> create(@RequestBody CreateOrderRequest req) {
        var event = new OrderEvent(UUID.randomUUID().toString(),
                req.product(), req.quantity(), req.price(), Instant.now());
        publisher.publish(event);
        return ResponseEntity.accepted().body(event);
    }

    public record CreateOrderRequest(String product, int quantity, BigDecimal price) {
    }
}