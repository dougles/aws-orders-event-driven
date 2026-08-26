cd lambda-s3-processor
zip function.zip index.mjs

# 1. Rol IAM (LocalStack no valida, pero el parámetro es obligatorio)
awslocal iam create-role --role-name lambda-role \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{"Effect":"Allow",
      "Principal":{"Service":"lambda.amazonaws.com"},
      "Action":"sts:AssumeRole"}]}'

# 2. Crear la función
awslocal lambda create-function \
  --function-name s3-processor \
  --runtime nodejs20.x \
  --handler index.handler \
  --zip-file fileb://function.zip \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --environment "Variables={AWS_ENDPOINT_URL=http://localstack:4566}"

# 3. Permitir que S3 invoque la Lambda (en AWS real es obligatorio)
awslocal lambda add-permission \
  --function-name s3-processor \
  --statement-id s3-invoke \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::orders-bucket

# 4. Configurar el trigger: S3 → Lambda en ObjectCreated
awslocal s3api put-bucket-notification-configuration \
  --bucket orders-bucket \
  --notification-configuration '{
    "LambdaFunctionConfigurations": [{
      "LambdaFunctionArn": "arn:aws:lambda:us-east-1:000000000000:function:s3-processor",
      "Events": ["s3:ObjectCreated:*"]
    }]}'