import argparse
import json
import os
from pathlib import Path

import requests
import torch
import torch.nn.functional as F
import torchvision.transforms as T
from PIL import Image

device = "cuda" if torch.cuda.is_available() else "cpu"
supported_extensions = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
class_names = ["Heart", "Oblong", "Oval", "Round", "Square"]
model_path = r"model_85_nn_.pth"
model_url = "https://huggingface.co/fahd9999/model_85_nn_/resolve/main/model_85_nn_.pth?download=true"

transform = T.Compose(
    [
        T.Resize((224, 224)),
        T.ToTensor(),
        T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ]
)


def download_model_if_not_exists(url, path):
    if os.path.exists(path):
        return

    response = requests.get(url, timeout=60)
    response.raise_for_status()
    with open(path, "wb") as file:
        file.write(response.content)


def load_model(path):
    model = torch.load(path, map_location=device, weights_only=False)
    model.eval()
    model.to(device)
    return model


def preprocess_image(image_path):
    image = Image.open(image_path).convert("RGB")
    return transform(image).unsqueeze(0).to(device)


def predict_scores(image_path, model):
    image_tensor = preprocess_image(image_path)
    with torch.inference_mode():
        outputs = model(image_tensor)
        percentages = F.softmax(outputs, dim=1) * 100
    return {class_names[i]: percentages[0, i].item() for i in range(len(class_names))}


def is_image_file(path):
    return Path(path).suffix.lower() in supported_extensions


def collect_image_paths(input_path):
    path = Path(input_path)
    if not path.exists():
        raise FileNotFoundError(f"Input path does not exist: {input_path}")

    if path.is_file():
        if not is_image_file(path):
            raise ValueError(f"Input file is not a supported image: {input_path}")
        return [path]

    if path.is_dir():
        images = sorted(
            candidate
            for candidate in path.rglob("*")
            if candidate.is_file() and is_image_file(candidate)
        )
        if not images:
            raise ValueError(f"No supported images found in directory: {input_path}")
        return images

    raise ValueError(f"Input path is neither a file nor a directory: {input_path}")


def sort_scores(scores):
    return dict(sorted(scores.items(), key=lambda item: item[1], reverse=True))


def main():
    parser = argparse.ArgumentParser(description="Face shape inference")
    parser.add_argument("input_path", help="Image file or directory of images")
    parser.add_argument(
        "--threshold",
        type=float,
        default=10.0,
        help="Ignore per-image class scores below this percentage when aggregating directories",
    )
    args = parser.parse_args()

    if not 0 <= args.threshold <= 100:
        raise ValueError("--threshold must be between 0 and 100")

    download_model_if_not_exists(model_url, model_path)
    model = load_model(model_path)
    image_paths = collect_image_paths(args.input_path)

    if len(image_paths) == 1:
        scores = predict_scores(str(image_paths[0]), model)
        predicted = max(scores, key=scores.get)
        output = {
            "image_path": str(image_paths[0]),
            "predicted_class": predicted,
            "class_scores_percent": sort_scores(scores),
        }
        print(json.dumps(output, indent=2))
        return

    aggregated = {name: 0.0 for name in class_names}
    for image_path in image_paths:
        scores = predict_scores(str(image_path), model)
        for class_name, score in scores.items():
            if score >= args.threshold:
                aggregated[class_name] += score

    if all(value == 0.0 for value in aggregated.values()):
        raise ValueError("All scores were filtered out. Lower --threshold.")

    predicted = max(aggregated, key=aggregated.get)
    output = {
        "input_directory": str(Path(args.input_path)),
        "images_scanned": len(image_paths),
        "threshold_percent": args.threshold,
        "predicted_class": predicted,
        "aggregated_class_scores_percent": sort_scores(aggregated),
    }
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
