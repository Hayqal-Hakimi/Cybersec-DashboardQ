import json
import random
import time
from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

# ------------------------------------------------------------------
# PRODUCTION ORIGINS (tambah CloudFront URL lepas deploy)
# ------------------------------------------------------------------
PRODUCTION_ORIGINS: list[str] = [
    # Development
    "http://localhost:8000",
    "http://127.0.0.1:8000",
    "http://localhost:5173",  # Vite dev
    # Production — ganti dengan CloudFront domain lepas deploy
    # "https://dxxxxxxxxxxxx.cloudfront.net",
]

app = FastAPI(title="CyberSec Threat Analyzer API", version="4.2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=PRODUCTION_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------------------------------------------------------
# Serve frontend static files untuk local dev
# ------------------------------------------------------------------
import os
FRONTEND_DIR = os.path.join(os.path.dirname(__file__), "..", "frontend")
if os.path.isdir(FRONTEND_DIR):
    app.mount("/", StaticFiles(directory=FRONTEND_DIR, html=True), name="frontend")

TRIGGER_WORDS: list[str] = [
    "win",
    "click",
    "money",
    "free",
    "congratulations",
    "prize",
    "urgent",
    "act now",
    "limited time",
    "password",
    "verify your account",
    "suspended",
    "lottery",
]


class AnalyzeRequest(BaseModel):
    text: str
    model: str = "Llama-3-CyberSec (8B)"


class RiskDetail(BaseModel):
    level: str
    value: int


class RiskBreakdown(BaseModel):
    metadata_spoofing: RiskDetail
    phishing_links: RiskDetail
    suspicious_tone: RiskDetail


class AnalyzeResponse(BaseModel):
    threat_score: int
    threat_type: str
    risk_breakdown: dict[str, dict[str, str | int]]
    inference_time_ms: int
    timestamp: str


def _contains_trigger(text: str) -> bool:
    lower_text = text.lower()
    return any(word in lower_text for word in TRIGGER_WORDS)


@app.post("/analyze", response_model=AnalyzeResponse)
async def analyze(request: AnalyzeRequest) -> AnalyzeResponse:
    start = time.perf_counter()

    # Simulate inference latency
    time.sleep(0.1)

    is_threat = _contains_trigger(request.text)

    if is_threat:
        threat_score = random.randint(90, 98)
        threat_type = "SCAM"
        risk_breakdown: dict[str, dict[str, str | int]] = {
            "metadata_spoofing": {"level": "High", "value": random.randint(75, 90)},
            "phishing_links": {"level": "Critical", "value": random.randint(85, 98)},
            "suspicious_tone": {"level": "Elevated", "value": random.randint(70, 85)},
        }
    else:
        threat_score = random.randint(5, 15)
        threat_type = "SAFE"
        risk_breakdown = {
            "metadata_spoofing": {"level": "Low", "value": random.randint(5, 15)},
            "phishing_links": {"level": "Minimal", "value": random.randint(2, 10)},
            "suspicious_tone": {"level": "Low", "value": random.randint(5, 12)},
        }

    elapsed_ms = int((time.perf_counter() - start) * 1000)
    ts = datetime.now(timezone.utc).isoformat()

    # Structured JSON log
    log_entry = {
        "timestamp": ts,
        "input_type": request.text[:50],
        "model": request.model,
        "result": {
            "threat_score": threat_score,
            "threat_type": threat_type,
        },
    }
    print(json.dumps(log_entry, indent=2))

    return AnalyzeResponse(
        threat_score=threat_score,
        threat_type=threat_type,
        risk_breakdown=risk_breakdown,
        inference_time_ms=elapsed_ms,
        timestamp=ts,
    )


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "healthy", "version": "v4.2.0"}