# SensAI — Real Sensor Integration Guide

## What Was Added

### 🎙️ Microphone (Noise Level)
- Package: `noise_meter ^6.0.0`
- Reads real-time ambient noise in **decibels (dB)**
- Thresholds: Quiet <65 dB | Moderate 65–85 dB | Loud >85 dB
- Permission required: `RECORD_AUDIO`

### 💡 Light Sensor
- Package: `light ^2.0.0`
- Reads ambient light in **lux** via the device's built-in light sensor
- Thresholds: Dim <300 lux | Normal 300–800 lux | Bright >800 lux
- Falls back gracefully if hardware unavailable (emulators)

### 📳 Accelerometer (Motion)
- Package: `sensors_plus ^5.0.1`
- Measures **motion intensity** (deviation from gravitational rest)
- Rolling average over 10 samples for smooth readings
- Detects: Still | Moving | High motion (hyperactivity indicator)

### 📷 Camera (Facial + Crowd Analysis)
- Package: `camera ^0.11.0` + `google_ml_kit ^0.19.0`
- Uses **front camera** + ML Kit Face Detection (on-device, private)
- Detects:
  - **Facial Tension** — derived from eye openness, smile probability, head tilt
  - **Eye Strain** — eyes <40% open = squinting/strain indicator
  - **Head Movement** — irregular angles suggest avoidance behavior
  - **Crowd Density** — face count as proxy for environmental stress
- Runs every **2 seconds** to preserve battery
- Optional live preview toggle in the AppBar

### 🧠 Backend (FastAPI v2)
- Accepts the enriched payload: `noise, light, heartRate, time, motionIntensity, facialTension, crowdDensity`
- Computes a **composite risk score (0–100)** combining all sensors
- ML model prediction acts as a baseline; composite overrides when signals are strong
- New `/health` endpoint for connectivity checks

## Android Permissions Added
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

## Running on a Physical Device
In `lib/services/api_service.dart`, change:
```dart
static const String _baseUrl = 'http://127.0.0.1:8000';
```
to your machine's LAN IP:
```dart
static const String _baseUrl = 'http://192.168.x.x:8000';
```

## Offline Mode
If the FastAPI backend is unreachable, the app automatically falls back to a
rule-based risk classifier using the sensor readings — so the app remains
functional without a server.
