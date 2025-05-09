package com.example.service;

import io.confluent.examples.avro.Address;
import io.confluent.examples.avro.Order;
import io.confluent.examples.avro.OrderItem;
import com.github.javafaker.Faker;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

@Service
public class OrderService {

    private final Faker faker = new Faker();

    @Autowired
    private KafkaTemplate<String, Order> kafkaTemplate;

    @Value("${spring.kafka.topic.orders}")
    private String ordersTopic;

    public void generateAndSendOrder() {
        Order order = createSampleOrder();
        kafkaTemplate.send(ordersTopic, order.getId(), order);
    }

    private Order createSampleOrder() {
        List<OrderItem> items = new ArrayList<>();
        int numberOfItems = ThreadLocalRandom.current().nextInt(1, 6); // 1-5 items per order
        double subtotal = 0.0;

        for (int i = 0; i < numberOfItems; i++) {
            OrderItem item = createOrderItem();
            items.add(item);
            subtotal += item.getTotalPrice();
        }

        double tax = subtotal * 0.08; // 8% tax
        double total = subtotal + tax;

        return Order.newBuilder()
                .setId(UUID.randomUUID().toString())
                .setCustomerId("CUST-" + faker.number().numberBetween(1000, 9999))
                .setSubtotal(subtotal)
                .setTax(tax)
                .setTotal(total)
                .setCreatedAt(Instant.now().toEpochMilli())
                .setItems(items)
                .setShippingAddress(createAddress())
                .build();
    }

    private OrderItem createOrderItem() {
        int quantity = ThreadLocalRandom.current().nextInt(1, 6); // 1-5 items
        double unitPrice = faker.number().randomDouble(2, 10, 100);
        double totalPrice = unitPrice * quantity;

        return OrderItem.newBuilder()
                .setProductId("PROD-" + faker.number().numberBetween(1000, 9999))
                .setProductName(faker.commerce().productName())
                .setQuantity(quantity)
                .setUnitPrice(unitPrice)
                .setTotalPrice(totalPrice)
                .build();
    }

    private Address createAddress() {
        return Address.newBuilder()
                .setStreet(faker.address().streetAddress())
                .setCity(faker.address().city())
                .setState(faker.address().stateAbbr())
                .setPostalCode(faker.address().zipCode())
                .setCountry("USA")
                .build();
    }
} 