package com.awsorders.demo;

import java.math.BigDecimal;
import java.time.Instant;

public record OrderEvent(String orderId, String product, int quantity,
                         BigDecimal price, Instant createdAt) {}
