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

### Installation

Make sure you have the following dependencies installed:

```bash
pip install transformers torch torchvision