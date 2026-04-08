from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import viewsets
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


def recommend_outfits_view(request):
    payload = request.data or {}
    weather = payload.get("weather") or {}

    temperature = coerce_temperature_label(weather.get("temperature"), allow_unknown=True) or ""
    condition = coerce_weather_label(weather.get("weather"), allow_unknown=True) or ""

    if temperature and temperature not in ALLOWED_TEMPERATURES:
        return Response({"error": "Invalid temperature label."}, status=400)
    if condition and condition not in ALLOWED_WEATHER:
        return Response({"error": "Invalid weather label."}, status=400)
    if not temperature or not condition:
        return Response({"error": "weather.temperature and weather.weather are required."}, status=400)

    occasion = payload.get("occasion")
    prompt = payload.get("prompt")

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
    if data.get("occasion_fallback_used") and (occasion or "").strip():
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
    return Response(
        {
            "canonical_occasions": [*canonical_order, *extras],
            "attribute_signals": sorted(filters.OCCASION_ATTRIBUTE_SIGNALS),
            "sort_order": list(filters.OCCASION_SORT_ORDER),
        },
        status=200,
    )


@extend_schema_view(
    recommend=extend_schema(summary="Recommend outfits"),
    occasions=extend_schema(summary="Get occasion catalog"),
)
class RecommendationViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    def recommend(self, request):
        return recommend_outfits_view(request)

    def occasions(self, request):
        return occasion_catalog_view(request)
