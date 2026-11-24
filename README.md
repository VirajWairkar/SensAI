# SensAI

AI-powered sensory overload risk prediction with a Flutter Android app, FastAPI backend, and Random Forest training and evaluation pipeline.

## Android APK

[Download the earlier prototype APK](https://drive.google.com/file/d/1vnI1OvmkGfORUqtVM7LqhMrGQcwokZjm/view?usp=drive_link)

This APK was built from an earlier version and may differ from the current source. Access depends on the file's Google Drive sharing permissions.

## Current features

- Microphone noise monitoring in decibels, ambient light readings in lux, and accelerometer motion monitoring with a rolling average.
- On-device camera face counting using Google ML Kit, approximately every two seconds.
- FastAPI classification into Low, Medium, or High risk using a five-feature Random Forest model.
- Rule-based mobile fallback when API requests throw an exception or time out.
- Risk history, high-risk alerts, breathing exercises, and contextual suggestions.

## Model and evaluation

The included `evaluation/sensai_cleaned.csv` contains 10,000 records, with five input features: `Noise`, `Light`, `HeartRate`, `MotionIntensity`, and `CrowdDensity`, plus the `Risk` target.

Training uses 300 Random Forest trees, maximum depth 12, and an 80/20 train/test split with random seed 42. Evaluation prints accuracy, a classification report, a confusion matrix, feature importance, and a sample prediction. Dataset provenance and clinical validation are not documented in this repository.

## Repository layout

- `backend/`: FastAPI service and model artifact.
- `evaluation/`: Dataset, training, and evaluation scripts.
- `sensai_app/`: Flutter application.
- `SENSOR_FEATURES.md`: Historical prototype integration notes.

## Backend setup

From the repository root, with Python and pip installed:

```sh
python -m pip install fastapi uvicorn scikit-learn pandas joblib
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

The backend loads `backend/sensai_model.pkl` at startup. Python dependency versions are not pinned. If the artifact is incompatible with your scikit-learn version, retrain and copy the generated model into the backend directory.

Endpoints: `GET /`, `GET /health`, and `POST /predict`. API documentation: `http://localhost:8000/docs`.

Example prediction payload:

```json
{
  "noise": 75,
  "light": 500,
  "heartRate": 85,
  "motionIntensity": 1.2,
  "crowdDensity": 2
}
```

Accepted ranges: noise 0–120, nonnegative light, heart rate 30–220, motion 0–5, and face count 0–10. Responses contain a risk label and input details, rather than a numerical 0–100 score.

## Mobile setup

Install Flutter with Dart compatible with the `^3.12.0` constraint in `sensai_app/pubspec.yaml`, and configure Android tooling.

Set `_baseUrl` in `sensai_app/lib/services/api_service.dart` to your backend address. For a physical device, use your computer's LAN IP and connect both devices to the same network. The default `127.0.0.1` points to the device itself.

```sh
cd sensai_app
flutter pub get
flutter run
```

Grant microphone and camera permissions. Use a physical Android device with an ambient light sensor for sensor testing.

To build the current source:

```sh
cd sensai_app
flutter build apk --release
```

## Train and evaluate

After installing the Python dependencies, run from the repository root:

```sh
cd evaluation
python evaluation.py
```

This trains and evaluates the model and writes `evaluation/sensai_model.pkl`. Copy it to `backend/sensai_model.pkl` and restart the backend to deploy the updated model. Running `train_model.py` directly does not start training; its function is called by `evaluation.py`.

## Current integration limitations

- Heart rate defaults to 72 BPM. An update method exists, but the app does not connect it to a live heart rate source.
- The dashboard passes noise, light, and heart rate to the API service. Motion and crowd inputs use the service defaults of `0.5` and `0`, despite live motion and face counts being displayed.
- Offline classification uses noise, light, heart rate, and motion, and excludes face count. Non-200 HTTP responses return `Error` instead of invoking fallback.
- If the light sensor is unavailable, the app retains its default light reading.
- Current camera analysis counts faces; it does not compute facial tension, eye strain, or head movement indicators.

## Earlier prototype and research

The linked APK represents an earlier prototype. The project author's research manuscript covers that earlier prototype; the updated five-feature training pipeline is a later development. `SENSOR_FEATURES.md` contains historical notes and is not the current API specification.

## Technologies

Python, FastAPI, pandas, scikit-learn, Random Forest, joblib, Flutter, Dart, Google ML Kit, camera, noise_meter, light, and sensors_plus.
