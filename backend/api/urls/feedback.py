from django.urls import path

from ..views.feedback import FeedbackViewSet

submit_feedback = FeedbackViewSet.as_view({"post": "create"})

urlpatterns = [
    path("", submit_feedback),
]
