import uuid
from django.db import models
from django.conf import settings

class Subscription(models.Model):
    PLAN_CHOICES = [("free", "Free"), ("starter", "Starter"), ("pro", "Pro")]
    STATUS_CHOICES = [("active", "Active"), ("canceled", "Canceled"), ("past_due", "Past Due")]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="subscription")
    stripe_customer_id = models.CharField(max_length=255, blank=True, default="")
    stripe_subscription_id = models.CharField(max_length=255, blank=True, default="")
    plan_name = models.CharField(max_length=20, choices=PLAN_CHOICES, default="free")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="active")
    current_period_end = models.DateTimeField(null=True, blank=True)
    monthly_lead_limit = models.IntegerField(default=10)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user} — {self.plan_name}"


class Payment(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="payments")
    stripe_payment_intent_id = models.CharField(max_length=255, unique=True, blank=True, default="")
    amount = models.IntegerField()  # in cents
    currency = models.CharField(max_length=10, default="eur")
    status = models.CharField(max_length=50)  # succeeded, failed, refunded
    payment_type = models.CharField(max_length=50)  # subscription, one_time
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user} — {self.amount/100}{self.currency} ({self.status})"
