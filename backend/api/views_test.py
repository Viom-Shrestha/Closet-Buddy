from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser

from ai_models.segmentation.segmentation_utill import test_segmentation
from ai_models.classification.subcategory import test_subcategory


import os
# Import your function - change 'your_file_name' to the actual name of your script
from ai_models.utils.color_extraction_util import extract_colors_with_names

def run_test(test_image_folder):
    for filename in os.listdir(test_image_folder):
        if filename.endswith((".jpg", ".png", ".jpeg")):
            path = os.path.join(test_image_folder, filename)
            result = extract_colors_with_names(path)
            print(f"File: {filename}")
            print(f"  -> Result: {result}\n")

if __name__ == "__main__":
    # Create a folder named 'test_images' and put 3-4 sample clothes there
    folder_path = "./test_images" 
    if not os.path.exists(folder_path):
        os.makedirs(folder_path)
        print(f"Please put some images in {folder_path} and run again.")
    else:
        run_test(folder_path)