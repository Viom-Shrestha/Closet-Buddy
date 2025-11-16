from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser

from ai_models.segmentation.segmentation_utill import test_segmentation
from ai_models.classification.subcategory import test_subcategory


class TestModels(APIView):
    parser_classes = [MultiPartParser]

    def post(self, request):
        img = request.FILES['image']

        # 1. Test Segmentation
        seg_output, seg_time = test_segmentation(img)

        # Convert segmented output to PIL for classification
        seg_output_pil = seg_output

        if seg_output_pil.mode != "RGB":
            image = seg_output_pil.convert("RGB")

        # 2. Test Classification
        label, cls_time = test_subcategory(image)

        # Respond
        return Response({
            "segmentation_time": seg_time,
            "classification_time": cls_time,
            "predicted_subcategory": label
        })
