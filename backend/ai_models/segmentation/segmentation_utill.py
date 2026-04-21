from rembg import remove
from PIL import Image
import uuid
from django.conf import settings
from pathlib import Path

# IMAGE SEGMENTATION FUNCTION
def segment_image(uploaded_image):
    input_image = Image.open(uploaded_image)

    output_image = remove(input_image)

    filename = f"{uuid.uuid4()}.png"
    output_path = Path(settings.MEDIA_ROOT) / "clothing" / filename

    output_image.save(output_path)

    return f"{settings.MEDIA_URL}clothing/{filename}"
