from __future__ import annotations

import json
from pathlib import Path

import joblib
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .safety import urgent_flags
from .schemas import Alternative, PredictionRequest, PredictionResponse

ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT / "models" / "production_model.joblib"
METADATA_PATH = ROOT / "models" / "metadata.json"
LOW_CONFIDENCE_THRESHOLD = 0.60

app = FastAPI(
    title="Symptom Tracker NLP Classifier",
    version="1.0.0",
    description=(
        "Educational symptom-text classification service. "
        "It does not provide medical diagnoses."
    ),
)

# The deployed classifier is consumed by Flutter web as well as native apps.
# It receives no credentials and persists no request data, so it can expose
# this public inference contract cross-origin.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["content-type"],
)

_model = None
_metadata: dict = {}

@app.on_event("startup")
def load_model() -> None:
    global _model, _metadata
    if not MODEL_PATH.exists():
        raise RuntimeError(
            "Model is missing. Run scripts/download_dataset.py and scripts/train.py."
        )
    _model = joblib.load(MODEL_PATH)
    if METADATA_PATH.exists():
        _metadata = json.loads(METADATA_PATH.read_text(encoding="utf-8"))

@app.get("/health")
def health() -> dict:
    return {
        "ok": _model is not None,
        "selected_model": _metadata.get("selected_model"),
        "dataset": _metadata.get("dataset"),
        "classes": _metadata.get("class_count"),
    }

@app.post("/predict", response_model=PredictionResponse)
def predict(payload: PredictionRequest) -> PredictionResponse:
    if _model is None:
        raise HTTPException(status_code=503, detail="Model is not loaded.")

    flags = urgent_flags(
        payload.text,
        payload.pain_level,
        payload.temperature_celsius,
    )

    probabilities = _model.predict_proba([payload.text])[0]
    classes = _model.classes_
    ranked = sorted(
        zip(classes, probabilities),
        key=lambda pair: float(pair[1]),
        reverse=True,
    )[: payload.top_k]

    best_label, best_probability = ranked[0]
    confidence = float(best_probability)
    low_confidence = confidence < LOW_CONFIDENCE_THRESHOLD

    return PredictionResponse(
        possible_match=None if low_confidence else str(best_label),
        confidence=confidence,
        alternatives=[
            Alternative(condition=str(label), probability=float(probability))
            for label, probability in ranked
        ],
        low_confidence=low_confidence,
        urgent=bool(flags),
        urgent_flags=flags,
        model=str(_metadata.get("selected_model", "unknown")),
        disclaimer=(
            "This result is an educational pattern match, not a diagnosis. "
            "Consult a qualified healthcare professional. Seek urgent care "
            "for severe, sudden, or worsening symptoms."
        ),
    )
