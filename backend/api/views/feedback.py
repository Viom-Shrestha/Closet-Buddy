from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ..models import BetaFeedback


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def submit_feedback(request):
    message = (request.data.get("message") or "").strip()
    if not message:
        return Response({"detail": "Message is required."}, status=400)

    rating_raw = request.data.get("rating")
    rating = None
    if rating_raw not in [None, ""]:
        try:
            rating = int(rating_raw)
        except (TypeError, ValueError):
            return Response({"detail": "Rating must be a number."}, status=400)
        if rating < 1 or rating > 5:
            return Response({"detail": "Rating must be between 1 and 5."}, status=400)

    feedback = BetaFeedback.objects.create(
        user=request.user,
        message=message,
        rating=rating,
    )

    return Response(
        {
            "id": feedback.id,
            "message": feedback.message,
            "rating": feedback.rating,
            "created_at": feedback.created_at.isoformat(),
        },
        status=201,
    )
