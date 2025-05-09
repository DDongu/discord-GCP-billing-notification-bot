#!/bin/bash

# 로그인 계정의 프로젝트 목록에서 선택하도록 구성
echo "📌 현재 계정으로 접근 가능한 GCP 프로젝트 목록:"
gcloud projects list --format="value(projectId)" | nl

read -p "👉 사용할 프로젝트 번호를 선택하세요: " PROJECT_INDEX
SELECTED_PROJECT_ID=$(gcloud projects list --format="value(projectId)" | sed -n "${PROJECT_INDEX}p")

if [[ -z "$SELECTED_PROJECT_ID" ]]; then
  echo "❌ 잘못된 선택입니다. 스크립트를 종료합니다."
  exit 1
fi

gcloud config set project "$SELECTED_PROJECT_ID"

# --------------------------
# 환경 변수 불러오기
# --------------------------
source .env

# --------------------------
# 기본 변수 설정
# --------------------------
SERVICE_NAME="maximum-billing-alert"
REGION="asia-east1"
TOPIC_NAME="billing-alerts"
SUBSCRIPTION_NAME="billing-sub-to-cloudrun"
PROJECT_ID=$(gcloud config get-value project)

echo "🚀 현재 선택된 프로젝트: $PROJECT_ID"

# --------------------------
# 기존 Cloud Run 서비스 삭제
# --------------------------
echo "🧼 기존 Cloud Run 서비스 확인..."
if gcloud run services describe $SERVICE_NAME --region $REGION &>/dev/null; then
  echo "⚠️  기존 Cloud Run 서비스 '$SERVICE_NAME' 삭제 중..."
  gcloud run services delete $SERVICE_NAME --region $REGION --quiet
else
  echo "✅ 삭제할 기존 서비스 없음."
fi

# --------------------------
# Cloud Run 배포
# --------------------------
echo "🚀 Cloud Run 서비스 배포 중..."
gcloud run deploy $SERVICE_NAME \
  --source . \
  --region $REGION \
  --allow-unauthenticated \
  --quiet

echo "✅ Cloud Run 배포 완료."

# --------------------------
# Cloud Run URL 조회
# --------------------------
echo "🌐 Cloud Run URL 조회 중..."
RUN_URL=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format 'value(status.url)')

if [[ -z "$RUN_URL" ]]; then
  echo "❌ Cloud Run URL을 가져올 수 없습니다. 종료합니다."
  exit 1
fi

echo "🌐 배포된 Cloud Run URL: $RUN_URL"

# --------------------------
# 기존 Pub/Sub 구독 삭제
# --------------------------
echo "🔍 기존 Pub/Sub 구독 확인..."
if gcloud pubsub subscriptions describe $SUBSCRIPTION_NAME &>/dev/null; then
  echo "⚠️  기존 구독 '$SUBSCRIPTION_NAME' 삭제 중..."
  gcloud pubsub subscriptions delete $SUBSCRIPTION_NAME --quiet
else
  echo "✅ 삭제할 기존 구독 없음."
fi

# --------------------------
# Pub/Sub 구독 생성
# --------------------------
echo "🔗 Pub/Sub 구독 생성 중..."
gcloud pubsub subscriptions create $SUBSCRIPTION_NAME \
  --topic=$TOPIC_NAME \
  --push-endpoint="$RUN_URL" \
  --ack-deadline=30

echo "🎉 모든 작업 완료! ✅"