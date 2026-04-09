import base64
from pathlib import Path
from unittest.mock import patch

from django.conf import settings
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from api.recommend import scoring
from api.views import clothing as clothing_view

from .models import AccessoryItem, BetaFeedback, ClothingItem, NonClothingItem, Outfit, StorageUnit


def _png_upload(name: str = "item.png") -> SimpleUploadedFile:
    pixel_png = base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8Xw8AAoMBgQH0mN0AAAAASUVORK5CYII="
    )
    return SimpleUploadedFile(name, pixel_png, content_type="image/png")


class OutfitAiRateTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="alice", password="test1234")
        self.other_user = User.objects.create_user(username="bob", password="test1234")

        self.storage = StorageUnit.objects.create(
            user=self.user,
            name="Main Closet",
            type="closet",
        )
        self.other_storage = StorageUnit.objects.create(
            user=self.other_user,
            name="Other Closet",
            type="closet",
        )

        self.top = self._create_clothing(self.user, self.storage, "topwear", "shirt", "navy")
        self.top_alt = self._create_clothing(self.user, self.storage, "topwear", "tee", "white")
        self.bottom = self._create_clothing(self.user, self.storage, "bottomwear", "jeans", "black")
        self.shoes = self._create_clothing(self.user, self.storage, "footwear", "sneakers", "white")
        self.outerwear = self._create_clothing(self.user, self.storage, "outerwear", "jacket", "gray")

        self.other_top = self._create_clothing(
            self.other_user,
            self.other_storage,
            "topwear",
            "shirt",
            "red",
        )

        self.client.force_authenticate(user=self.user)

    def _create_clothing(self, user, storage, category, subcategory, color) -> ClothingItem:
        return ClothingItem.objects.create(
            user=user,
            storage_unit=storage,
            image=_png_upload(f"{category}-{subcategory}.png"),
            category=category,
            subcategory=subcategory,
            dominant_color=color,
            secondary_color="white",
            attributes=[],
        )

    @patch("api.recommend.scoring.clip_score", return_value=0.82)
    def test_ai_rate_returns_score_reasons_and_breakdown(self, _mock_clip):
        payload = {
            "topwear_id": self.top.id,
            "bottomwear_id": self.bottom.id,
            "shoes_id": self.shoes.id,
            "outerwear_id": self.outerwear.id,
        }
        res = self.client.post("/api/outfits/ai-rate/", payload, format="json")

        self.assertEqual(res.status_code, 200)
        self.assertIn("ai_rating_score", res.data)
        self.assertIn("ai_rating_reasons", res.data)
        self.assertIn("ai_rating_breakdown", res.data)
        self.assertIn("ai_rated_at", res.data)
        self.assertGreaterEqual(float(res.data["ai_rating_score"]), 1.0)
        self.assertLessEqual(float(res.data["ai_rating_score"]), 5.0)
        self.assertEqual(len(res.data["ai_rating_reasons"]), 3)
        self.assertIn("clip", res.data["ai_rating_breakdown"])
        self.assertIn("color_harmony", res.data["ai_rating_breakdown"])
        self.assertIn("neutral_weather_fit", res.data["ai_rating_breakdown"])
        self.assertIn("overall_raw", res.data["ai_rating_breakdown"])

    @patch("api.recommend.scoring.clip_score", return_value=0.7)
    def test_ai_rate_rejects_items_from_other_user(self, _mock_clip):
        payload = {
            "topwear_id": self.other_top.id,
            "bottomwear_id": self.bottom.id,
            "shoes_id": self.shoes.id,
        }
        res = self.client.post("/api/outfits/ai-rate/", payload, format="json")

        self.assertEqual(res.status_code, 400)
        self.assertIn("error", res.data)

    def test_ai_rate_requires_main_slots(self):
        payload = {"topwear_id": self.top.id}
        res = self.client.post("/api/outfits/ai-rate/", payload, format="json")

        self.assertEqual(res.status_code, 400)
        self.assertIn("error", res.data)

    @patch("api.recommend.scoring.clip_score", return_value=0.86)
    def test_ai_rate_persists_when_outfit_id_is_provided(self, _mock_clip):
        outfit = Outfit.objects.create(
            user=self.user,
            name="Weekend Fit",
            topwear=self.top,
            bottomwear=self.bottom,
            shoes=self.shoes,
            outerwear=self.outerwear,
        )
        outfit.clothing_items.set([self.top, self.bottom, self.shoes, self.outerwear])

        payload = {
            "outfit_id": outfit.id,
            "topwear_id": self.top.id,
            "bottomwear_id": self.bottom.id,
            "shoes_id": self.shoes.id,
            "outerwear_id": self.outerwear.id,
        }
        res = self.client.post("/api/outfits/ai-rate/", payload, format="json")

        self.assertEqual(res.status_code, 200)
        outfit.refresh_from_db()
        self.assertIsNotNone(outfit.ai_rating_score)
        self.assertEqual(len(outfit.ai_rating_reasons), 3)
        self.assertIn("overall_raw", outfit.ai_rating_breakdown)
        self.assertIsNotNone(outfit.ai_rated_at)

    def test_outfit_update_clears_stale_ai_snapshot_when_items_change(self):
        outfit = Outfit.objects.create(
            user=self.user,
            name="Office Fit",
            topwear=self.top,
            bottomwear=self.bottom,
            shoes=self.shoes,
            ai_rating_score=4.3,
            ai_rating_reasons=["Good cohesion", "Color works", "Could refine shoes"],
            ai_rating_breakdown={
                "clip": 0.81,
                "color_harmony": 0.77,
                "neutral_weather_fit": 0.7,
                "overall_raw": 0.82,
            },
        )
        outfit.clothing_items.set([self.top, self.bottom, self.shoes])

        res = self.client.patch(
            f"/api/outfits/{outfit.id}/",
            {"topwear_id": self.top_alt.id},
            format="json",
        )
        self.assertEqual(res.status_code, 200)

        outfit.refresh_from_db()
        self.assertIsNone(outfit.ai_rating_score)
        self.assertEqual(outfit.ai_rating_reasons, [])
        self.assertEqual(outfit.ai_rating_breakdown, {})
        self.assertIsNone(outfit.ai_rated_at)


class RecommendationApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="reco-user", password="test1234")
        self.storage = StorageUnit.objects.create(
            user=self.user,
            name="Main Closet",
            type="closet",
        )
        self.client.force_authenticate(user=self.user)

        self._create_clothing("topwear", "shirt", "navy")
        self._create_clothing("topwear", "tee", "white")
        self._create_clothing("bottomwear", "jeans", "black")
        self._create_clothing("bottomwear", "trousers", "gray")
        self._create_clothing("footwear", "sneakers", "white")

    def _create_clothing(self, category, subcategory, color) -> ClothingItem:
        return ClothingItem.objects.create(
            user=self.user,
            storage_unit=self.storage,
            image=_png_upload(f"{category}-{subcategory}.png"),
            category=category,
            subcategory=subcategory,
            dominant_color=color,
            secondary_color="white",
            attributes=[],
        )

    @patch("api.recommend.scoring.clip_score", return_value=0.78)
    def test_recommendations_endpoint_returns_three_results(self, _mock_clip):
        payload = {"weather": {"temperature": "cool", "weather": "dry"}}
        res = self.client.post("/api/recommendations/", payload, format="json")

        self.assertEqual(res.status_code, 200)
        self.assertIn("outfits", res.data)
        self.assertIn("fallback_used", res.data)
        self.assertIn("metadata", res.data)
        self.assertEqual(len(res.data["outfits"]), 3)
        self.assertEqual(res.data["metadata"]["temperature"], "cool")
        self.assertEqual(res.data["metadata"]["weather"], "dry")

    @patch("api.recommend.scoring.clip_score", return_value=0.78)
    def test_recommendations_fallback_when_requested_occasion_lacks_items(self, _mock_clip):
        payload = {
            "weather": {"temperature": "cool", "weather": "dry"},
            "occasion": "date",
        }
        res = self.client.post("/api/recommendations/", payload, format="json")

        self.assertEqual(res.status_code, 200)
        self.assertIn("outfits", res.data)
        self.assertEqual(len(res.data["outfits"]), 3)
        self.assertEqual(res.data["occasion_fallback_used"], True)
        self.assertIn("warning", res.data)
        self.assertIn("Not enough items match that occasion", res.data["warning"])

    @patch("api.recommend.scoring.clip_score", return_value=0.78)
    def test_recommendations_accept_any_weather_and_temperature(self, _mock_clip):
        payload = {"weather": {"temperature": "any", "weather": "any"}}
        res = self.client.post("/api/recommendations/", payload, format="json")

        self.assertEqual(res.status_code, 200)
        self.assertIn("outfits", res.data)
        self.assertEqual(len(res.data["outfits"]), 3)
        self.assertEqual(res.data["metadata"]["temperature"], "any")
        self.assertEqual(res.data["metadata"]["weather"], "any")

    def test_recommendations_rejects_invalid_payload_shape(self):
        res = self.client.post("/api/recommendations/", [], format="json")
        self.assertEqual(res.status_code, 400)
        self.assertEqual(res.data.get("error"), "Invalid payload. Expected a JSON object.")

    def test_recommendations_rejects_non_object_weather(self):
        payload = {"weather": "dry"}
        res = self.client.post("/api/recommendations/", payload, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertEqual(
            res.data.get("error"),
            "weather must be an object with temperature and weather.",
        )

    def test_recommendations_rejects_non_string_occasion(self):
        payload = {
            "weather": {"temperature": "cool", "weather": "dry"},
            "occasion": {"value": "casual"},
        }
        res = self.client.post("/api/recommendations/", payload, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertEqual(res.data.get("error"), "occasion must be a string.")

    def test_item_context_score_ignores_rainy_label_for_generic_tshirt(self):
        top = self._create_clothing("topwear", "t-shirt", "white")
        top.detected_temp = "warm"
        top.detected_weather = "rainy"
        top.attributes = []
        top.save(update_fields=["detected_temp", "detected_weather", "attributes"])

        dry_score = scoring.item_context_score(
            top,
            {"temperature": "warm", "weather": "dry"},
            None,
        )
        rainy_score = scoring.item_context_score(
            top,
            {"temperature": "warm", "weather": "rainy"},
            None,
        )

        self.assertAlmostEqual(dry_score, rainy_score, places=4)


class ClothingMetadataExtractionTests(APITestCase):
    @patch("api.views.clothing.classify_clothing_weather")
    def test_weather_safe_drops_low_confidence_precipitation_label(self, classify_mock):
        classify_mock.return_value = {
            "temperature": "warm",
            "weather": "rainy",
            "temperature_confidence": 0.82,
            "temperature_margin": 0.12,
            "weather_confidence": 0.33,
            "weather_margin": 0.01,
            "is_precipitation_specific": False,
        }

        detected_temp, detected_weather = clothing_view._classify_weather_safe(
            Path("dummy.png"),
            category="Topwear",
            subcategory="T-Shirt",
        )

        self.assertEqual(detected_temp, "warm")
        self.assertIsNone(detected_weather)

    @patch("api.views.clothing.classify_clothing_weather")
    def test_weather_safe_keeps_strong_precipitation_label_when_specific(self, classify_mock):
        classify_mock.return_value = {
            "temperature": "cold",
            "weather": "rainy",
            "temperature_confidence": 0.77,
            "temperature_margin": 0.09,
            "weather_confidence": 0.71,
            "weather_margin": 0.05,
            "is_precipitation_specific": True,
        }

        detected_temp, detected_weather = clothing_view._classify_weather_safe(
            Path("dummy.png"),
            category="Outerwear",
            subcategory="Raincoat",
        )

        self.assertEqual(detected_temp, "cold")
        self.assertEqual(detected_weather, "rainy")

    @patch("api.views.clothing.predict_occasion_details")
    def test_predict_occasion_safe_returns_none_on_ambiguous_result(self, occasion_mock):
        occasion_mock.return_value = {
            "occasion": "",
            "raw_occasion": "Office",
            "confidence": 0.28,
            "margin": 0.01,
            "reliable": False,
        }

        detected_occasion, confidence = clothing_view._predict_occasion_safe(Path("dummy.png"))
        self.assertIsNone(detected_occasion)
        self.assertEqual(confidence, 0.28)


class ShoeUploadFlowTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="shoe-user", password="test1234")
        self.storage = StorageUnit.objects.create(
            user=self.user,
            name="Shoe Closet",
            type="closet",
        )
        self.client.force_authenticate(user=self.user)

    def _write_media_file(self, relative_path: str) -> Path:
        media_root = Path(settings.MEDIA_ROOT)
        target = media_root / relative_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(_png_upload("tmp.png").read())
        return target

    def test_process_shoe_uses_shoe_metadata_flow(self):
        original_path = self._write_media_file("clothing/review/test-original.png")
        segmented_path = self._write_media_file("clothing/segmented/test-segmented.png")
        original_url = "http://testserver/media/clothing/review/test-original.png"

        with (
            patch("api.views.clothing._authenticate_item", return_value=None),
            patch(
                "api.views.clothing._persist_original_upload",
                return_value=(original_url, original_path),
            ),
            patch(
                "api.views.clothing.segment_image",
                return_value="/media/clothing/segmented/test-segmented.png",
            ),
            patch(
                "api.views.clothing._resolve_media_path_safe",
                return_value=segmented_path,
            ),
            patch(
                "api.views.clothing._extract_colors_safe",
                return_value={"dominant_color": "Black", "secondary_color": "White"},
            ),
            patch(
                "api.views.clothing.classify_shoe_metadata",
                return_value=("Shoe", "Sneakers", "Sports", ["mesh"]),
            ) as shoe_mock,
            patch("api.views.clothing._classify_clothing_safe") as clothing_mock,
            patch("api.views.clothing._predict_occasion_safe") as occasion_mock,
            patch(
                "api.views.clothing._classify_weather_safe",
                return_value=("cool", "dry"),
            ),
        ):
            res = self.client.post(
                "/api/clothing/process/",
                {"image": _png_upload("shoe-upload.png"), "is_shoe": "true"},
            )

        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["is_shoe"], True)
        self.assertEqual(res.data["category"], "Shoes")
        self.assertEqual(res.data["subcategory"], "Sneakers")
        self.assertEqual(res.data["occasion"], "Sports")
        shoe_mock.assert_called_once()
        clothing_mock.assert_not_called()
        occasion_mock.assert_not_called()

    def test_save_shoe_forces_shoe_category(self):
        original_path = self._write_media_file("clothing/review/test-save-source.png")
        original_url = "http://testserver/media/clothing/review/test-save-source.png"

        with patch(
            "api.views.clothing._resolve_media_path_safe",
            return_value=original_path,
        ):
            res = self.client.post(
                "/api/clothing/save/",
                {
                    "storage_unit": self.storage.id,
                    "original_image": original_url,
                    "use_segmentation": False,
                    "is_shoe": True,
                    "category": "Topwear",
                    "subcategory": "Sneakers",
                    "dominant_color": "Black",
                    "secondary_color": "White",
                    "occasion": "Sports",
                    "attributes": ["mesh"],
                    "detected_temp": "cool",
                    "detected_weather": "dry",
                },
                format="json",
            )

        self.assertEqual(res.status_code, 201)
        clothing = ClothingItem.objects.get(id=res.data["id"])
        self.assertEqual(clothing.category, "Shoes")
        self.assertEqual(clothing.subcategory.lower(), "sneakers")
        self.assertEqual(clothing.occasion, "Sports")

    def test_update_shoe_keeps_category_locked(self):
        clothing = ClothingItem.objects.create(
            user=self.user,
            storage_unit=self.storage,
            image=_png_upload("shoe-existing.png"),
            category="footwear",
            subcategory="sneakers",
            dominant_color="Black",
            secondary_color="White",
            attributes=[],
        )

        res = self.client.put(
            f"/api/clothing/{clothing.id}/update/",
            {
                "category": "Topwear",
                "occasion": "Formal",
            },
            format="json",
        )

        self.assertEqual(res.status_code, 200)
        clothing.refresh_from_db()
        self.assertEqual(clothing.category, "Shoes")
        self.assertEqual(clothing.occasion, "Formal")


class OutfitRoutesParityTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="outfit-user", password="test1234")
        self.storage = StorageUnit.objects.create(user=self.user, name="Main Closet", type="closet")
        self.client.force_authenticate(user=self.user)

        self.top = ClothingItem.objects.create(
            user=self.user,
            storage_unit=self.storage,
            image=_png_upload("top.png"),
            category="topwear",
            subcategory="shirt",
            dominant_color="Navy",
            secondary_color="White",
            attributes=[],
        )
        self.bottom = ClothingItem.objects.create(
            user=self.user,
            storage_unit=self.storage,
            image=_png_upload("bottom.png"),
            category="bottomwear",
            subcategory="jeans",
            dominant_color="Black",
            secondary_color="White",
            attributes=[],
        )
        self.shoes = ClothingItem.objects.create(
            user=self.user,
            storage_unit=self.storage,
            image=_png_upload("shoes.png"),
            category="footwear",
            subcategory="sneakers",
            dominant_color="White",
            secondary_color="Black",
            attributes=[],
        )
        self.outfit = Outfit.objects.create(
            user=self.user,
            name="Daily Fit",
            topwear=self.top,
            bottomwear=self.bottom,
            shoes=self.shoes,
        )
        self.outfit.clothing_items.set([self.top, self.bottom, self.shoes])

    def test_outfit_list_invalid_favourite_filter_returns_400(self):
        res = self.client.get("/api/outfits/?is_favourite=not-a-bool")

        self.assertEqual(res.status_code, 400)
        self.assertEqual(res.data.get("error"), "is_favourite must be a boolean value.")

    def test_toggle_favourite_returns_full_outfit_payload(self):
        res = self.client.post(f"/api/outfits/{self.outfit.id}/toggle-favourite/", {}, format="json")

        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["id"], self.outfit.id)
        self.assertEqual(res.data["is_favourite"], True)
        self.assertIn("topwear_item", res.data)
        self.assertIn("bottomwear_item", res.data)
        self.assertIn("shoes_item", res.data)

    def test_wear_only_increments_once_per_local_day(self):
        first = self.client.post(f"/api/outfits/{self.outfit.id}/wear/", {}, format="json")
        second = self.client.post(f"/api/outfits/{self.outfit.id}/wear/", {}, format="json")

        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 200)
        self.outfit.refresh_from_db()
        self.assertEqual(self.outfit.wear_count, 1)
        self.assertIsNotNone(self.outfit.last_worn_at)


class AccessoryRoutesParityTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="acc-user", password="test1234")
        self.other_user = User.objects.create_user(username="acc-other", password="test1234")
        self.storage = StorageUnit.objects.create(user=self.user, name="Accessory Box", type="box")
        self.other_storage = StorageUnit.objects.create(user=self.other_user, name="Other Box", type="box")
        self.client.force_authenticate(user=self.user)

    def _write_media_file(self, relative_path: str) -> Path:
        media_root = Path(settings.MEDIA_ROOT)
        target = media_root / relative_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(_png_upload("tmp.png").read())
        return target

    def test_process_accessory_returns_expected_payload(self):
        self._write_media_file("accessories/segmented/test-segmented.png")
        with (
            patch(
                "api.views.accessory.segment_image",
                return_value="/media/accessories/segmented/test-segmented.png",
            ),
            patch(
                "api.views.accessory._extract_colors_safe",
                return_value={"dominant_color": "Black", "secondary_color": "White"},
            ),
        ):
            res = self.client.post("/api/accessories/process/", {"image": _png_upload("acc.png")})

        self.assertEqual(res.status_code, 200)
        self.assertEqual(
            res.data["segmented_image"],
            "http://testserver/media/accessories/segmented/test-segmented.png",
        )
        self.assertEqual(res.data["dominant_color"], "Black")
        self.assertEqual(res.data["secondary_color"], "White")

    def test_save_accessory_returns_id_only(self):
        self._write_media_file("accessories/segmented/test-save.png")
        res = self.client.post(
            "/api/accessories/save/",
            {
                "segmented_image": "http://testserver/media/accessories/segmented/test-save.png",
                "storage_unit": self.storage.id,
                "name": "Watch",
                "description": "Black strap",
                "dominant_color": "Black",
                "secondary_color": "Silver",
            },
            format="json",
        )

        self.assertEqual(res.status_code, 201)
        self.assertEqual(set(res.data.keys()), {"id"})
        accessory = AccessoryItem.objects.get(id=res.data["id"])
        self.assertEqual(accessory.user_id, self.user.id)
        self.assertEqual(accessory.storage_unit_id, self.storage.id)
        self.assertEqual(accessory.name, "Watch")

    def test_accessory_all_and_detail_update_delete_toggle_routes(self):
        mine = AccessoryItem.objects.create(
            user=self.user,
            storage_unit=self.storage,
            image=_png_upload("mine.png"),
            name="Bracelet",
            description="Leather",
            dominant_color="Brown",
            secondary_color="Black",
        )
        AccessoryItem.objects.create(
            user=self.other_user,
            storage_unit=self.other_storage,
            image=_png_upload("other.png"),
            name="Ring",
            description="Silver",
            dominant_color="Silver",
            secondary_color="White",
        )

        list_res = self.client.get("/api/accessories/all/")
        self.assertEqual(list_res.status_code, 200)
        returned_ids = {row["id"] for row in list_res.data}
        self.assertEqual(returned_ids, {mine.id})

        detail_res = self.client.get(f"/api/accessories/{mine.id}/")
        self.assertEqual(detail_res.status_code, 200)
        self.assertEqual(detail_res.data["id"], mine.id)

        update_res = self.client.put(
            f"/api/accessories/{mine.id}/",
            {"name": "Bracelet Updated", "description": "Updated desc"},
            format="json",
        )
        self.assertEqual(update_res.status_code, 200)
        self.assertEqual(update_res.data["name"], "Bracelet Updated")

        toggle_res = self.client.post(f"/api/accessories/{mine.id}/toggle-favourite/", {}, format="json")
        self.assertEqual(toggle_res.status_code, 200)
        self.assertEqual(toggle_res.data["id"], mine.id)
        self.assertEqual(toggle_res.data["is_favourite"], True)

        delete_res = self.client.delete(f"/api/accessories/{mine.id}/")
        self.assertEqual(delete_res.status_code, 204)

        not_found_res = self.client.get(f"/api/accessories/{mine.id}/")
        self.assertEqual(not_found_res.status_code, 404)
        self.assertEqual(not_found_res.data.get("error"), "Not found")


class NonClothingRoutesParityTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="nonc-user", password="test1234")
        self.storage = StorageUnit.objects.create(user=self.user, name="Shelf", type="shelf")
        self.other_storage = StorageUnit.objects.create(user=self.user, name="Box", type="box")
        self.client.force_authenticate(user=self.user)

    def test_non_clothing_create_list_detail_update_delete(self):
        create_res = self.client.post(
            "/api/non-clothing/",
            {"storage_id": self.storage.id, "name": "Detergent", "description": "Liquid"},
            format="json",
        )
        self.assertEqual(create_res.status_code, 201)
        item_id = create_res.data["id"]

        list_res = self.client.get("/api/non-clothing/list/")
        self.assertEqual(list_res.status_code, 200)
        self.assertEqual(len(list_res.data), 1)
        self.assertEqual(list_res.data[0]["id"], item_id)

        detail_res = self.client.get(f"/api/non-clothing/{item_id}/")
        self.assertEqual(detail_res.status_code, 200)
        self.assertEqual(detail_res.data["name"], "Detergent")

        update_res = self.client.put(
            f"/api/non-clothing/{item_id}/",
            {"name": "Detergent Pro", "description": "Updated"},
            format="json",
        )
        self.assertEqual(update_res.status_code, 200)
        self.assertEqual(update_res.data["name"], "Detergent Pro")

        delete_res = self.client.delete(f"/api/non-clothing/{item_id}/")
        self.assertEqual(delete_res.status_code, 204)

        not_found = self.client.get(f"/api/non-clothing/{item_id}/")
        self.assertEqual(not_found.status_code, 404)
        self.assertEqual(not_found.data.get("error"), "Not found")

    def test_non_clothing_update_ignores_storage_unit_field(self):
        item = NonClothingItem.objects.create(
            user=self.user,
            storage_unit=self.storage,
            name="Belt",
            description="Brown",
        )

        res = self.client.put(
            f"/api/non-clothing/{item.id}/",
            {"storage_unit": self.other_storage.id, "description": "Still here"},
            format="json",
        )

        self.assertEqual(res.status_code, 200)
        item.refresh_from_db()
        self.assertEqual(item.storage_unit_id, self.storage.id)
        self.assertEqual(item.description, "Still here")

    def test_non_clothing_blank_name_rejected(self):
        item = NonClothingItem.objects.create(
            user=self.user,
            storage_unit=self.storage,
            name="Hat",
            description="Wool",
        )

        res = self.client.put(
            f"/api/non-clothing/{item.id}/",
            {"name": "   "},
            format="json",
        )

        self.assertEqual(res.status_code, 400)
        self.assertEqual(res.data.get("error"), "Name is required")


class StorageRoutesParityTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="storage-user", password="test1234")
        self.client.force_authenticate(user=self.user)

    def _create_clothing(self, storage, category="topwear", subcategory="shirt", color="Navy"):
        return ClothingItem.objects.create(
            user=self.user,
            storage_unit=storage,
            image=_png_upload("storage-clothing.png"),
            category=category,
            subcategory=subcategory,
            dominant_color=color,
            secondary_color="White",
            attributes=[],
        )

    def test_storage_create_and_recursive_view_payload(self):
        parent = StorageUnit.objects.create(user=self.user, name="Closet", type="closet")
        child = StorageUnit.objects.create(user=self.user, name="Shelf 1", type="shelf", parent_storage=parent)
        self._create_clothing(child)
        NonClothingItem.objects.create(
            user=self.user,
            storage_unit=child,
            name="Lint Roller",
            description="Sticky",
        )

        res = self.client.get(f"/api/storage/{parent.id}/view/")

        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["storage"]["id"], parent.id)
        self.assertEqual(res.data["counts"]["clothing"], 1)
        self.assertEqual(res.data["counts"]["non_clothing"], 1)
        self.assertEqual(res.data["counts"]["total"], 2)
        self.assertEqual(len(res.data["clothes"]), 1)
        self.assertEqual(len(res.data["non_clothing_items"]), 1)

    def test_storage_create_route_accepts_zero_parent_as_top_level(self):
        res = self.client.post(
            "/api/storage/",
            {"name": "Top Box", "type": "box", "parent_storage": 0},
            format="json",
        )

        self.assertEqual(res.status_code, 201)
        created = StorageUnit.objects.get(id=res.data["id"])
        self.assertIsNone(created.parent_storage_id)

    def test_storage_update_parent_storage_null_keeps_existing_parent(self):
        parent = StorageUnit.objects.create(user=self.user, name="Wardrobe", type="wardrobe")
        child = StorageUnit.objects.create(user=self.user, name="Drawer A", type="drawer", parent_storage=parent)

        res = self.client.put(
            f"/api/storage/{child.id}/",
            {"parent_storage": None},
            format="json",
        )

        self.assertEqual(res.status_code, 200)
        child.refresh_from_db()
        self.assertEqual(child.parent_storage_id, parent.id)

    def test_storage_update_empty_string_clears_parent(self):
        parent = StorageUnit.objects.create(user=self.user, name="Wardrobe", type="wardrobe")
        child = StorageUnit.objects.create(user=self.user, name="Drawer B", type="drawer", parent_storage=parent)

        res = self.client.put(
            f"/api/storage/{child.id}/",
            {"parent_storage": ""},
            format="json",
        )

        self.assertEqual(res.status_code, 200)
        child.refresh_from_db()
        self.assertIsNone(child.parent_storage_id)

    def test_storage_delete_rejects_non_empty_storage(self):
        parent = StorageUnit.objects.create(user=self.user, name="Main", type="closet")
        child = StorageUnit.objects.create(user=self.user, name="Inner", type="shelf", parent_storage=parent)

        res = self.client.delete(f"/api/storage/{parent.id}/")

        self.assertEqual(res.status_code, 400)
        self.assertEqual(
            res.data.get("error"),
            "Cannot delete storage that has items or sub-storages",
        )
        self.assertTrue(StorageUnit.objects.filter(id=parent.id).exists())
        self.assertTrue(StorageUnit.objects.filter(id=child.id).exists())


class ClothingRoutesParityTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="cloth-user", password="test1234")
        self.storage = StorageUnit.objects.create(user=self.user, name="Closet", type="closet")
        self.client.force_authenticate(user=self.user)

        self.item = ClothingItem.objects.create(
            user=self.user,
            storage_unit=self.storage,
            image=_png_upload("cloth-item.png"),
            category="Topwear",
            subcategory="Shirt",
            dominant_color="Blue",
            secondary_color="White",
            attributes=[],
        )

    def test_clothing_recent_all_and_detail_routes(self):
        recent = self.client.get("/api/clothing/recent/")
        self.assertEqual(recent.status_code, 200)
        self.assertEqual(len(recent.data), 1)
        self.assertEqual(recent.data[0]["id"], self.item.id)
        self.assertIn("image", recent.data[0])
        self.assertIn("is_favourite", recent.data[0])

        all_items = self.client.get("/api/clothing/all/")
        self.assertEqual(all_items.status_code, 200)
        self.assertEqual(len(all_items.data), 1)
        self.assertEqual(all_items.data[0]["id"], self.item.id)
        self.assertIn("storage_unit", all_items.data[0])

        detail = self.client.get(f"/api/clothing/{self.item.id}/")
        self.assertEqual(detail.status_code, 200)
        self.assertEqual(detail.data["id"], self.item.id)

    def test_clothing_toggle_and_delete_routes(self):
        toggle = self.client.post(f"/api/clothing/{self.item.id}/toggle-favourite/", {}, format="json")
        self.assertEqual(toggle.status_code, 200)
        self.assertEqual(toggle.data["id"], self.item.id)
        self.assertEqual(toggle.data["is_favourite"], True)

        delete = self.client.delete(f"/api/clothing/{self.item.id}/delete/")
        self.assertEqual(delete.status_code, 204)
        self.assertFalse(ClothingItem.objects.filter(id=self.item.id).exists())


class FeedbackRoutesParityTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="feedback-user", password="test1234")
        self.client.force_authenticate(user=self.user)

    def test_feedback_submit_success(self):
        res = self.client.post(
            "/api/feedback/",
            {"message": "Love the app", "rating": 5},
            format="json",
        )

        self.assertEqual(res.status_code, 201)
        self.assertIn("id", res.data)
        self.assertEqual(res.data["message"], "Love the app")
        self.assertEqual(res.data["rating"], 5)
        self.assertIn("created_at", res.data)

    def test_feedback_validation_errors(self):
        missing_message = self.client.post("/api/feedback/", {"message": "   "}, format="json")
        self.assertEqual(missing_message.status_code, 400)
        self.assertEqual(missing_message.data.get("detail"), "Message is required.")

        bad_rating = self.client.post(
            "/api/feedback/",
            {"message": "ok", "rating": "bad"},
            format="json",
        )
        self.assertEqual(bad_rating.status_code, 400)
        self.assertEqual(bad_rating.data.get("detail"), "Rating must be a number.")


class AuthRoutesParityTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="auth-user",
            email="auth@example.com",
            password="test1234",
            first_name="Auth",
            last_name="User",
        )
        self.client.force_authenticate(user=self.user)

    def test_profile_get_and_put(self):
        get_res = self.client.get("/api/profile/")
        self.assertEqual(get_res.status_code, 200)
        self.assertEqual(get_res.data["username"], "auth-user")
        self.assertEqual(get_res.data["email"], "auth@example.com")
        self.assertEqual(get_res.data["role"], "user")

        put_res = self.client.put(
            "/api/profile/",
            {"first_name": "New", "last_name": "Name"},
            format="json",
        )
        self.assertEqual(put_res.status_code, 200)
        self.assertEqual(put_res.data["message"], "Profile updated successfully")
        self.assertEqual(put_res.data["first_name"], "New")
        self.assertEqual(put_res.data["last_name"], "Name")

    def test_profile_validation_quirk_and_logout(self):
        empty_name = self.client.put("/api/profile/", {"first_name": ""}, format="json")
        self.assertEqual(empty_name.status_code, 200)
        self.assertEqual(empty_name.data.get("error"), "First name cannot be empty")

        invalid_logout = self.client.post("/api/auth/logout/", {"refresh": "bad"}, format="json")
        self.assertEqual(invalid_logout.status_code, 400)
        self.assertEqual(invalid_logout.data.get("detail"), "Invalid refresh token.")

        valid_refresh = str(RefreshToken.for_user(self.user))
        valid_logout = self.client.post("/api/auth/logout/", {"refresh": valid_refresh}, format="json")
        self.assertEqual(valid_logout.status_code, 200)
        self.assertEqual(valid_logout.data.get("detail"), "Logged out")


class AdminRoutesParityTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            username="admin-user",
            email="admin@example.com",
            password="test1234",
            is_staff=True,
        )
        self.member = User.objects.create_user(
            username="member-user",
            email="member@example.com",
            password="test1234",
        )

        self.admin_storage = StorageUnit.objects.create(user=self.admin, name="Admin Closet", type="closet")
        self.member_storage = StorageUnit.objects.create(user=self.member, name="Member Closet", type="closet")
        self.member_item = ClothingItem.objects.create(
            user=self.member,
            storage_unit=self.member_storage,
            image=_png_upload("member-item.png"),
            category="Topwear",
            subcategory="Shirt",
            dominant_color="Blue",
            secondary_color="White",
            attributes=[],
        )
        self.feedback = BetaFeedback.objects.create(user=self.member, message="Needs dark mode", rating=4)

    def test_admin_dashboard_requires_admin(self):
        self.client.force_authenticate(user=self.member)
        res = self.client.get("/api/admin/dashboard/")

        self.assertEqual(res.status_code, 403)
        self.assertEqual(res.data.get("detail"), "Admin access required")

    def test_admin_users_self_guard_and_feedback_mark_read(self):
        self.client.force_authenticate(user=self.admin)

        users = self.client.get("/api/admin/users/?limit=5")
        self.assertEqual(users.status_code, 200)
        self.assertIn("results", users.data)
        usernames = {row["username"] for row in users.data["results"]}
        self.assertIn("admin-user", usernames)
        self.assertIn("member-user", usernames)

        self_block = self.client.post(
            f"/api/admin/users/{self.admin.id}/active/",
            {"is_active": False},
            format="json",
        )
        self.assertEqual(self_block.status_code, 400)
        self.assertEqual(self_block.data.get("detail"), "You cannot change your own active status.")

        mark_read = self.client.post(
            f"/api/admin/feedback/{self.feedback.id}/read/",
            {"is_read": False},
            format="json",
        )
        self.assertEqual(mark_read.status_code, 200)
        self.assertEqual(mark_read.data["id"], self.feedback.id)
        self.assertEqual(mark_read.data["is_read"], False)

    def test_admin_clothing_detail_get_and_delete(self):
        self.client.force_authenticate(user=self.admin)

        detail = self.client.get(f"/api/admin/clothing/{self.member_item.id}/")
        self.assertEqual(detail.status_code, 200)
        self.assertEqual(detail.data["id"], self.member_item.id)
        self.assertEqual(detail.data["user"]["id"], self.member.id)

        delete = self.client.delete(f"/api/admin/clothing/{self.member_item.id}/")
        self.assertEqual(delete.status_code, 204)
        self.assertFalse(ClothingItem.objects.filter(id=self.member_item.id).exists())
