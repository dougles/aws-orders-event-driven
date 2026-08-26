#!/bin/bash
set -e
ENDPOINT="--endpoint-url=http://localhost:4566"
REGION="us-east-1"
# Dentro del contenedor de init usa awslocal; fuera, aws $ENDPOINT

# ── 1. S3 bucket ──────────────────────────────────────────────
awslocal s3api create-bucket --bucket orders-bucket

# ── 2. SQS: DLQ primero (la cola principal la referencia) ─────
awslocal sqs create-queue --queue-name orders-dlq
DLQ_ARN=$(awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/orders-dlq \
  --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)

# ── 3. SQS: cola principal con redrive policy → DLQ ───────────
# maxReceiveCount=3: al 4to intento fallido el mensaje va a la DLQ
awslocal sqs create-queue --queue-name orders-queue \
  --attributes "{
    \"RedrivePolicy\": \"{\\\"deadLetterTargetArn\\\":\\\"${DLQ_ARN}\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\",
    \"VisibilityTimeout\": \"30\"
  }"
QUEUE_ARN=$(awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/orders-queue \
  --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)

# ── 4. SNS topic ──────────────────────────────────────────────
TOPIC_ARN=$(awslocal sns create-topic --name orders-topic \
  --query 'TopicArn' --output text)

# ── 5. Suscripción SNS → SQS ──────────────────────────────────
# RawMessageDelivery=true: SQS recibe el JSON limpio, sin el envelope de SNS
awslocal sns subscribe --topic-arn "$TOPIC_ARN" \
  --protocol sqs --notification-endpoint "$QUEUE_ARN" \
  --attributes RawMessageDelivery=true

# En AWS real además necesitas una Queue Policy que permita a SNS escribir
# en la cola (sqs:SendMessage con Condition aws:SourceArn = topic).
# LocalStack no la exige; el JSON está en la sección 9 de la guía.

echo "Infra lista: TOPIC=$TOPIC_ARN QUEUE=$QUEUE_ARN DLQ=$DLQ_ARN"