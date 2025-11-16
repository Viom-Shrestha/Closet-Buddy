# from django.shortcuts import render
# from rest_framework.views import APIView
# from rest_framework.response import Response
# from rest_framework.parsers import MultiPartParser
# from .models import ClothingItem
# from .serializer import ClothingItemSerializer

# from .segmentation_utils import segment_image
# from .classification_utils import classify_item, extract_color

# class UploadClothingItem(APIView):
#     parser_classes = [MultiPartParser]

#     def post(self, request):
#         image = request.FILES['image']

#         # Step 1: SEGMENTATION
#         segmented_path = segment_image(image)

#         # Step 2: CLASSIFICATION (your 3 models)
#         category, subcategory, usage = classify_item(segmented_path)

#         # Step 3: COLOR EXTRACTION
#         color = extract_color(segmented_path)

#         # Step 4: Store in DB
#         item = ClothingItem.objects.create(
#             original_image=image,
#             segmented_image=segmented_path,
#             color=color,
#             category=category,
#             subcategory=subcategory,
#             usage=usage
#         )

#         return Response(ClothingItemSerializer(item).data)

# # Create your views here.
