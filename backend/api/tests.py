import base64
from unittest.mock import patch

from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APITestCase

from .models import ClothingItem, Outfit, StorageUnit


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
