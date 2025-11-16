# from rembg import remove
# from PIL import Image
# import uuid
# from django.conf import settings

# def segment_image(uploaded_file):
#     img = Image.open(uploaded_file)
#     output = remove(img)

#     filename = f"{uuid.uuid4()}.png"
#     output_path = settings.MEDIA_ROOT / "items/segmented" / filename

#     output.save(output_path)

#     return f"items/segmented/{filename}"

from rembg import remove
from PIL import Image
import time
import io

def test_segmentation(image_file):
    """
    Takes an uploaded image file and returns:
    - segmented image (PIL image)
    - execution time (seconds)
    """
    start = time.time()

    img = Image.open(image_file)
    output = remove(img)

    end = time.time()

    return output, round(end - start, 4)
