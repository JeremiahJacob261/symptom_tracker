from __future__ import annotations

URGENT_TERMS = {
    "chest pain",
    "difficulty breathing",
    "trouble breathing",
    "shortness of breath",
    "severe bleeding",
    "loss of consciousness",
    "fainted",
    "fainting",
    "face drooping",
    "one sided weakness",
    "one-sided weakness",
    "seizure",
    "suicidal",
    "self harm",
    "self-harm",
}

def urgent_flags(text: str, pain_level: int | None, temperature_celsius: float | None) -> list[str]:
    normalized = text.lower()
    flags: list[str] = []

    if pain_level is not None and pain_level >= 9:
        flags.append("Very high pain was recorded.")

    if temperature_celsius is not None and temperature_celsius >= 39.4:
        flags.append("Very high fever was recorded.")

    for term in sorted(URGENT_TERMS):
        if term in normalized:
            flags.append(f'Urgent symptom language was recorded: "{term}".')

    return flags
