from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import serializers, viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ..models import BetaFeedback


class FeedbackSchemaSerializer(serializers.Serializer):
    message = serializers.CharField()
    rating = serializers.IntegerField(required=False, allow_null=True, min_value=1, max_value=5)


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


class FeedbackResponseSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    message = serializers.CharField()
    rating = serializers.IntegerField(allow_null=True)
    created_at = serializers.DateTimeField()


@extend_schema_view(
    create=extend_schema(
        summary="Submit beta feedback",
        request=FeedbackSchemaSerializer,
        responses={201: FeedbackResponseSerializer},
    ),
)
class FeedbackViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = FeedbackSchemaSerializer

    def create(self, request):
        return submit_feedback(request)
