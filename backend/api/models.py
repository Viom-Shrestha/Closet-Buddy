from django.db import models
from django.contrib.auth.models import User
from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator, MaxValueValidator


class UserProfile(models.Model):
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="profile",
    )
    avatar = models.ImageField(upload_to="profiles/", null=True, blank=True)
    # Per-day engagement map:
    # {
    #   "YYYY-MM-DD": {
    #     "last_seen_at": "<iso datetime>|null",
    #     "session_count": <int>,
    #     "total_session_seconds": <int>
    #   }
    # }
    activity_daily = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Profile ({self.user.username})"

class StorageUnit(models.Model):
    STORAGE_TYPE_CHOICES = [
        ("closet", "Closet"),
        ("wardrobe", "Wardrobe"),
        ("cupboard", "Cupboard"),
        ("drawer", "Drawer"),
        ("box", "Box"),
        ("shelf", "Shelf"),
        ("other", "Other"),
    ]
    ALLOWED_CHILDREN = {
    "closet": ["shelf", "drawer", "box"],
    "wardrobe": ["shelf", "drawer", "box"],
    "cupboard": ["shelf", "box", "drawer"],
    "shelf": ["box"],
    "drawer": [],
    "box": [],
    "other": []
    }

    user = models.ForeignKey(User, on_delete=models.CASCADE,related_name="storage_units")
    name = models.CharField(max_length=100)
    description = models.TextField(null=True, blank=True)
    type = models.CharField(
        max_length=30,
        choices=STORAGE_TYPE_CHOICES
    )
    parent_storage = models.ForeignKey(
        "self",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="sub_units"
    )
    is_put_away = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} [{self.type}] - {self.user.username}"
    
    def clean(self):
        if self.parent_storage:
            if self.parent_storage.user != self.user:
                raise ValidationError("Parent storage must belong to same user.")

            parent_type = self.parent_storage.type

            allowed = self.ALLOWED_CHILDREN.get(parent_type, [])

            if self.type not in allowed:
                raise ValidationError(
                    f"{parent_type} cannot contain {self.type}"
                )
                
    def save(self, *args, **kwargs):
        self.full_clean()
        super().save(*args, **kwargs)

    
    
class ClothingItem(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="clothing_items"
    )
    storage_unit = models.ForeignKey(
        StorageUnit,
        on_delete=models.PROTECT,
        related_name="clothes"
    )
    image = models.ImageField(upload_to="clothing/")
    category = models.CharField(max_length=50)       # topwear, footwear
    subcategory = models.CharField(max_length=50)    # shirt, jeans
    occasion = models.CharField(max_length=50, null=True, blank=True)
    dominant_color = models.CharField(max_length=30)
    secondary_color = models.CharField(max_length=30, null=True, blank=True)
    attributes = models.JSONField(default=list, blank=True)
    detected_temp = models.CharField(max_length=30, null=True, blank=True)
    detected_weather = models.CharField(max_length=30, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_favourite = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.category} ({self.user.username})"
    def clean(self):
        if self.storage_unit.user != self.user:
            raise ValidationError("Storage unit must belong to the same user.")

class NonClothingItem(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="non_clothing_items"
    )
    storage_unit = models.ForeignKey(
        StorageUnit,
        on_delete=models.PROTECT,
        related_name="misc_items"
    )
    name = models.CharField(max_length=100)
    description = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    def __str__(self):
        return self.name
    def clean(self):
        if self.storage_unit.user != self.user:
            raise ValidationError("Storage unit must belong to the same user.")


class AccessoryItem(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="accessory_items",
    )
    storage_unit = models.ForeignKey(
        StorageUnit,
        on_delete=models.PROTECT,
        related_name="accessory_items",
    )
    image = models.ImageField(upload_to="accessories/")
    name = models.CharField(max_length=100)
    description = models.TextField(null=True, blank=True)
    dominant_color = models.CharField(max_length=30, default="Unknown")
    secondary_color = models.CharField(max_length=30, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_favourite = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.name} ({self.user.username})"

    def clean(self):
        if self.storage_unit.user != self.user:
            raise ValidationError("Storage unit must belong to the same user.")

class Outfit(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="outfits"
    )
    name = models.CharField(max_length=100)
    clothing_items = models.ManyToManyField(
        ClothingItem,
        related_name="outfits"
    )
    occasion = models.CharField(max_length=50, null=True, blank=True)
    rating = models.IntegerField(null=True, blank=True, validators=[MinValueValidator(1), MaxValueValidator(5)])
    ai_rating_score = models.FloatField(
        null=True,
        blank=True,
        validators=[MinValueValidator(1.0), MaxValueValidator(5.0)],
    )
    ai_rating_reasons = models.JSONField(default=list, blank=True)
    ai_rating_breakdown = models.JSONField(default=dict, blank=True)
    ai_rated_at = models.DateTimeField(null=True, blank=True)
    wear_count = models.IntegerField(default=0)
    last_worn_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_favourite = models.BooleanField(default=False)
    topwear = models.ForeignKey(
        ClothingItem,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="as_topwear_in_outfits",
    )
    bottomwear = models.ForeignKey(
        ClothingItem,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="as_bottomwear_in_outfits",
    )
    shoes = models.ForeignKey(
        ClothingItem,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="as_shoes_in_outfits",
    )
    outerwear = models.ForeignKey(
        ClothingItem,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="as_outerwear_in_outfits",
    )
    accessories = models.ManyToManyField(
        AccessoryItem,
        related_name="outfits",
        blank=True,
    )
    preview_layout = models.JSONField(default=dict, blank=True)

    def __str__(self):
        return f"{self.name} ({self.user.username})"


class BetaFeedback(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="beta_feedback",
    )
    message = models.TextField()
    rating = models.IntegerField(
        null=True,
        blank=True,
        validators=[MinValueValidator(1), MaxValueValidator(5)],
    )
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Feedback {self.id} by {self.user.username}"

