from django.urls import path
from . import views

urlpatterns = [
    path("pricing/", views.pricing, name="pricing"),
    path("checkout/<str:plan>/", views.checkout, name="checkout"),
    path("success/", views.success, name="billing_success"),
    path("webhook/", views.stripe_webhook, name="stripe_webhook"),
]
