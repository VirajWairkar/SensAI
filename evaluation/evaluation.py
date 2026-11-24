import pandas as pd
import joblib

from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix
)

from train_model import train_model


# Train model and get data
model, X_train, X_test, y_train, y_test = train_model()


# Predictions on test set
y_pred = model.predict(X_test)


# Accuracy
print("\nAccuracy:")
print(
    accuracy_score(
        y_test,
        y_pred
    )
)


# Classification Report
print("\nClassification Report:")
print(
    classification_report(
        y_test,
        y_pred
    )
)


# Confusion Matrix
print("\nConfusion Matrix:")
print(
    confusion_matrix(
        y_test,
        y_pred
    )
)


# =========================
# Feature Importance
# =========================

importance = pd.DataFrame(
    {
        "Feature": X_train.columns,
        "Importance": model.feature_importances_
    }
)

print("\nFeature Importance:")

print(
    importance.sort_values(
        by="Importance",
        ascending=False
    )
)


# =========================
# Load Saved Model
# =========================

loaded_model = joblib.load(
    "sensai_model.pkl"
)

print("\nSaved model loaded successfully.")


# =========================
# Test Prediction
# =========================

sample = pd.DataFrame(
    [[100, 950, 135, 4.2, 9]],
    columns=[
        "Noise",
        "Light",
        "HeartRate",
        "MotionIntensity",
        "CrowdDensity",
    ],
)

prediction = loaded_model.predict(sample)


print("\nPrediction Code:")
print(prediction)


# =========================
# Convert to Human Label
# =========================

risk_map = {
    0: "Low",
    1: "Medium",
    2: "High"
}

print("\nPredicted Risk Level:")
print(
    risk_map[
        prediction[0]
    ]
)