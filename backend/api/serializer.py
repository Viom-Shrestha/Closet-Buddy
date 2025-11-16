from rest_framework import serializers
from .models import ClothingItem

class ClothingItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = ClothingItem
        fields = "__all__"
