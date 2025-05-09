#!/bin/bash

SERVICE_NAME="maximum-billing-alert"
REGION="asia-east1"

RUN_URL=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format 'value(status.url)')

if [[ -z "$RUN_URL" ]]; then
  echo "❌ Cloud Run URL을 가져올 수 없습니다. 종료합니다."
  exit 1
fi

echo "🌐 배포된 Cloud Run URL: $RUN_URL"


# 직접 인라인 메시지 작성 → Base64 인코딩 포함 → gcloud
echo "🚀 gcloud pubsub 메시지 게시..."
gcloud pubsub topics publish billing-alerts \
  --message="$(echo '{
    "budgetDisplayName": "test-budget",
    "alertThresholdExceeded": 1.0,
    "costAmount": 100.01,
    "budgetAmount": 100.00,
    "currencyCode": "USD"
  }' | base64)"

echo "🌐 curl로 Cloud Run 직접 호출..."
curl -X POST "$RUN_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "data": "'$(echo '{
        "budgetDisplayName": "test-budget",
        "alertThresholdExceeded": 1.0,
        "costAmount": 100.01,
        "budgetAmount": 100.00,
        "currencyCode": "USD"
      }' | base64)'"
    }
  }'

echo -e "\n✅ 테스트 완료"