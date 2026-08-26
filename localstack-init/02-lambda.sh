#!/bin/bash
# 02-lambda.sh — crea la Lambda s3-processor y su trigger S3→Lambda
# Ejecutar DENTRO del contenedor de LocalStack (docker exec localstack bash /opt/init-scripts/02-lambda.sh)
# Requiere: 01-setup.sh ejecutado antes (bucket orders-bucket ya existe)
set -e

echo "==> [Lambda] Creando rol IAM lambda-role"
awslocal iam create-role --role-name lambda-role \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{"Effect":"Allow",
      "Principal":{"Service":"lambda.amazonaws.com"},
      "Action":"sts:AssumeRole"}]}' > /dev/null \
  || echo "    (rol ya existía)"

echo "==> [Lambda] Creando función s3-processor (nodejs20.x)"
awslocal lambda create-function \
  --function-name s3-processor \
  --runtime nodejs20.x \
  --handler index.handler \
  --zip-file fileb:///opt/lambda-s3-processor/function.zip \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --environment "Variables={AWS_ENDPOINT_URL=http://localstack:4566}" > /dev/null \
  || echo "    (función ya existía)"

echo "==> [Lambda] Permitiendo que S3 invoque la función"
awslocal lambda add-permission \
  --function-name s3-processor \
  --statement-id s3-invoke \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::orders-bucket > /dev/null \
  || echo "    (permiso ya existía)"

echo "==> [Lambda] Configurando trigger S3 orders-bucket → s3-processor (ObjectCreated:Put)"
awslocal s3api put-bucket-notification-configuration \
  --bucket orders-bucket \
  --notification-configuration '{
    "LambdaFunctionConfigurations": [{
      "LambdaFunctionArn": "arn:aws:lambda:us-east-1:000000000000:function:s3-processor",
      "Events": ["s3:ObjectCreated:Put"]
    }]}' > /dev/null \
  || echo "    (configuración ya existía)"

echo "==> [Lambda] Lista: s3-processor"
