from django.urls import path
from . import views

urlpatterns = [
    path("", views.dashboard, name="dashboard"),
    path("new/", views.new_job, name="new_job"),
    path("<uuid:job_id>/", views.job_detail, name="job_detail"),
    path("<uuid:job_id>/download/", views.download_csv, name="download_csv"),
    path("profile/", views.profile, name="profile"),
]
