from pathlib import Path

import modal

ROOT = Path(__file__).resolve().parent

image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install_from_requirements("requirements.txt")
    .add_local_dir(ROOT / "app", remote_path="/root/app")
    # The API only loads the selected production pipeline and metadata. Keeping
    # the unused candidate models out of the image makes deployment faster.
    .add_local_file(
        ROOT / "models" / "production_model.joblib",
        remote_path="/root/models/production_model.joblib",
    )
    .add_local_file(
        ROOT / "models" / "metadata.json",
        remote_path="/root/models/metadata.json",
    )
)

app = modal.App("symptom-tracker-ml")

@app.function(image=image, cpu=2.0, memory=4096, scaledown_window=30)
@modal.asgi_app()
def web():
    import sys
    sys.path.insert(0, "/root")
    from app.main import app as fastapi_app
    return fastapi_app
