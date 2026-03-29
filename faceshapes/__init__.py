import argparse
import json
from pathlib import Path

import requests
import torch
import torchvision.transforms as T
from PIL import Image
from tqdm import tqdm

device = "cuda" if torch.cuda.is_available() else "cpu"
supported_extensions = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
class_names = ["Heart", "Oblong", "Oval", "Round", "Square"]
project_root = Path(__file__).resolve().parent.parent
model_path = project_root / "model_85_nn_.pth"
model_url = "https://huggingface.co/fahd9999/model_85_nn_/resolve/main/model_85_nn_.pth?download=true"

transform = T.Compose(
    [
        T.Resize((224, 224)),
        T.ToTensor(),
        T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ]
)


def get_top_class_from_txt(text_output_path):
    winner_name = None
    winner_score = None
    for line in text_output_path.read_text(encoding="utf-8").splitlines():
        parts = line.strip().split()
        if len(parts) != 2:
            continue
        class_name, raw_score = parts
        if class_name not in class_names:
            continue
        try:
            score = float(raw_score)
        except ValueError:
            continue
        if winner_score is None or score > winner_score:
            winner_name = class_name
            winner_score = score
    return winner_name


def ensure_model_file():
    model_file = Path(model_path)
    if model_file.exists():
        return model_file

    response = requests.get(model_url, timeout=60)
    response.raise_for_status()
    model_file.write_bytes(response.content)
    return model_file


def load_model():
    model = torch.load(ensure_model_file(), map_location=device, weights_only=False)
    model.eval()
    model.to(device)
    return model


def infer_scores(model, image_path):
    with Image.open(image_path) as image:
        image_tensor = transform(image.convert("RGB")).unsqueeze(0).to(device)  # pyright: ignore[reportAttributeAccessIssue]

    with torch.inference_mode():
        outputs = model(image_tensor)

    raw_scores = outputs.squeeze(0).detach().cpu().tolist()
    return {class_names[i]: raw_scores[i] for i in range(len(class_names))}


def resolve_move_destination(image_path, target_dir):
    destination = target_dir / image_path.name
    if destination == image_path:
        return destination
    if not destination.exists():
        return destination

    stem = image_path.stem
    suffix = image_path.suffix
    counter = 1
    while True:
        candidate = target_dir / f"{stem}_{counter}{suffix}"
        if not candidate.exists():
            return candidate
        counter += 1


def resolve_faceshape_directory_name(target_dir):
    file_count = sum(1 for path in target_dir.iterdir() if path.is_file())
    base_name = f"{target_dir.name}_{file_count}"
    destination = target_dir.with_name(base_name)
    if destination == target_dir:
        return destination
    if not destination.exists():
        return destination

    counter = 1
    while True:
        candidate = target_dir.with_name(f"{base_name}_{counter}")
        if not candidate.exists():
            return candidate
        counter += 1


def calculate_predicted_faceshape(faceshapes_dir):
    faceshapes_path = Path(faceshapes_dir)
    txt_files = sorted(faceshapes_path.glob("*.txt"))
    if not txt_files:
        raise ValueError(f"No .txt files found in: {faceshapes_path}")

    class_order = {name: i for i, name in enumerate(class_names)}
    counts = {name: 0 for name in class_names}

    for txt_file in txt_files:
        winner_name = None
        winner_score = None
        for line in txt_file.read_text(encoding="utf-8").splitlines():
            parts = line.strip().split()
            if len(parts) != 2:
                continue
            class_name, raw_score = parts
            if class_name not in counts:
                continue
            try:
                score = float(raw_score)
            except ValueError:
                continue
            if winner_score is None or score > winner_score:
                winner_name = class_name
                winner_score = score
        if winner_name is not None:
            counts[winner_name] += 1

    shape_counts = [
        [class_name, count]
        for class_name, count in sorted(counts.items(), key=lambda item: (-item[1], class_order[item[0]]))
        if count > 0
    ]
    if not shape_counts:
        raise ValueError(f"No valid class scores found in: {faceshapes_path}")

    return {
        "predicted_faceshape": shape_counts[0][0],
        "shape_counts": shape_counts,
        "faceshapes_dir": str(faceshapes_path.resolve()),
        "txt_files": len(txt_files),
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description="Face shape inference")
    parser.add_argument("input_path", help="Image file or directory of images")
    parser.add_argument(
        "-Force",
        "--force",
        action="store_true",
        help="Re-run inference and overwrite existing faceshape txt files",
    )
    parser.add_argument(
        "-Move",
        "--move",
        action="store_true",
        help="Move images into a folder named after each image's top predicted faceshape",
    )
    parser.add_argument(
        "-Directory",
        "--directory",
        default="Faces",
        help="Parent directory to place moved images under before faceshape folders (default: Faces)",
    )
    args = parser.parse_args(argv)

    input_root = Path(args.input_path)
    if not input_root.exists():
        raise FileNotFoundError(f"Input path does not exist: {args.input_path}")

    if input_root.is_file():
        if input_root.suffix.lower() not in supported_extensions:
            raise ValueError(f"Input file is not a supported image: {args.input_path}")
        image_paths = [input_root]
    elif input_root.is_dir():
        image_paths = sorted(
            path
            for path in input_root.iterdir()
            if path.is_file() and path.suffix.lower() in supported_extensions
        )
        if not image_paths:
            raise ValueError(f"No supported images found in directory: {args.input_path}")
    else:
        raise ValueError(f"Input path is neither a file nor a directory: {args.input_path}")

    if input_root.is_dir():
        faceshapes_dir = input_root / "faceshapes"
        move_root = input_root
    else:
        faceshapes_dir = input_root.parent / "faceshapes"
        move_root = input_root.parent

    model = None
    moved_faceshape_dirs = set()

    progress = tqdm(image_paths, desc="Process", unit="image")
    for image_path in progress:
        output_name = f"{image_path.stem}_faceshapes.txt"
        text_output_path = faceshapes_dir / output_name

        top_class = None
        inferred = False

        if text_output_path.exists() and not args.force:
            top_class = get_top_class_from_txt(text_output_path)

        if top_class is None:
            if model is None:
                model = load_model()

            progress.set_postfix_str(f"image={image_path.name} infer=run move=pending")
            scores = infer_scores(model, image_path)
            text_output_path.parent.mkdir(parents=True, exist_ok=True)
            lines = [f"{class_name} {scores[class_name]:.6f}" for class_name in class_names]
            text_output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            top_class = max(scores, key=scores.get)
            inferred = True

        move_status = "off"
        if args.move:
            target_dir = move_root / args.directory / top_class
            target_dir.mkdir(parents=True, exist_ok=True)
            destination = resolve_move_destination(image_path, target_dir)
            if destination != image_path:
                image_path.rename(destination)
                moved_faceshape_dirs.add(target_dir)
                move_status = "moved"
            else:
                move_status = "already"

        infer_status = "run" if inferred else "skip"
        progress.set_postfix_str(f"image={image_path.name} infer={infer_status} move={move_status}")

    if args.move:
        for target_dir in sorted(moved_faceshape_dirs, key=lambda path: path.name):
            if not target_dir.exists():
                continue
            renamed_dir = resolve_faceshape_directory_name(target_dir)
            if renamed_dir != target_dir:
                target_dir.rename(renamed_dir)

    print(json.dumps(calculate_predicted_faceshape(faceshapes_dir), indent=2))
    return 0


__all__ = [
    "calculate_predicted_faceshape",
    "get_top_class_from_txt",
    "infer_scores",
    "load_model",
    "main",
]
