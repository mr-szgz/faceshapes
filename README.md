---
pipeline_tag: image-classification
tags:
- face
- shape
- face shape
- pytorch
- torch
- face model
- face shape classifier
datasets:
- bkprocovid19/face_shape
library_name: keras
---
# Face Shape Classification Model (EfficientNetB4 + CNN)

This model is designed for **face shape classification**. It uses **EfficientNetB4** as the backbone, trained with transfer learning, and fine-tuned with a custom Convolutional Neural Network (CNN) to classify images into 5 different face shape categories. The model uses a **softmax activation function** to return the probability distribution over the 5 classes.

## Model Overview

The model performs face shape classification, predicting the most likely face shape category based on the input image. It outputs the predicted class with the highest probability, along with the percentage of confidence in that prediction.

### Key Features:
- **EfficientNetB4** for feature extraction.
- Fine-tuned CNN layers for improved face shape classification.
- Softmax function for multi-class classification, returning 5 face shape categories.
- Can classify faces into **5 distinct face shape classes** based on the learned features.

## Face Shape Categories

The model classifies the input face into one of the following categories:
1. **Oval**
2. **Round**
3. **Square**
4. **Heart**
5. **Diamond**

## Model Architecture

The model is based on **EfficientNetB4**, which has been pretrained on a large-scale dataset (ImageNet) and fine-tuned using a CNN that focuses on face shape classification tasks.

1. **EfficientNetB4**: A high-performing backbone for feature extraction that efficiently captures patterns in facial features.
2. **CNN Layers**: Additional layers were added on top of EfficientNetB4 to specialize the model for face shape classification tasks.
3. **Softmax Activation**: The final layer uses the softmax function to predict the probabilities for each of the 5 face shape classes.

## Model Performance

This model has been trained and evaluated on a diverse dataset of face images. Below are the performance metrics:

- **Accuracy**: 85% (on the validation set)
- **Loss**: 0.45 (categorical cross-entropy)
- **F1 Score**: 0.83 (macro average)

The model provides high accuracy in classifying face shapes and performs well even on images with slight variations in pose, lighting, and expression.

## Usage

You can use this model for inference using the Hugging Face `transformers` library.

For the local project layout in this repository, you can also run the packaged CLI directly:

```bash
python -m faceshapes path/to/image-or-folder
```

This always writes per-image text output into a `faceshapes/` directory next to the input file, or inside the input directory when you pass a folder.

### CLI Options

```bash
python -m faceshapes path/to/image-or-folder -Move
python -m faceshapes path/to/image-or-folder -Force
python -m faceshapes path/to/image-or-folder -Move -Directory faces
```

- `-Move` / `--move`: Move each image into a folder named after that image's top predicted face shape under `faces/` by default, then rename each face shape folder to include its file count (for example `faces/Oval_12/`).
- `-Directory` / `--directory`: Parent folder name used by `-Move` before the face shape folder (default: `faces`).
- `-Force` / `--force`: Re-run inference and overwrite existing `faceshapes/*.txt` files.
- By default, inference is skipped when an existing `faceshapes/*_faceshapes.txt` is present and valid. With `-Move`, those existing results are reused and inference only runs when a result file is missing/invalid (or when `-Force` is set).

### Installation

Make sure you have the following dependencies installed:

```bash
pip install transformers torch torchvision
```

## Build and Release Automation

This repository now includes reusable packaging/CI/release scaffolding for the `faceshapes` CLI:

```bash
mise run clean
mise run build
mise run bump
```

Equivalent direct PowerShell commands:

```powershell
pwsh -NoProfile -File scripts/Invoke-Clean-Faceshapes-Build.ps1
pwsh -NoProfile -File scripts/Invoke-Build-Faceshapes-Wheels.ps1
pwsh -NoProfile -File scripts/Invoke-Bump-Faceshapes-Version.ps1 -BumpVersion auto
```

CI runs packaging checks on pushes/PRs, and release publishing is triggered by semantic tags (`vX.Y.Z`) via `.github/workflows/release.yml`.
