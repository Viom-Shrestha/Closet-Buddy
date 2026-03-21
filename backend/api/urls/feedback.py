from django.urls import path

from ..views.feedback import submit_feedback

urlpatterns = [
    path("", submit_feedback),
]
