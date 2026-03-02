from django.contrib import admin
from django.urls import path, include
from . import views

urlpatterns = [
    path("admin/", admin.site.urls),
    path("", views.landing, name="landing"),
    path("accounts/", include("accounts.urls")),
    path("jobs/", include("jobs.urls")),
    path("billing/", include("billing.urls")),
]
