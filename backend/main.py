"""
SensAI FastAPI Backend
Receives sensor data from Flutter and predicts sensory overload risk.
"""


from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

import joblib
import os

app = FastAPI(
    title="SensAI API",
    version="3.0.0"
)

# -----------------------------
# Enable CORS
# -----------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------------
# Load Trained Model
# -----------------------------
MODEL_PATH = os.path.join(
    os.path.dirname(__file__),
    "sensai_model.pkl"
)

model = joblib.load(MODEL_PATH)

# -----------------------------
# Input Schema
# -----------------------------
class SensorData(BaseModel):

    noise: int = Field(
        ...,
        ge=0,
        le=120,
        description="Noise Level (dB)"
    )

    light: int = Field(
        ...,
        ge=0,
        description="Ambient Light (Lux)"
    )

    heartRate: int = Field(
        ...,
        ge=30,
        le=220,
        description="Heart Rate (BPM)"
    )

    motionIntensity: float = Field(
        ...,
        ge=0,
        le=5,
        description="Motion Intensity"
    )

    crowdDensity: int = Field(
        ...,
        ge=0,
        le=10,
        description="Number of Faces Detected"
    )


# -----------------------------
# Response Schema
# -----------------------------
class PredictionResponse(BaseModel):

    risk: str

    details: dict


RISK_MAP = {
    0: "Low",
    1: "Medium",
    2: "High"
}

# -----------------------------
# Home
# -----------------------------
@app.get("/")
def home():

    return {
        "message": "SensAI API Running",
        "model": "Random Forest",
        "version": "3.0.0"
    }


# -----------------------------
# Prediction
# -----------------------------
@app.post(
    "/predict",
    response_model=PredictionResponse
)
def predict(data: SensorData):

    prediction = model.predict([[
        data.noise,
        data.light,
        data.heartRate,
        data.motionIntensity,
        data.crowdDensity
    ]])[0]

    risk = RISK_MAP[int(prediction)]

    return PredictionResponse(

        risk=risk,

        details={

            "noise": data.noise,

            "light": data.light,

            "heartRate": data.heartRate,

            "motionIntensity": data.motionIntensity,

            "crowdDensity": data.crowdDensity,

            "prediction": risk

        }
    )


# -----------------------------
# Health Check
# -----------------------------
@app.get("/health")
def health():
    
    return {
        "status": "ok"
    }