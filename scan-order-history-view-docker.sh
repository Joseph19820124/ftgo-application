#!/usr/bin/env bash

# 使用 Docker 容器中的 AWS CLI 查询 DynamoDB
docker run --rm -it --network ftgo-application_default \
  -e AWS_ACCESS_KEY_ID=id_key \
  -e AWS_SECRET_ACCESS_KEY=access_key \
  -e AWS_DEFAULT_REGION=us-west-2 \
  amazon/aws-cli:latest \
  dynamodb scan --table-name ftgo-order-history --endpoint-url http://dynamodblocal:8000