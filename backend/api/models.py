from django.db import models
from django.contrib.auth.models import User
from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator, MaxValueValidator

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
    created_at = models.DateTimeField(auto_now_add=True)

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
    created_at = models.DateTimeField(auto_now_add=True)
    def __str__(self):
        return f"{self.name} ({self.user.username})"
