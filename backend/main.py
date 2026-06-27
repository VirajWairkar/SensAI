"""
SensAI FastAPI Backend
Accepts enriched sensor data (noise, light, heartRate, motionIntensity,
crowdDensity) and returns a risk prediction.
"""


from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional
import joblib
import os

app = FastAPI(title="SensAI API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load ML model
_model_path = os.path.join(os.path.dirname(__file__), "sensai_model.pkl")
model = joblib.load(_model_path)


class SensorData(BaseModel):
    """Enriched sensor payload from Flutter app."""
    noise: int = Field(..., ge=0, le=120, description="Noise level in dB")
    light: int = Field(..., ge=0, description="Ambient light in Lux")
    heartRate: int = Field(..., ge=30, le=220, description="Heart rate in BPM")
    time: int = Field(..., ge=0, le=23, description="Hour of day (0-23)")
    # New fields from real sensors/camera (optional for backwards compat)
    motionIntensity: Optional[float] = Field(default=0.5, ge=0, le=10)
    crowdDensity: Optional[int] = Field(default=0, ge=0)



class PredictionResponse(BaseModel):
    risk: str
    score: float
    details: dict


RISK_MAP = {0: "Low", 1: "Medium", 2: "High"}


def compute_composite_score(data: SensorData) -> float:
    """
    Composite risk score (0-100) combining ML prediction confidence
    with real sensor signals from microphone, camera, and accelerometer.
    """
    score = 0.0

    # Noise contribution (max 30pts)
    if data.noise > 85:
        score += 30
    elif data.noise > 70:
        score += 20
    elif data.noise > 55:
        score += 10

    # Light contribution (max 20pts)
    if data.light > 1000:
        score += 20
    elif data.light > 600:
        score += 12
    elif data.light > 300:
        score += 5

    # Heart rate contribution (max 20pts)
    if data.heartRate > 110:
        score += 20
    elif data.heartRate > 90:
        score += 12
    elif data.heartRate > 80:
        score += 5

    # Motion intensity contribution (max 15pts)
    motion = data.motionIntensity or 0
    if motion > 5:
        score += 15
    elif motion > 2:
        score += 8
    elif motion > 0.5:
        score += 3

    # Crowd density contribution (max 5pts)

    crowd = data.crowdDensity or 0
    if crowd > 4:
        score += 5
    elif crowd > 2:
        score += 3
    elif crowd > 0:
        score += 1

    return min(score, 100.0)


@app.get("/")
def home():
    return {"message": "SensAI Model Loaded Successfully", "version": "2.0.0"}


@app.post("/predict", response_model=PredictionResponse)
def predict(data: SensorData):
    # Original ML model prediction (uses 4 core features)
    ml_prediction = model.predict([[
        data.noise,
        data.light,
        data.heartRate,
        data.time,
    ]])[0]

    ml_risk = RISK_MAP.get(int(ml_prediction), "Low")

    # Composite score from all sensors
    composite = compute_composite_score(data)

    # Override ML result with composite if significantly higher
    if composite >= 70:
        final_risk = "High"
    elif composite >= 40:
        # Take the higher of ML and composite
        if ml_risk == "High":
            final_risk = "High"
        else:
            final_risk = "Medium"
    else:
        final_risk = ml_risk if ml_risk == "Low" else "Medium"

    return PredictionResponse(
        risk=final_risk,
        score=round(composite, 1),
        details={
            "ml_prediction": ml_risk,
            "noise_db": data.noise,
            "light_lux": data.light,
            "heart_rate": data.heartRate,
            "motion_intensity": data.motionIntensity,
            "crowd_density": data.crowdDensity,

            "composite_score": round(composite, 1),
        },
    )


@app.get("/health")
def health():
    return {"status": "ok"}
