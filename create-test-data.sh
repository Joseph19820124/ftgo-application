#!/bin/bash

# FTGO 测试数据创建脚本
# 按顺序创建：消费者 → 餐厅 → 订单

set -e  # 遇到错误时退出

echo "🚀 开始创建 FTGO 测试数据..."

# 检查服务是否运行
echo "📋 检查服务状态..."
curl -s http://localhost:8081/actuator/health > /dev/null || { echo "❌ Consumer Service 未运行"; exit 1; }
curl -s http://localhost:8084/actuator/health > /dev/null || { echo "❌ Restaurant Service 未运行"; exit 1; }
curl -s http://localhost:8087/actuator/health > /dev/null || { echo "❌ API Gateway 未运行"; exit 1; }

echo "✅ 所有服务正常运行"

# 1. 创建消费者
echo ""
echo "👤 创建消费者..."
CONSUMER_RESPONSE=$(curl -s -X POST http://localhost:8081/consumers \
  -H "Content-Type: application/json" \
  -d '{
    "name": {
      "firstName": "John",
      "lastName": "Doe"
    }
  }')

echo "消费者响应: $CONSUMER_RESPONSE"

# 提取消费者ID
if [[ $CONSUMER_RESPONSE =~ \"consumerId\":([0-9]+) ]]; then
    CONSUMER_ID=${BASH_REMATCH[1]}
    echo "✅ 消费者创建成功，ID: $CONSUMER_ID"
else
    echo "❌ 消费者创建失败"
    exit 1
fi

# 2. 创建餐厅
echo ""
echo "🍕 创建餐厅..."
RESTAURANT_RESPONSE=$(curl -s -X POST http://localhost:8084/restaurants \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Pizza Palace",
    "address": {
      "street1": "123 Main St",
      "street2": "",
      "city": "San Francisco",
      "state": "CA",
      "zip": "94102"
    },
    "menu": {
      "menuItems": [
        {
          "id": "pizza-margherita",
          "name": "Margherita Pizza",
          "price": "12.99"
        },
        {
          "id": "pizza-pepperoni",
          "name": "Pepperoni Pizza",
          "price": "14.99"
        },
        {
          "id": "pizza-hawaiian",
          "name": "Hawaiian Pizza",
          "price": "13.99"
        }
      ]
    }
  }')

echo "餐厅响应: $RESTAURANT_RESPONSE"

# 提取餐厅ID
if [[ $RESTAURANT_RESPONSE =~ \"id\":([0-9]+) ]]; then
    RESTAURANT_ID=${BASH_REMATCH[1]}
    echo "✅ 餐厅创建成功，ID: $RESTAURANT_ID"
else
    echo "❌ 餐厅创建失败"
    exit 1
fi

# 3. 等待几秒确保数据同步
echo ""
echo "⏳ 等待数据同步..."
sleep 3

# 4. 创建订单
echo ""
echo "📦 创建订单..."
ORDER_RESPONSE=$(curl -s -X POST http://localhost:8087/orders \
  -H "Content-Type: application/json" \
  -d "{
    \"consumerId\": $CONSUMER_ID,
    \"restaurantId\": $RESTAURANT_ID,
    \"deliveryTime\": \"2024-12-25T19:00:00\",
    \"deliveryAddress\": {
      \"street1\": \"456 Oak Ave\",
      \"street2\": \"Apt 2B\",
      \"city\": \"San Francisco\",
      \"state\": \"CA\",
      \"zip\": \"94105\"
    },
    \"lineItems\": [
      {
        \"menuItemId\": \"pizza-margherita\",
        \"quantity\": 2
      },
      {
        \"menuItemId\": \"pizza-pepperoni\",
        \"quantity\": 1
      }
    ]
  }")

echo "订单响应: $ORDER_RESPONSE"

# 提取订单ID
if [[ $ORDER_RESPONSE =~ \"orderId\":([0-9]+) ]]; then
    ORDER_ID=${BASH_REMATCH[1]}
    echo "✅ 订单创建成功，ID: $ORDER_ID"
else
    echo "❌ 订单创建失败"
    echo "错误详情: $ORDER_RESPONSE"
    exit 1
fi

# 5. 等待 Saga 处理完成
echo ""
echo "⏳ 等待 Saga 处理订单..."
sleep 5

# 6. 验证数据
echo ""
echo "🔍 验证创建的数据..."

echo "查看消费者信息:"
curl -s http://localhost:8081/consumers/$CONSUMER_ID | jq '.' 2>/dev/null || curl -s http://localhost:8081/consumers/$CONSUMER_ID

echo ""
echo "查看餐厅信息:"
curl -s http://localhost:8084/restaurants/$RESTAURANT_ID | jq '.' 2>/dev/null || curl -s http://localhost:8084/restaurants/$RESTAURANT_ID

echo ""
echo "查看订单信息:"
curl -s http://localhost:8087/orders/$ORDER_ID | jq '.' 2>/dev/null || curl -s http://localhost:8087/orders/$ORDER_ID

# 7. 查看订单历史
echo ""
echo "📊 查看订单历史 (DynamoDB)..."
if [ -f "./scan-order-history-view-docker.sh" ]; then
    ./scan-order-history-view-docker.sh
else
    echo "⚠️  订单历史查询脚本不存在，请手动查询"
fi

echo ""
echo "🎉 测试数据创建完成！"
echo "📋 创建的数据:"
echo "   - 消费者 ID: $CONSUMER_ID (John Doe)"
echo "   - 餐厅 ID: $RESTAURANT_ID (Pizza Palace)"
echo "   - 订单 ID: $ORDER_ID"
echo ""
echo "🔗 访问链接:"
echo "   - 消费者: http://localhost:8081/consumers/$CONSUMER_ID"
echo "   - 餐厅: http://localhost:8084/restaurants/$RESTAURANT_ID"
echo "   - 订单: http://localhost:8087/orders/$ORDER_ID"
echo "   - API Gateway: http://localhost:8087"