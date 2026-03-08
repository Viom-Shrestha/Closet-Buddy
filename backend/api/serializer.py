from rest_framework import serializers
from .models import ClothingItem, NonClothingItem, Outfit, StorageUnit
from django.contrib.auth.models import User

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
class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name']
        # Username and Email are usually read-only during a profile update
        read_only_fields = ['username', 'email']
        

class ClothingItemSerializer(serializers.ModelSerializer):
    storage_unit = serializers.SerializerMethodField()

    class Meta:
        model = ClothingItem
        fields = [
            "id",
            "image",
            "category",
            "subcategory",
            "occasion",
            "dominant_color",
            "secondary_color",
            "attributes",
            "is_favourite",
            "created_at",
            "storage_unit",
        ]

    def get_storage_unit(self, obj):
        return {
            "id": obj.storage_unit.id,
            "name": obj.storage_unit.name,
            "type": obj.storage_unit.type,
        }

class ClothingItemUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = ClothingItem
        fields = [
            "category",
            "subcategory",
            "dominant_color",
            "secondary_color",
            "occasion",
            "attributes",
        ]


# class ClothingItemCreateSerializer(serializers.ModelSerializer):
#     storage_id = serializers.PrimaryKeyRelatedField(
#         queryset=StorageUnit.objects.all(),
#         source="storage_unit",
#         write_only=True
#     )
#     class Meta:
#         model = ClothingItem
#         fields = [
#             "storage_id",
#             "image",
#             "category",
#             "subcategory",
#             "occasion",
#             "dominant_color",
#             "secondary_color",
#         ]

#     def create(self, validated_data):
#         user = self.context["request"].user
#         return ClothingItem.objects.create(user=user, **validated_data)

class StorageUnitSerializer(serializers.ModelSerializer):
    parent_storage = serializers.SerializerMethodField()
    sub_storages = serializers.SerializerMethodField()
    item_count = serializers.SerializerMethodField()

    class Meta:
        model = StorageUnit
        fields = [
            "id",
            "name",
            "description",
            "type",
            "parent_storage",
            "is_put_away",
            "item_count",
            "sub_storages",
            "created_at"
        ]

    def get_parent_storage(self, obj):
        if obj.parent_storage:
            return {
                "id": obj.parent_storage.id,
                "name": obj.parent_storage.name,
                "type": obj.parent_storage.type,
            }
        return None
    
    def get_sub_storages(self, obj):
        return StorageUnitSerializer(
            obj.sub_units.all(),
            many=True,
            context=self.context
        ).data


    def get_item_count(self, obj):

        def collect_ids(s):
            ids = [s.id]
            for c in s.sub_units.all():
                ids += collect_ids(c)
            return ids

        ids = collect_ids(obj)

        clothing = ClothingItem.objects.filter(storage_unit__in=ids).count()
        non_clothing = NonClothingItem.objects.filter(storage_unit__in=ids).count()

        return clothing + non_clothing

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


def _slot_text(item: ClothingItem) -> str:
    category = (item.category or "").lower()
    subcategory = (item.subcategory or "").lower()
    return f"{category} {subcategory}"


def _is_shoe(item: ClothingItem) -> bool:
    text = _slot_text(item)
    keys = ["shoe", "sneaker", "boot", "heel", "footwear", "slipper", "sandal", "loafer"]
    return any(key in text for key in keys)


def _is_bottom(item: ClothingItem) -> bool:
    text = _slot_text(item)
    keys = [
        "pant",
        "trouser",
        "jean",
        "short",
        "skirt",
        "bottom",
        "jogger",
        "legging",
        "cargo",
    ]
    return any(key in text for key in keys)


class OutfitSlotItemSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()

    class Meta:
        model = ClothingItem
        fields = [
            "id",
            "image",
            "category",
            "subcategory",
            "dominant_color",
            "is_favourite",
        ]

    def get_image(self, obj):
        request = self.context.get("request")
        if not obj.image:
            return ""
        if request:
            return request.build_absolute_uri(obj.image.url)
        return obj.image.url


class OutfitReadSerializer(serializers.ModelSerializer):
    topwear_item = OutfitSlotItemSerializer(source="topwear", read_only=True)
    bottomwear_item = OutfitSlotItemSerializer(source="bottomwear", read_only=True)
    shoes_item = OutfitSlotItemSerializer(source="shoes", read_only=True)

    class Meta:
        model = Outfit
        fields = [
            "id",
            "name",
            "occasion",
            "rating",
            "is_favourite",
            "silhouette",
            "created_at",
            "topwear_item",
            "bottomwear_item",
            "shoes_item",
        ]


class OutfitWriteSerializer(serializers.ModelSerializer):
    topwear_id = serializers.PrimaryKeyRelatedField(
        queryset=ClothingItem.objects.all(),
        source="topwear",
        required=False,
        allow_null=True,
    )
    bottomwear_id = serializers.PrimaryKeyRelatedField(
        queryset=ClothingItem.objects.all(),
        source="bottomwear",
        required=False,
        allow_null=True,
    )
    shoes_id = serializers.PrimaryKeyRelatedField(
        queryset=ClothingItem.objects.all(),
        source="shoes",
        required=False,
        allow_null=True,
    )

    class Meta:
        model = Outfit
        fields = [
            "name",
            "occasion",
            "rating",
            "is_favourite",
            "silhouette",
            "topwear_id",
            "bottomwear_id",
            "shoes_id",
        ]

    def validate(self, attrs):
        request = self.context.get("request")
        user = getattr(request, "user", None)

        instance = getattr(self, "instance", None)
        topwear = attrs.get("topwear", getattr(instance, "topwear", None))
        bottomwear = attrs.get("bottomwear", getattr(instance, "bottomwear", None))
        shoes = attrs.get("shoes", getattr(instance, "shoes", None))

        for field_name, item in [("topwear_id", topwear), ("bottomwear_id", bottomwear), ("shoes_id", shoes)]:
            if item and user and item.user_id != user.id:
                raise serializers.ValidationError({field_name: "Selected item must belong to current user."})

        if topwear and (_is_shoe(topwear) or _is_bottom(topwear)):
            raise serializers.ValidationError({"topwear_id": "Topwear slot cannot contain footwear or bottomwear."})
        if bottomwear and not _is_bottom(bottomwear):
            raise serializers.ValidationError({"bottomwear_id": "Bottomwear slot expects a bottomwear item."})
        if shoes and not _is_shoe(shoes):
            raise serializers.ValidationError({"shoes_id": "Shoes slot expects a footwear item."})

        return attrs

    def create(self, validated_data):
        outfit = Outfit.objects.create(**validated_data)
        self._sync_clothing_items(outfit)
        return outfit

    def update(self, instance, validated_data):
        for key, value in validated_data.items():
            setattr(instance, key, value)
        instance.save()
        self._sync_clothing_items(instance)
        return instance

    def _sync_clothing_items(self, outfit: Outfit):
        selected = [item for item in [outfit.topwear, outfit.bottomwear, outfit.shoes] if item]
        outfit.clothing_items.set(selected)
