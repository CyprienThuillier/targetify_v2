import uuid
import os
from celery import shared_task
from django.utils import timezone

@shared_task(bind=True)
def run_scraping_job(self, job_id: str):
    # Import inside task to avoid circular imports at module load time
    from .models import Job, Lead, SearchedUrl
    from scraper.scraper_service import run_scrape

    try:
        job = Job.objects.get(id=job_id)
    except Job.DoesNotExist:
        return

    job.status = "running"
    job.save(update_fields=["status"])

    output_path = os.path.join("exports", f"job-{job_id}.csv")

    def on_result(result: dict):
        Lead.objects.create(
            job=job,
            user=job.user,
            business_name=result.get("name", ""),
            website=result.get("website", ""),
            phone=result.get("phone", ""),
            email=result.get("email", ""),
            city=result.get("address", ""),
            additional_data={
                "url": result.get("url"),
                "category": result.get("category"),
                "lead_score": result.get("lead_score"),
            },
        )
        Job.objects.filter(id=job_id).update(
            processed_targets=job.leads.count()
        )

    try:
        # Deduplication: filter already-scraped URLs for this user
        existing_urls = set(
            SearchedUrl.objects.filter(user=job.user).values_list("url", flat=True)
        )

        run_scrape(
            search_query=job.search_query,
            city=job.city or "",
            max_results=job.max_results,
            output_path=output_path,
            on_result=on_result,
            existing_urls=existing_urls,
            user=job.user,
        )

        job.status = "completed"
        job.file_path = output_path
        job.completed_at = timezone.now()
        job.save(update_fields=["status", "file_path", "completed_at"])

    except Exception as e:
        job.status = "failed"
        job.error_message = str(e)
        job.save(update_fields=["status", "error_message"])
        raise
