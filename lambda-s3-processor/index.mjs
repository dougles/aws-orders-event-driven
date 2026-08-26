import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";

// Dentro de LocalStack, la Lambda debe hablar con el endpoint interno
const s3 = new S3Client({
    endpoint: process.env.AWS_ENDPOINT_URL || undefined,
    forcePathStyle: true,
});

export const handler = async (event) => {
    for (const record of event.Records) {
        const bucket = record.s3.bucket.name;
        const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, " "));
        console.log(`Procesando s3://${bucket}/${key}`);

        const obj = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
        const body = await obj.Body.transformToString();
        const order = JSON.parse(body);

        console.log(`Orden procesada por Lambda: ${order.orderId} - ${order.product}`);
        // Aquí iría lógica real: generar factura, thumbnail, indexar, etc.
    }
    return { statusCode: 200 };
};