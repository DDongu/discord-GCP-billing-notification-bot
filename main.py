import base64
import json
import requests
import os
from flask import Flask, request
from dotenv import load_dotenv
from datetime import datetime, timezone, timedelta

# 🔽 .env 파일 불러오기
load_dotenv()

DISCORD_WEBHOOK_URL = os.getenv("DISCORD_WEBHOOK_URL")

# 시간대 설정 (예: 한국이면 +9)
LOCAL_TIMEZONE = timezone(timedelta(hours=9))  # Asia/Seoul 기준

app = Flask(__name__)

@app.route("/", methods=["POST"])
def notify_discord():
    try:
        envelope = request.get_json(silent=True)
        if not envelope or "message" not in envelope:
            print("[WARN] Empty or malformed Pub/Sub message. Ignoring.")
            return "Ignored: no message", 200

        message = envelope["message"]
        data_encoded = message.get("data", "")
        if not data_encoded:
            print("[WARN] No data in message. Ignoring.")
            return "Ignored: no data", 200

        data = json.loads(base64.b64decode(data_encoded).decode("utf-8"))

    except Exception as e:
        print(f"[ERROR] Failed to parse request: {e}")
        # Pub/Sub 재시도 방지를 위해 200 OK 반환
        return "Ignored malformed request", 200

    cost_amount = data.get("costAmount", "N/A")
    budget_amount = data.get("budgetAmount", "N/A")
    budget_name = data.get("budgetDisplayName", "이름 없음")

    try:
        cost_amount_formatted = f"{float(cost_amount):,.0f}원"
        budget_amount_formatted = f"{float(budget_amount):,.0f}원"
    except:
        cost_amount_formatted = f"{cost_amount}원"
        budget_amount_formatted = f"{budget_amount}원"

    now = datetime.now(LOCAL_TIMEZONE)

    if "alertThresholdExceeded" in data:
        threshold = float(data["alertThresholdExceeded"]) * 100
        alert_message = (
            f"⚠️ **GCP 비용 경고** [{budget_name}]⚠️\n"
            f"[**GCP 예산**] ❗ **${threshold:.0f}% 초과** ❗\n"
            f"현재 사용액: `{cost_amount_formatted}`  / 예산 한도: `{budget_amount_formatted}`"
        )

    else:
        # 수정된 코드: 09:00 ~ 09:59 사이만 허용
        if not (now.hour == 9 and now.minute <= 59):
            print(f"[INFO] Skipped periodic alert at {now.strftime('%H:%M')}")
            return "Skipped due to time filter", 200

        alert_message = (
            f"📊 **GCP 사용량 리포트** [{budget_name}]\n"
            f"💰 현재 비용: **`{cost_amount_formatted}`** / 예산: **`{budget_amount_formatted}`**"
        )
        
    try:
        requests.post(DISCORD_WEBHOOK_URL, json={"content": alert_message})
        print("[INFO] Notification sent to Discord.")
        return "OK", 200
    except Exception as e:
        print(f"[ERROR] Failed to send Discord message: {e}")
        return "Failed to send Discord message", 500