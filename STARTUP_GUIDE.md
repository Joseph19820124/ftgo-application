# FTGO 微服务启动指南

## 快速启动（推荐）

使用项目提供的简化命令，自动处理启动顺序：

```bash
# 启动所有服务（基础设施 + 应用服务）
./gradlew :composeUp

# 仅启动基础设施服务（MySQL, Kafka 等）
./gradlew infrastructureComposeUp

# 停止所有服务
./gradlew :composeDown
```

## 手动启动顺序

如需手动控制启动顺序，请按以下层级依次启动：

### 第1层：基础设施组件（必须最先启动）
```bash
docker-compose up -d zookeeper mysql dynamodblocal
```

**服务说明：**
- `zookeeper`: Kafka 协调服务
- `mysql`: 主数据库，包含所有服务的数据库模式
- `dynamodblocal`: DynamoDB 本地实例，用于订单历史查询

### 第2层：消息与存储初始化
```bash
docker-compose up -d kafka dynamodblocal-init zipkin
```

**服务说明：**
- `kafka`: 事件流平台，依赖 zookeeper
- `dynamodblocal-init`: 初始化 DynamoDB 表结构
- `zipkin`: 分布式链路追踪服务（独立启动）

### 第3层：CDC服务
```bash
docker-compose up -d cdc-service
```

**服务说明：**
- `cdc-service`: 变更数据捕获服务，监控数据库变更并发布事件
- 依赖：mysql + kafka

### 第4层：核心业务服务（可并行启动）
```bash
docker-compose up -d \
  ftgo-consumer-service \
  ftgo-order-service \
  ftgo-kitchen-service \
  ftgo-restaurant-service \
  ftgo-accounting-service \
  ftgo-delivery-service
```

**服务说明：**
- `ftgo-consumer-service`: 客户管理服务
- `ftgo-order-service`: 订单管理服务（Saga 协调器）
- `ftgo-kitchen-service`: 厨房操作服务
- `ftgo-restaurant-service`: 餐厅和菜单管理
- `ftgo-accounting-service`: 财务服务（事件溯源）
- `ftgo-delivery-service`: 配送物流服务
- 依赖：mysql + kafka + cdc-service

### 第5层：查询服务
```bash
docker-compose up -d ftgo-order-history-service
```

**服务说明：**
- `ftgo-order-history-service`: CQRS 读模型，提供订单历史查询
- 依赖：kafka + cdc-service + dynamodb

### 第6层：API网关（最后启动）
```bash
docker-compose up -d ftgo-api-gateway
```

**服务说明：**
- `ftgo-api-gateway`: HTTP API 网关，外部客户端访问入口
- 依赖：所有业务服务就绪

## 服务端点

启动完成后，可通过以下 URL 访问各服务：

- **API Gateway**: http://localhost:8087
- **Consumer Service**: http://localhost:8081/swagger-ui/index.html
- **Order Service**: http://localhost:8082/swagger-ui/index.html
- **Kitchen Service**: http://localhost:8083/swagger-ui/index.html
- **Restaurant Service**: http://localhost:8084/swagger-ui/index.html
- **Accounting Service**: http://localhost:8085/swagger-ui/index.html
- **Order History Service**: http://localhost:8086/swagger-ui/index.html
- **Delivery Service**: http://localhost:8089/swagger-ui/index.html
- **Zipkin UI**: http://localhost:9411
- **Kafka UI**: http://localhost:9088

## 关键启动依赖

```
zookeeper ──┐
            ├─► kafka ──┐
mysql ──────┼──────────┼─► cdc-service ──┐
            │          │                 ├─► 业务服务
dynamodb ───┼─► init ──┘                 │
            │                            ├─► order-history
zipkin ─────┘                            │
                                         └─► api-gateway
```

## 故障排除

### 常见问题

1. **端口冲突**: 确保 3306(MySQL), 9092(Kafka), 2181(Zookeeper) 等端口未被占用
2. **内存不足**: 建议至少 8GB RAM，可调整各服务的 JAVA_OPTS
3. **启动超时**: CDC 服务需要等待数据库完全就绪，可能需要额外等待时间

### 有用命令

```bash
# 查看服务状态
docker-compose ps

# 查看服务日志
docker-compose logs <service-name>

# 重启特定服务
./build-and-restart-service.sh <service-name>

# 等待所有服务启动完成
./wait-for-services.sh

# 打开所有 Swagger UI
./open-swagger-uis.sh
```

## 环境变量

启动前可设置以下环境变量：

```bash
# Docker 主机 IP（如果 Docker 不在本地）
export DOCKER_HOST_IP=<your-docker-host-ip>

# AWS 相关（用于 DynamoDB）
export AWS_REGION=us-west-2
export AWS_ACCESS_KEY_ID=id_key
export AWS_SECRET_ACCESS_KEY=access_key
```