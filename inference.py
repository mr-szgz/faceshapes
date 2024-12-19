import os
import requests
import torch
import torchvision.transforms as T
from PIL import Image
import torch.nn.functional as F  # For softmax

# Define device
device = "cuda" if torch.cuda.is_available() else "cpu"

# Model and transformation setup
def download_model_if_not_exists(url, model_path):
    """Download model from Hugging Face repository if it doesn't exist locally."""
    if not os.path.exists(model_path):
        print("Model not found locally, downloading from Hugging Face...")
        response = requests.get(url)
        if response.status_code == 200:
            with open(model_path, 'wb') as f:
                f.write(response.content)
            print(f"Model downloaded and saved to {model_path}")
        else:
            print("Failed to download model. Please check the URL.")
    else:
        print("Model already exists locally.")

def load_model(model_path):
    """Load model from the given path."""
    model = torch.load(model_path, map_location=torch.device('cpu'))
    model.eval()  # Set model to evaluation mode
    model.to(device)
    return model

def preprocess_image(image_path):
    transform = T.Compose([
        T.Resize((224, 224)),  # Resize image to 224x224
        T.ToTensor(),          # Convert image to Tensor
        T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])  # Normalize
    ])
    image = Image.open(image_path).convert("RGB")  # Open and convert image to RGB
    return transform(image).unsqueeze(0)  # Add batch dimension

def get_probabilities(logits):
    """Apply softmax to get probabilities."""
    probabilities = F.softmax(logits, dim=1)
    percentages = probabilities * 100
    return percentages

def predict(image_path, model, class_names):
    """Make prediction using the trained model."""
    image_tensor = preprocess_image(image_path).to(device)
    model.eval()
    with torch.inference_mode():  # Disable gradient calculations
        outputs = model(image_tensor)
        percentages = get_probabilities(outputs)
        _, predicted_class = torch.max(outputs, 1)  # Get the index of the highest logit
    predicted_label = class_names[predicted_class.item()]
    return predicted_label, percentages

# Define class names
class_names = ['Heart', 'Oblong', 'Oval', 'Round', 'Square']

# Path to the model file
model_path = r"model_85_nn_.pth"  # Update this with the correct model path
model_url = "https://huggingface.co/fahd9999/model_85_nn_/resolve/main/model_85_nn_.pth?download=true"

# Download the model only if it doesn't exist locally
download_model_if_not_exists(model_url, model_path)

# Load the model
model = load_model(model_path)

def main(image_path):
    """Run the prediction process."""
    predicted_label, percentages = predict(image_path, model, class_names)
    result = {class_names[i]: percentages[0, i].item() for i in range(len(class_names))}
    sorted_result = dict(sorted(result.items(), key=lambda item: item[1], reverse=True))
    print(sorted_result)

# Call the function with the path to the image
if __name__ == "__main__":
    image_path = "path_to_your_image.jpg"  # Update this with your image path
    main(image_path)
