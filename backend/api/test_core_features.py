import os
import base64
import json
from pathlib import Path
from unittest.mock import patch, MagicMock

from django.conf import settings
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APITestCase

from api.models import StorageUnit, ClothingItem, Outfit

def _png_upload(name: str = "item.png") -> SimpleUploadedFile:
    pixel_png = base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8Xw8AAoMBgQH0mN0AAAAASUVORK5CYII="
    )
    return SimpleUploadedFile(name, pixel_png, content_type="image/png")

class CoreFeaturesTest(APITestCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        print("\n\n" + "="*70)
        print("  Starting Unit Tests for 6 Core Feature Functions  ".center(70))
        print("="*70 + "\n")

    def setUp(self):
        self.user = User.objects.create_user(username="core_user", password="pwd")
        self.storage = StorageUnit.objects.create(user=self.user, name="Main Closet", type="closet")
        self.client.force_authenticate(user=self.user)
        
        # Setup initial items for tests
        self.top = ClothingItem.objects.create(
            user=self.user, storage_unit=self.storage, image=_png_upload("top.png"),
            category="Topwear", subcategory="Shirt", dominant_color="Navy", attributes=[]
        )
        self.bottom = ClothingItem.objects.create(
            user=self.user, storage_unit=self.storage, image=_png_upload("bot.png"),
            category="Bottomwear", subcategory="Jeans", dominant_color="Black", attributes=[]
        )
        self.shoe = ClothingItem.objects.create(
            user=self.user, storage_unit=self.storage, image=_png_upload("sho.png"),
            category="Footwear", subcategory="Sneakers", dominant_color="White", attributes=[]
        )
        self.outfit = Outfit.objects.create(
            user=self.user, name="My Fit", topwear=self.top, bottomwear=self.bottom, shoes=self.shoe
        )

    def print_result(self, feature_name, case_name, status_code, output, is_error=False):
        status_color = "\033[92m" if status_code in [200, 201] else "\033[91m"
        reset = "\033[0m"
        if not is_error and status_code not in [200, 201]:
            status_color = "\033[91m" # Actually Failed
        elif is_error and status_code in [400, 404, 422]:
            status_color = "\033[92m" # Passed error condition
            
        print(f"[{feature_name}] - {case_name}")
        print(f"Status Code: {status_color}{status_code}{reset}")
        
        # Format JSON output safely
        if isinstance(output, dict) or isinstance(output, list):
            out_str = json.dumps(output, indent=2)
            # truncate long output for readability
            if len(out_str) > 500:
                out_str = out_str[:500] + "\n... [truncated]"
            print(f"Output:\n{out_str}\n")
        else:
            print(f"Output: {output}\n")

    # 1. clothing_process
    @patch("api.views.clothing._authenticate_item", return_value=None)
    @patch("api.views.clothing.segment_image", return_value="/media/segmented.png")
    @patch("api.views.clothing._resolve_media_path_safe")
    @patch("api.views.clothing._extract_colors_safe", return_value={"dominant_color": "Blue", "secondary_color": "White"})
    @patch("api.views.clothing._classify_clothing_safe", return_value=("Topwear", "Shirt", ["cotton"]))
    @patch("api.views.clothing._predict_occasion_safe", return_value=("Casual", 0.95))
    @patch("api.views.clothing._classify_weather_safe", return_value=("warm", "dry"))
    def test_1_clothing_process(self, mock_w, mock_o, mock_c, mock_color, mock_resolv, mock_seg, mock_auth):
        print("-" * 50)
        # Mock pathlib exists
        mock_path = MagicMock()
        mock_path.exists.return_value = True
        mock_resolv.return_value = mock_path

        # Success Case
        payload = {"image": _png_upload("test.png"), "is_shoe": False}
        res = self.client.post("/api/clothing/process/", payload)
        self.print_result("1. clothing_process", "Valid Image Input", res.status_code, res.data)

        # Error Case
        payload_err = {"is_shoe": False}
        res_err = self.client.post("/api/clothing/process/", payload_err)
        self.print_result("1. clothing_process", "Missing Image Input", res_err.status_code, res_err.data, is_error=True)


    # 2. clothing_save
    def test_2_clothing_save(self):
        print("-" * 50)
        original_url = "http://testserver/media/test.png"
        
        with patch("api.views.clothing._resolve_media_path_safe") as mock_resolv:
            mock_path = MagicMock()
            mock_path.exists.return_value = True
            mock_path.read_bytes.return_value = _png_upload("test.png").read()
            mock_path.name = "test.png"
            mock_resolv.return_value = mock_path
            
            # Success Case
            payload = {
                "storage_unit": self.storage.id,
                "original_image": original_url,
                "use_segmentation": False,
                "category": "Topwear",
                "subcategory": "Jacket",
                "dominant_color": "Black",
            }
            res = self.client.post("/api/clothing/save/", payload, format="json")
            self.print_result("2. clothing_save", "Valid Item Save", res.status_code, res.data)

            # Error Case
            payload_err = {
                "original_image": original_url,
                "use_segmentation": False,
            }
            res_err = self.client.post("/api/clothing/save/", payload_err, format="json")
            self.print_result("2. clothing_save", "Missing Storage Unit & Fields", res_err.status_code, res_err.data, is_error=True)

    # 3. recommend_outfits
    def test_3_recommend_outfits(self):
        print("-" * 50)
        with patch("api.recommend.engine.scoring.clip_score", return_value=0.88):
            # Success Case
            payload = {"weather": {"temperature": "cool", "weather": "dry"}}
            res = self.client.post("/api/recommendations/", payload, format="json")
            self.print_result("3. recommend_outfits", "Valid Weather Input", res.status_code, res.data)

            # Error Case
            payload_err = {"weather": "not_a_dict"}
            res_err = self.client.post("/api/recommendations/", payload_err, format="json")
            self.print_result("3. recommend_outfits", "Invalid Weather String", res_err.status_code, res_err.data, is_error=True)

    # 4. ai_rate
    def test_4_ai_rate(self):
        print("-" * 50)
        with patch("api.recommend.scoring.clip_score", return_value=0.82):
            payload = {
                "topwear_id": self.top.id,
                "bottomwear_id": self.bottom.id,
                "shoes_id": self.shoe.id,
            }
            # Success Case
            res = self.client.post("/api/outfits/ai-rate/", payload, format="json")
            self.print_result("4. ai_rate", "Valid Outfit Combination", res.status_code, res.data)

            # Error Case
            payload_err = {
                "topwear_id": self.top.id,
                "shoes_id": self.shoe.id,
            }
            res_err = self.client.post("/api/outfits/ai-rate/", payload_err, format="json")
            self.print_result("4. ai_rate", "Missing Bottomwear", res_err.status_code, res_err.data, is_error=True)

    # 5. toggle_favourite
    def test_5_toggle_favourite(self):
        print("-" * 50)
        # Success Case
        res = self.client.post(f"/api/clothing/{self.top.id}/toggle-favourite/", {}, format="json")
        self.print_result("5. toggle_favourite", "Valid Clothing ID", res.status_code, res.data)

        # Error Case
        res_err = self.client.post(f"/api/clothing/999999/toggle-favourite/", {}, format="json")
        self.print_result("5. toggle_favourite", "Invalid ID (Not Found)", res_err.status_code, res_err.data, is_error=True)

    # 6. wear_outfit
    def test_6_wear_outfit(self):
        print("-" * 50)
        # Success Case (First Wear Today)
        res = self.client.post(f"/api/outfits/{self.outfit.id}/wear/", {}, format="json")
        outfit_worn_data = res.data if res.status_code == 200 else {}
        self.print_result("6. wear_outfit", "Valid Outfit ID (First wear today)", res.status_code, outfit_worn_data)
        
        # Success Case (Already Worn Today - skip increment)
        res2 = self.client.post(f"/api/outfits/{self.outfit.id}/wear/", {}, format="json")
        outfit_worn_twice_data = res2.data if res2.status_code == 200 else {}
        self.print_result("6. wear_outfit", "Valid Outfit ID (Already worn today - no increment)", res2.status_code, outfit_worn_twice_data)

        # Error Case
        res_err = self.client.post(f"/api/outfits/999999/wear/", {}, format="json")
        self.print_result("6. wear_outfit", "Invalid Outfit ID (Not Found)", res_err.status_code, res_err.data, is_error=True)

