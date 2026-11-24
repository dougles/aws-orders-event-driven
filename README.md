# AWS Learning Two — Spring Boot + LocalStack

Proyecto de aprendizaje: arquitectura de eventos con AWS emulado con **LocalStack**.

```
POST /orders ──► order-service (8080) ──┬──► SNS orders-topic ──► SQS orders-queue ──► notification-service (8081)
                                        └──► S3 orders-bucket ──► Lambda s3-processor (Node 20)
```

| Módulo | Rol | Stack |
|---|---|---|
| `order-service` | API REST `POST /orders`; publica el evento a SNS y sube el JSON a S3 | Spring Boot 4.1.0, Java 25, Spring Cloud AWS 4.0.0 |
| `notification-service` | Consume `orders-queue` (SQS) y "envía" la notificación; producto `FAIL` → DLQ | Spring Boot 4.1.0, Java 25, Spring Cloud AWS 4.0.0 |
| `lambda-s3-processor` | Se dispara con `s3:ObjectCreated:Put`, lee el JSON y lo procesa | Node 20, `@aws-sdk/client-s3` |
| `localstack-init` | Scripts que crean la infraestructura (bucket, colas, topic, Lambda) | awslocal |

Flujo: `POST /orders` → SNS → SQS (raw delivery) → consumido por notification-service. En paralelo, S3 → Lambda. Si el producto es `"FAIL"`, el listener lanza una excepción y el mensaje va a `orders-dlq` tras 3 reintentos (redrive policy).

## Requisitos

- Docker Desktop (con el motor Linux corriendo)
- Java 25 (LTS) y Maven 3.9+ (para compilar los servicios)
- Node 24 (solo para regenerar `function.zip`, opcional)

## Puesta en marcha

```bash
# 1. Levantar LocalStack (imagen community 3.8.1)
docker compose up -d
# Esperar a que esté healthy:
docker ps --filter name=localstack

# 2. Empaquetar la Lambda (el zip no se versiona en git)
cd lambda-s3-processor && zip function.zip index.mjs
# En Windows sin zip:  tar -a -c -f function.zip index.mjs
cd ..

# 3. Inicializar la infraestructura (dentro del contenedor)
docker exec localstack bash /opt/init-scripts/01-setup.sh     # S3 + SQS + DLQ + SNS + suscripción
docker exec localstack bash /opt/init-scripts/02-lambda.sh    # rol + función Lambda + trigger S3→Lambda

# 4. Compilar y arrancar los servicios (dos terminales)
cd order-service        && mvn -DskipTests package && java -jar target/order-service-0.0.1-SNAPSHOT.jar        # :8080
cd notification-service && mvn -DskipTests package && java -jar target/notification-service-0.0.1-SNAPSHOT.jar  # :8081
```

> El estado de LocalStack se persiste en el volumen `localstack-data`; si arrancas de cero (`docker compose down -v`), vuelve a ejecutar los scripts del paso 3.

## Probar el flujo

```bash
# Orden normal → SNS → SQS → notificación + S3 → Lambda
curl -X POST http://localhost:8080/orders \
  -H "Content-Type: application/json" \
  -d '{"product":"Laptop","quantity":2,"price":999.99}'

# Ver la notificación: en la consola donde corre notification-service verás
#   "Recibido de SQS: OrderEvent[...]" y "Notificación enviada para orden ..."

# Ver la Lambda
docker exec localstack awslocal logs describe-log-groups --log-group-name /aws/lambda/s3-processor

# Orden que falla → DLQ después de 3 reintentos (~90 s)
curl -X POST http://localhost:8080/orders \
  -H "Content-Type: application/json" \
  -d '{"product":"FAIL","quantity":1,"price":10}'

docker exec localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/orders-dlq \
  --attribute-names ApproximateNumberOfMessages
```

## Notas y advertencias

- **`localstack/localstack:latest` ya no sirve gratis**: la imagen `latest` (2026.x) exige `LOCALSTACK_AUTH_TOKEN` (licencia Pro). Por eso `docker-compose.yml` fija la imagen comunitaria **`localstack/localstack:3.8.1`**.
- **Evento del trigger**: LocalStack 3.8.1 rechaza `s3:ObjectCreated:*` con "Unable to validate the following destination configurations"; hay que usar el evento concreto `s3:ObjectCreated:Put` (ya corregido en `02-lambda.sh`).
- **Configuración duplicada**: cada servicio tiene `application.properties` **y** `application.yml`; al coexistir, el `.properties` gana y `spring.application.name` queda como `demo`. Se recomienda quedarse con el `.yml`.
- **AWS real**: hay que quitar `endpoint`/`credentials` de `application.yml`, añadir la Queue Policy SNS→SQS y usar el evento `s3:ObjectCreated:*` en AWS de verdad.
