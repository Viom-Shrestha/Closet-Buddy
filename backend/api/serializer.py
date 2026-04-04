from rest_framework import serializers
from .models import (
    AccessoryItem,
    ClothingItem,
    NonClothingItem,
    Outfit,
    StorageUnit,
)
from .metadata_normalization import (
    coerce_temperature_label,
    coerce_weather_label,
    normalize_attributes,
    normalize_color_label,
    normalize_occasion_label,
    to_display_label,
)
from django.contrib.auth.models import User

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    confirm_password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ('username', 'email', 'password', 'confirm_password', 'first_name', 'last_name')

    def validate_email(self, value):
        email = (value or "").strip().lower()
        if email and User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError("Email is already registered.")
        return email

    def validate(self, attrs):
        if attrs.get("password") != attrs.get("confirm_password"):
            raise serializers.ValidationError({"confirm_password": "Passwords do not match."})
        return attrs

    def create(self, validated_data):
        validated_data.pop("confirm_password", None)
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
            "detected_temp",
            "detected_weather",
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
            "detected_temp",
            "detected_weather",
        ]

    def validate_occasion(self, value):
        normalized = normalize_occasion_label(value)
        return to_display_label(normalized)

    def validate_attributes(self, value):
        return normalize_attributes(value)

    def validate_detected_temp(self, value):
        return coerce_temperature_label(value, allow_unknown=True)

    def validate_detected_weather(self, value):
        return coerce_weather_label(value, allow_unknown=True)

    def validate_dominant_color(self, value):
        return normalize_color_label(value) or "Unknown"

    def validate_secondary_color(self, value):
        return normalize_color_label(value)


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
        accessories = AccessoryItem.objects.filter(storage_unit__in=ids).count()

        return clothing + non_clothing + accessories

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


class AccessoryItemSerializer(serializers.ModelSerializer):
    storage_unit = serializers.SerializerMethodField()

    class Meta:
        model = AccessoryItem
        fields = [
            "id",
            "image",
            "name",
            "description",
            "dominant_color",
            "secondary_color",
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


def _is_outerwear(item: ClothingItem) -> bool:
    text = _slot_text(item)
    keys = [
        "jacket",
        "coat",
        "blazer",
        "cardigan",
        "hoodie",
        "outerwear",
        "parka",
        "trench",
    ]
    return any(key in text for key in keys)


class OutfitSlotItemSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()
    storage_unit = serializers.SerializerMethodField()

    class Meta:
        model = ClothingItem
        fields = [
            "id",
            "image",
            "category",
            "subcategory",
            "dominant_color",
            "storage_unit",
            "is_favourite",
        ]

    def get_image(self, obj):
        request = self.context.get("request")
        if not obj.image:
            return ""
        if request:
            return request.build_absolute_uri(obj.image.url)
        return obj.image.url

    def _serialize_storage_unit(self, storage):
        if not storage:
            return None

        parent = getattr(storage, "parent_storage", None)
        return {
            "id": storage.id,
            "name": storage.name,
            "type": storage.type,
            "parent_storage": self._serialize_storage_unit(parent) if parent else None,
        }

    def get_storage_unit(self, obj):
        storage = getattr(obj, "storage_unit", None)
        return self._serialize_storage_unit(storage)


class OutfitAccessoryItemSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()

    class Meta:
        model = AccessoryItem
        fields = [
            "id",
            "image",
            "name",
            "dominant_color",
            "secondary_color",
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
    outerwear_item = OutfitSlotItemSerializer(source="outerwear", read_only=True)
    topwear_item = OutfitSlotItemSerializer(source="topwear", read_only=True)
    bottomwear_item = OutfitSlotItemSerializer(source="bottomwear", read_only=True)
    shoes_item = OutfitSlotItemSerializer(source="shoes", read_only=True)
    accessory_items = OutfitAccessoryItemSerializer(source="accessories", many=True, read_only=True)

    class Meta:
        model = Outfit
        fields = [
            "id",
            "name",
            "occasion",
            "rating",
            "ai_rating_score",
            "ai_rating_reasons",
            "ai_rating_breakdown",
            "ai_rated_at",
            "wear_count",
            "last_worn_at",
            "is_favourite",
            "created_at",
            "preview_layout",
            "outerwear_item",
            "topwear_item",
            "bottomwear_item",
            "shoes_item",
            "accessory_items",
        ]


class OutfitWriteSerializer(serializers.ModelSerializer):
    outerwear_id = serializers.PrimaryKeyRelatedField(
        queryset=ClothingItem.objects.all(),
        source="outerwear",
        required=False,
        allow_null=True,
    )
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
    accessory_ids = serializers.PrimaryKeyRelatedField(
        queryset=AccessoryItem.objects.all(),
        source="accessories",
        many=True,
        required=False,
    )

    class Meta:
        model = Outfit
        fields = [
            "name",
            "occasion",
            "rating",
            "ai_rating_score",
            "ai_rating_reasons",
            "ai_rating_breakdown",
            "ai_rated_at",
            "is_favourite",
            "preview_layout",
            "outerwear_id",
            "topwear_id",
            "bottomwear_id",
            "shoes_id",
            "accessory_ids",
        ]

    def validate(self, attrs):
        request = self.context.get("request")
        user = getattr(request, "user", None)

        instance = getattr(self, "instance", None)
        outerwear = attrs.get("outerwear", getattr(instance, "outerwear", None))
        topwear = attrs.get("topwear", getattr(instance, "topwear", None))
        bottomwear = attrs.get("bottomwear", getattr(instance, "bottomwear", None))
        shoes = attrs.get("shoes", getattr(instance, "shoes", None))
        accessories = attrs.get(
            "accessories",
            list(getattr(instance, "accessories", []).all()) if instance else [],
        )

        for field_name, item in [
            ("outerwear_id", outerwear),
            ("topwear_id", topwear),
            ("bottomwear_id", bottomwear),
            ("shoes_id", shoes),
        ]:
            if item and user and item.user_id != user.id:
                raise serializers.ValidationError({field_name: "Selected item must belong to current user."})
        if user:
            for acc in accessories:
                if acc.user_id != user.id:
                    raise serializers.ValidationError({"accessory_ids": "Selected accessory must belong to current user."})

        if outerwear and (_is_shoe(outerwear) or _is_bottom(outerwear)):
            raise serializers.ValidationError({"outerwear_id": "Outerwear slot expects an outerwear item."})
        if outerwear and not _is_outerwear(outerwear):
            raise serializers.ValidationError({"outerwear_id": "Outerwear slot expects jacket/coat/blazer-like item."})
        if topwear and (_is_shoe(topwear) or _is_bottom(topwear)):
            raise serializers.ValidationError({"topwear_id": "Topwear slot cannot contain footwear or bottomwear."})
        if bottomwear and not _is_bottom(bottomwear):
            raise serializers.ValidationError({"bottomwear_id": "Bottomwear slot expects a bottomwear item."})
        if shoes and not _is_shoe(shoes):
            raise serializers.ValidationError({"shoes_id": "Shoes slot expects a footwear item."})

        return attrs

    def create(self, validated_data):
        accessories = validated_data.pop("accessories", [])
        outfit = Outfit.objects.create(**validated_data)
        if accessories is not None:
            outfit.accessories.set(accessories)
        self._sync_clothing_items(outfit)
        return outfit

    def update(self, instance, validated_data):
        ai_fields = {"ai_rating_score", "ai_rating_reasons", "ai_rating_breakdown", "ai_rated_at"}
        had_fresh_ai_snapshot = any(field in validated_data for field in ai_fields)

        slot_changed = False
        for field_name in ["outerwear", "topwear", "bottomwear", "shoes"]:
            if field_name in validated_data and validated_data[field_name] != getattr(instance, field_name):
                slot_changed = True
                break

        accessories = validated_data.pop("accessories", None)
        accessories_changed = False
        if accessories is not None:
            current_ids = set(instance.accessories.values_list("id", flat=True))
            incoming_ids = {acc.id for acc in accessories}
            accessories_changed = current_ids != incoming_ids

        if (slot_changed or accessories_changed) and not had_fresh_ai_snapshot:
            validated_data["ai_rating_score"] = None
            validated_data["ai_rating_reasons"] = []
            validated_data["ai_rating_breakdown"] = {}
            validated_data["ai_rated_at"] = None

        for key, value in validated_data.items():
            setattr(instance, key, value)
        instance.save()
        if accessories is not None:
            instance.accessories.set(accessories)
        self._sync_clothing_items(instance)
        return instance

    def _sync_clothing_items(self, outfit: Outfit):
        selected = [item for item in [outfit.outerwear, outfit.topwear, outfit.bottomwear, outfit.shoes] if item]
        outfit.clothing_items.set(selected)
