from django.db import models

class ClothingItem(models.Model):
    original_image = models.ImageField(upload_to='items/original/')
    segmented_image = models.ImageField(upload_to='items/segmented/')

    color = models.CharField(max_length=50)
    category = models.CharField(max_length=100)
    subcategory = models.CharField(max_length=100)
    usage = models.CharField(max_length=100)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.category} - {self.subcategory}"

