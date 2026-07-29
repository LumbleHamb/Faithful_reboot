from PIL import Image
import sys

def get_image_dimensions(image_path):
    try:
        with Image.open(image_path) as img:
            width, height = img.size
            print(f"{width},{height}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python get_dims.py <path_to_image>")
    else:
        get_image_dimensions(sys.argv[1])
