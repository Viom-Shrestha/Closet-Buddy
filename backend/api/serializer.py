from rest_framework import serializers
from .models import ClothingItem,NonClothingItem,StorageUnit
from django.contrib.auth.models import User

# class ClothingItemSerializer(serializers.ModelSerializer):
#     class Meta:
#         model = ClothingItem
#         fields = "__all__"

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)

    class Meta:
        model = User
        fields = ('username', 'email', 'password', 'first_name', 'last_name')

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', '')
        )
        return user

class ClothingItemCreateSerializer(serializers.ModelSerializer):
    storage_id = serializers.PrimaryKeyRelatedField(
        queryset=StorageUnit.objects.all(),
        source="storage_unit",
        write_only=True
    )

    class Meta:
        model = ClothingItem
        fields = [
            "storage_id",
            "image",
            "category",
            "subcategory",
            "occasion",
            "dominant_color",
            "secondary_color",
        ]

    def create(self, validated_data):
        user = self.context["request"].user
        return ClothingItem.objects.create(user=user, **validated_data)

class StorageUnitSerializer(serializers.ModelSerializer):
    parent_storage = serializers.SerializerMethodField()

    class Meta:
        model = StorageUnit
        fields = ["id", "name", "description", "type", "parent_storage", "is_put_away"]

    def get_parent_storage(self, obj):
        if obj.parent_storage:
            return {
                "id": obj.parent_storage.id,
                "name": obj.parent_storage.name,
                "type": obj.parent_storage.type,
            }
        return None

class NonClothingItemSerializer(serializers.ModelSerializer):
    storage_unit = serializers.SerializerMethodField()

    class Meta:
        model = NonClothingItem
        fields = ['id', 'name', 'description', 'storage_unit', 'created_at']

    def get_storage_unit(self, obj):
        """Return minimal storage info"""
        return {
            "id": obj.storage_unit.id,
            "name": obj.storage_unit.name,
            "type": obj.storage_unit.type
        }