from drf_spectacular.utils import extend_schema
from rest_framework import serializers, viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ..metadata_normalization import (
    ALLOWED_TEMPERATURES,
    ALLOWED_WEATHER,
    coerce_temperature_label,
    coerce_weather_label,
)
from ..recommend import filters
from ..recommend.engine import recommend_outfits


RECOMMENDATION_LIMIT = 3


class RecommendationWeatherSerializer(serializers.Serializer):
    temperature = serializers.ChoiceField(choices=sorted(ALLOWED_TEMPERATURES))
    weather = serializers.ChoiceField(choices=sorted(ALLOWED_WEATHER))


class RecommendationRequestSerializer(serializers.Serializer):
    weather = RecommendationWeatherSerializer()
    occasion = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    prompt = serializers.CharField(required=False, allow_blank=True, allow_null=True)


class RecommendationOutfitSerializer(serializers.Serializer):
    topwear_id = serializers.IntegerField()
    bottomwear_id = serializers.IntegerField()
    shoes_id = serializers.IntegerField()
    outerwear_id = serializers.IntegerField(required=False, allow_null=True)


class RecommendationMetadataSerializer(serializers.Serializer):
    temperature = serializers.ChoiceField(choices=sorted(ALLOWED_TEMPERATURES))
    weather = serializers.ChoiceField(choices=sorted(ALLOWED_WEATHER))
    available_occasions = serializers.ListField(child=serializers.CharField(), required=False)
    occasion_applied = serializers.CharField(allow_blank=True)


class RecommendationResponseSerializer(serializers.Serializer):
    outfits = RecommendationOutfitSerializer(many=True)
    fallback_used = serializers.BooleanField()
    occasion_fallback_used = serializers.BooleanField()
    metadata = RecommendationMetadataSerializer()
    warning = serializers.CharField(required=False)


class RecommendationErrorSerializer(serializers.Serializer):
    error = serializers.CharField()


class OccasionCatalogResponseSerializer(serializers.Serializer):
    classifier_occasions = serializers.ListField(child=serializers.CharField())
    canonical_occasions = serializers.ListField(child=serializers.CharField())
    attribute_signals = serializers.ListField(child=serializers.CharField())
    sort_order = serializers.ListField(child=serializers.CharField())
    aliases = serializers.DictField(child=serializers.CharField(allow_blank=True))


def _coerce_optional_text(value, field_name: str):
    if value is None:
        return None
    if isinstance(value, str):
        text = value.strip()
        return text or None
    return Response({"error": f"{field_name} must be a string."}, status=400)


def recommend_outfits_view(request):
    payload = request.data or {}
    if not isinstance(payload, dict):
        return Response({"error": "Invalid payload. Expected a JSON object."}, status=400)

    weather = payload.get("weather") or {}
    if not isinstance(weather, dict):
        return Response(
            {"error": "weather must be an object with temperature and weather."},
            status=400,
        )

    temperature = coerce_temperature_label(weather.get("temperature"), allow_unknown=True) or ""
    condition = coerce_weather_label(weather.get("weather"), allow_unknown=True) or ""

    if temperature and temperature not in ALLOWED_TEMPERATURES:
        return Response({"error": "Invalid temperature label."}, status=400)
    if condition and condition not in ALLOWED_WEATHER:
        return Response({"error": "Invalid weather label."}, status=400)
    if not temperature or not condition:
        return Response({"error": "weather.temperature and weather.weather are required."}, status=400)

    occasion = _coerce_optional_text(payload.get("occasion"), "occasion")
    if isinstance(occasion, Response):
        return occasion
    prompt = _coerce_optional_text(payload.get("prompt"), "prompt")
    if isinstance(prompt, Response):
        return prompt

    data = recommend_outfits(
        user=request.user,
        weather={"temperature": temperature, "weather": condition},
        occasion=occasion,
        prompt=prompt,
        limit=RECOMMENDATION_LIMIT,
    )
    available_occasions = data.get("available_occasions") or []

    response_body = {
        "outfits": data["results"],
        "fallback_used": data["fallback_used"],
        "occasion_fallback_used": data.get("occasion_fallback_used", False),
        "metadata": {
            "temperature": temperature,
            "weather": condition,
            "available_occasions": available_occasions,
            "occasion_applied": data.get("occasion_applied") or "",
        },
    }
    warnings = []
    if data.get("occasion_fallback_used") and occasion:
        warnings.append(
            "Not enough items match that occasion right now. Showing best available outfits based on weather and overall style match."
        )
    if data["fallback_used"]:
        warnings.append(
            "Not enough weather-appropriate items found. Showing best available matches."
        )
    if warnings:
        response_body["warning"] = " ".join(warnings)

    return Response(response_body, status=200)


def occasion_catalog_view(request):
    canonical_order = [
        name for name in filters.OCCASION_SORT_ORDER if name in filters.CANONICAL_OCCASIONS
    ]
    extras = sorted(filters.CANONICAL_OCCASIONS.difference(canonical_order))
    alias_map = dict(filters.OCCASION_ALIASES)
    if "any" not in alias_map:
        alias_map["any"] = ""
    return Response(
        {
            "classifier_occasions": list(filters.OCCASION_CLASSIFIER_ORDER),
            "canonical_occasions": [*canonical_order, *extras],
            "attribute_signals": sorted(filters.OCCASION_ATTRIBUTE_SIGNALS),
            "sort_order": list(filters.OCCASION_SORT_ORDER),
            "aliases": alias_map,
        },
        status=200,
    )


class RecommendationViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = RecommendationRequestSerializer

    @extend_schema(
        summary="Recommend outfits",
        request=RecommendationRequestSerializer,
        responses={
            200: RecommendationResponseSerializer,
            400: RecommendationErrorSerializer,
        },
    )
    def recommend(self, request):
        return recommend_outfits_view(request)

    @extend_schema(
        summary="Get occasion catalog",
        responses={200: OccasionCatalogResponseSerializer},
    )
    def occasions(self, request):
        return occasion_catalog_view(request)
