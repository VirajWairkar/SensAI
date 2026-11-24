import pandas as pd
import joblib

from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier


def train_model():

    df = pd.read_csv("sensai_cleaned.csv")

    expected_features = [
        "Noise",
        "Light",
        "HeartRate",
        "MotionIntensity",
        "CrowdDensity",
    ]

    missing = [f for f in expected_features if f not in df.columns]
    if missing:
        raise ValueError(
            "Missing required columns in sensai_cleaned.csv: " + ", ".join(missing)
        )

    print(df.head())

    X = df[expected_features]
    y = df["Risk"]


    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=0.20,
        random_state=42
    )

    model = RandomForestClassifier(
        n_estimators=300,
        max_depth=12,
        random_state=42
    )

    model.fit(X_train, y_train)

    # Save trained model
    joblib.dump(
        model,
        "sensai_model.pkl"
    )

    print("\nModel saved as sensai_model.pkl")

    return model, X_train, X_test, y_train, y_test