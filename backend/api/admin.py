from django.contrib import admin
from .models import StorageUnit, ClothingItem, Outfit, NonClothingItem, UserProfile, AccessoryItem

admin.site.register(StorageUnit)
admin.site.register(ClothingItem)
admin.site.register(Outfit)
admin.site.register(NonClothingItem)
admin.site.register(UserProfile)
admin.site.register(AccessoryItem)
admin.site.site_header = "Closet Organizer Admin"
admin.site.site_title = "Closet Organizer Admin Portal"
admin.site.index_title = "Welcome to the Closet Organizer Admin Portal"


