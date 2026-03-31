from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ..recommend.engine import recommend_outfits


ALLOWED_TEMPERATURES = {"freezing", "cold", "cool", "warm", "hot"}
ALLOWED_WEATHER = {"rainy", "snowy", "windy", "humid", "dry"}
RECOMMENDATION_LIMIT = 3


def _normalize_text(value):
    return (value or "").strip().lower()


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def recommend_outfits_view(request):
    payload = request.data or {}
    weather = payload.get("weather") or {}

    temperature = _normalize_text(weather.get("temperature"))
    condition = _normalize_text(weather.get("weather"))

    if temperature and temperature not in ALLOWED_TEMPERATURES:
        return Response({"error": "Invalid temperature label."}, status=400)
    if condition and condition not in ALLOWED_WEATHER:
        return Response({"error": "Invalid weather label."}, status=400)
    if not temperature or not condition:
        return Response({"error": "weather.temperature and weather.weather are required."}, status=400)

    occasion = payload.get("occasion")
    prompt = payload.get("prompt")

    results = recommend_outfits(
        user=request.user,
        weather={"temperature": temperature, "weather": condition},
        occasion=occasion,
        prompt=prompt,
        limit=RECOMMENDATION_LIMIT,
    )

    return Response(results, status=200)
