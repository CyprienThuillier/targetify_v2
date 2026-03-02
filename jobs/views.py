import os
import uuid
import bleach
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.http import FileResponse, Http404
from django.utils import timezone
from .models import Job, Lead
from .forms import NewJobForm
from .tasks import run_scraping_job

def sanitize(value):
    return bleach.clean(value, tags=[], strip=True)

def check_limits(user):
    """Returns an error string if user is over the free limit, else None."""
    month_start = timezone.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    leads_this_month = Lead.objects.filter(user=user, created_at__gte=month_start).count()
    if leads_this_month >= 10:
        return "Free tier limit reached (10 leads/month). Upgrade to continue."
    return None

@login_required
def dashboard(request):
    jobs = Job.objects.filter(user=request.user)
    return render(request, "jobs/dashboard.html", {"jobs": jobs})

@login_required
def new_job(request):
    if request.method == "POST":
        form = NewJobForm(request.POST)
        if form.is_valid():
            search_query = sanitize(form.cleaned_data["search_query"])
            city = sanitize(form.cleaned_data.get("city", ""))
            max_results = int(form.cleaned_data["max_results"])

            # Check active job
            active = Job.objects.filter(user=request.user, status__in=["pending", "running"]).first()
            if active:
                form.add_error(None, "You already have a job in progress.")
                return render(request, "jobs/new_job.html", {"form": form})

            # Check limits
            error = check_limits(request.user)
            if error:
                form.add_error(None, error)
                return render(request, "jobs/new_job.html", {"form": form})

            job = Job.objects.create(
                user=request.user,
                search_query=search_query,
                city=city,
                max_results=max_results,
            )
            run_scraping_job.delay(str(job.id))
            return redirect("dashboard")
    else:
        form = NewJobForm()
    return render(request, "jobs/new_job.html", {"form": form})

@login_required
def job_detail(request, job_id):
    job = get_object_or_404(Job, id=job_id, user=request.user)
    leads = Lead.objects.filter(job=job)
    return render(request, "jobs/job_detail.html", {"job": job, "leads": leads})

@login_required
def download_csv(request, job_id):
    job = get_object_or_404(Job, id=job_id, user=request.user, status="completed")
    if not job.file_path or not os.path.exists(job.file_path):
        raise Http404("CSV file not found.")
    return FileResponse(
        open(job.file_path, "rb"),
        as_attachment=True,
        filename=f"leads-{job.search_query}-{str(job.id)[:8]}.csv",
        content_type="text/csv",
    )

@login_required
def profile(request):
    return render(request, "jobs/profile.html")