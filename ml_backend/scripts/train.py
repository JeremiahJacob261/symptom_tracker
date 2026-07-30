from __future__ import annotations

import json
from pathlib import Path

import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
)
from sklearn.model_selection import train_test_split
from sklearn.naive_bayes import MultinomialNB
from sklearn.pipeline import Pipeline
from sklearn.tree import DecisionTreeClassifier

ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "data" / "Symptom2Disease.csv"
MODELS_DIR = ROOT / "models"
REPORTS_DIR = ROOT / "reports"
RANDOM_STATE = 42

def load_dataset() -> pd.DataFrame:
    if not DATA_PATH.exists():
        raise FileNotFoundError(
            f"{DATA_PATH} does not exist. Run scripts/download_dataset.py first."
        )

    frame = pd.read_csv(DATA_PATH)
    unnamed = [column for column in frame.columns if column.lower().startswith("unnamed")]
    if unnamed:
        frame = frame.drop(columns=unnamed)

    required = {"label", "text"}
    missing = required.difference(frame.columns)
    if missing:
        raise ValueError(f"Dataset is missing columns: {sorted(missing)}")

    frame = frame[["label", "text"]].dropna()
    frame["label"] = frame["label"].astype(str).str.strip()
    frame["text"] = frame["text"].astype(str).str.strip()
    frame = frame[(frame["label"] != "") & (frame["text"] != "")]
    return frame.drop_duplicates().reset_index(drop=True)

def make_vectorizer() -> TfidfVectorizer:
    return TfidfVectorizer(
        lowercase=True,
        strip_accents="unicode",
        ngram_range=(1, 2),
        min_df=2,
        max_df=0.98,
        sublinear_tf=True,
        max_features=12000,
    )

def build_models() -> dict[str, Pipeline]:
    return {
        "decision_tree": Pipeline(
            [
                ("tfidf", make_vectorizer()),
                (
                    "classifier",
                    DecisionTreeClassifier(
                        max_depth=80,
                        min_samples_leaf=2,
                        class_weight="balanced",
                        random_state=RANDOM_STATE,
                    ),
                ),
            ]
        ),
        "naive_bayes": Pipeline(
            [
                ("tfidf", make_vectorizer()),
                ("classifier", MultinomialNB(alpha=0.25)),
            ]
        ),
        "random_forest": Pipeline(
            [
                ("tfidf", make_vectorizer()),
                (
                    "classifier",
                    RandomForestClassifier(
                        n_estimators=700,
                        max_features="sqrt",
                        min_samples_leaf=1,
                        class_weight="balanced_subsample",
                        random_state=RANDOM_STATE,
                        n_jobs=-1,
                    ),
                ),
            ]
        ),
    }

def main() -> None:
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    frame = load_dataset()
    X_train, X_test, y_train, y_test = train_test_split(
        frame["text"],
        frame["label"],
        test_size=0.20,
        random_state=RANDOM_STATE,
        stratify=frame["label"],
    )

    summary: dict[str, dict[str, float | int]] = {}
    best_name = ""
    best_macro_f1 = -1.0

    for name, pipeline in build_models().items():
        print(f"Training {name}...")
        pipeline.fit(X_train, y_train)
        predictions = pipeline.predict(X_test)

        accuracy = float(accuracy_score(y_test, predictions))
        macro_f1 = float(f1_score(y_test, predictions, average="macro"))
        weighted_f1 = float(f1_score(y_test, predictions, average="weighted"))

        report = classification_report(
            y_test,
            predictions,
            output_dict=True,
            zero_division=0,
        )
        matrix = confusion_matrix(y_test, predictions, labels=pipeline.classes_)

        joblib.dump(pipeline, MODELS_DIR / f"{name}.joblib")
        (REPORTS_DIR / f"{name}_classification_report.json").write_text(
            json.dumps(report, indent=2),
            encoding="utf-8",
        )
        pd.DataFrame(
            matrix,
            index=pipeline.classes_,
            columns=pipeline.classes_,
        ).to_csv(REPORTS_DIR / f"{name}_confusion_matrix.csv")

        summary[name] = {
            "accuracy": accuracy,
            "macro_f1": macro_f1,
            "weighted_f1": weighted_f1,
            "train_rows": int(len(X_train)),
            "test_rows": int(len(X_test)),
            "classes": int(frame["label"].nunique()),
        }

        if macro_f1 > best_macro_f1:
            best_name = name
            best_macro_f1 = macro_f1

    best_model = joblib.load(MODELS_DIR / f"{best_name}.joblib")
    joblib.dump(best_model, MODELS_DIR / "production_model.joblib")

    metadata = {
        "dataset": "Symptom2Disease",
        "dataset_url": (
            "https://www.kaggle.com/datasets/niyarrbarman/symptom2disease"
        ),
        "dataset_rows_after_cleaning": int(len(frame)),
        "class_count": int(frame["label"].nunique()),
        "random_state": RANDOM_STATE,
        "selection_metric": "macro_f1",
        "selected_model": best_name,
        "models": summary,
        "warning": (
            "This educational dataset does not establish clinical diagnostic validity. "
            "Outputs must be displayed as possible pattern matches, not diagnoses."
        ),
    }
    (MODELS_DIR / "metadata.json").write_text(
        json.dumps(metadata, indent=2),
        encoding="utf-8",
    )

    print(json.dumps(metadata, indent=2))

if __name__ == "__main__":
    main()
