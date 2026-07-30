from __future__ import annotations

from pydantic import BaseModel, Field

class PredictionRequest(BaseModel):
    text: str = Field(min_length=3, max_length=4000)
    pain_level: int | None = Field(default=None, ge=0, le=10)
    temperature_celsius: float | None = Field(default=None, ge=25, le=45)
    top_k: int = Field(default=3, ge=1, le=5)

class Alternative(BaseModel):
    condition: str
    probability: float

class PredictionResponse(BaseModel):
    possible_match: str | None
    confidence: float
    alternatives: list[Alternative]
    low_confidence: bool
    urgent: bool
    urgent_flags: list[str]
    model: str
    disclaimer: str
