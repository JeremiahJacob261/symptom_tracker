from pathlib import Path
from urllib.request import urlretrieve

DATA_URL = (
    "https://raw.githubusercontent.com/mistralai/cookbook/"
    "main/data/Symptom2Disease.csv"
)
OUTPUT = Path(__file__).resolve().parents[1] / "data" / "Symptom2Disease.csv"

def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {DATA_URL}")
    urlretrieve(DATA_URL, OUTPUT)
    print(f"Saved dataset to {OUTPUT}")

if __name__ == "__main__":
    main()
