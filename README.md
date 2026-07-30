# Symptom Tracker — Flutter ML Client

This is the full Flutter application from
`JeremiahJacob261/symptom_tracker`, upgraded to work with the
Symptom2Disease NLP backend.

The app keeps its existing features:

- symptom, pain, mood, temperature, note, and photo logging;
- local SQLite/offline storage and Supabase synchronization;
- history, statistics, medications, appointments, CSV, and PDF export;
- deterministic urgent-care screening;
- Cloudflare-generated historical health insights.

It now also sends a newly saved symptom description to the deployed Random
Forest FastAPI classifier. The app defaults to this Modal endpoint:

```text
https://akpomoshix--symptom-tracker-ml-web.modal.run
```

`SYMPTOM_MODEL_API_URL` can override that endpoint for a local backend or a
future deployment. The response UI supports
the exact `/predict` contract from the ML package:

- possible pattern match and confidence;
- top alternatives;
- low-confidence rejection;
- urgent flags;
- selected model name;
- a permanent medical disclaimer.

The classifier is educational and is not a medical diagnosis.

## 1. Prepare the backend

Use `symptom_tracker_ml_upgrade/ml_backend` from the accompanying ML upgrade
package:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python scripts/download_dataset.py
python scripts/train.py
uvicorn app.main:app --reload
```

Confirm that these endpoints work:

```text
GET  /health
POST /predict
```

For a phone or release build, deploy the backend to an HTTPS URL such as Modal.
Do not use `localhost` from a physical phone because it points back to the
phone, not to your computer.

If the Flutter app is deployed on the web, the FastAPI backend must allow that
website's origin with `CORSMiddleware`. Native Android, iOS, Windows, Linux, and
macOS builds do not use browser CORS enforcement.

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://your-flutter-web-app.example.com"],
    allow_methods=["GET", "POST"],
    allow_headers=["content-type"],
)
```

## 2. Run the Flutter app

```bash
flutter pub get

flutter run \
  --dart-define=SYMPTOM_MODEL_API_URL=https://your-ml-backend.example.com
```

The `--dart-define` flag is optional for the checked-in application because the
Modal production endpoint is already configured. Use it only to override the
production service.

For the Android emulator with a local backend, use the host alias:

```bash
flutter run \
  --dart-define=SYMPTOM_MODEL_API_URL=http://10.0.2.2:8000
```

For a USB-connected Android phone, expose the local port and use loopback:

```bash
adb reverse tcp:8000 tcp:8000
flutter run \
  --dart-define=SYMPTOM_MODEL_API_URL=http://127.0.0.1:8000
```

Use HTTPS for production. Android release builds may reject cleartext HTTP.

## 3. Build the APK

```bash
flutter clean
flutter pub get
flutter build apk --release \
  --dart-define=SYMPTOM_MODEL_API_URL=https://your-ml-backend.example.com
```

The APK will be written to:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 4. Test

```bash
flutter analyze
flutter test
```

The classifier integration is implemented in:

```text
lib/services/disease_prediction_service.dart
```

It preserves a path prefix in the configured backend URL, applies a 45-second
timeout, parses FastAPI error messages, and closes its HTTP client after use.

## Modal deployment

The checked-in Random Forest API is deployed as the `symptom-tracker-ml` Modal
app in the `akpomoshix` workspace. Its production endpoint is:

```text
https://akpomoshix--symptom-tracker-ml-web.modal.run
```

To update the model service after changing `ml_backend/app` or retraining the
production artifact, activate the intended Modal profile and deploy from the
backend directory:

```bash
cd ml_backend
./.venv/bin/python -m modal profile activate new-account
./.venv/bin/python -m modal deploy modal_app.py --name symptom-tracker-ml
```

## Safety order

Every entry follows this order:

1. Run the app's deterministic urgent-care rules.
2. Save the entry locally and queue normal synchronization.
3. If safe and enough symptom text exists, call the NLP classifier.
4. Continue using the existing Cloudflare service for readable historical
   insights.

The UI deliberately says that a description is “similar to patterns associated
with” a condition. It never tells the user that they have a condition.
