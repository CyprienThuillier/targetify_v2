import uuid
from django.db import models
from django.conf import settings

class Job(models.Model):
    STATUS_CHOICES = [
        ("pending", "Pending"),
        ("running", "Running"),
        ("completed", "Completed"),
        ("failed", "Failed"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="jobs")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="pending")
    job_type = models.CharField(max_length=50, default="maps_search")
    search_query = models.CharField(max_length=255)
    city = models.CharField(max_length=255, blank=True, default="")
    max_results = models.IntegerField(default=50)
    total_targets = models.IntegerField(default=0)
    processed_targets = models.IntegerField(default=0)
    file_path = models.CharField(max_length=500, blank=True, default="")
    error_message = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.search_query} ({self.status})"


class Lead(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    job = models.ForeignKey(Job, on_delete=models.CASCADE, related_name="leads")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="leads")
    business_name = models.CharField(max_length=255, blank=True, default="")
    website = models.URLField(max_length=500, blank=True, default="")
    email = models.EmailField(blank=True, default="")
    phone = models.CharField(max_length=50, blank=True, default="")
    city = models.CharField(max_length=255, blank=True, default="")
    additional_data = models.JSONField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.business_name or str(self.id)


class SearchedUrl(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    url = models.URLField(max_length=1000)
    scraped_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "url")
