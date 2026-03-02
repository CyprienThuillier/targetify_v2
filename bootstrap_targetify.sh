#!/bin/bash
# ============================================================
# TARGETIFY — Django Bootstrap Script
# Run this ONCE from the folder where you want the project.
# It installs dependencies, scaffolds the full Django project,
# and writes every file so you can start the server immediately.
# ============================================================
set -e

PROJECT="targetify"
echo "🚀 Bootstrapping $PROJECT..."

# ── 1. Install Python dependencies ──────────────────────────
pip install django celery redis django-celery-results \
    psycopg2-binary python-dotenv stripe bleach \
    playwright requests beautifulsoup4

# Install Playwright browsers
playwright install firefox

# ── 2. Create Django project + apps ─────────────────────────
django-admin startproject config .
python manage.py startapp accounts
python manage.py startapp jobs
python manage.py startapp billing

mkdir -p accounts/templates/accounts
mkdir -p jobs/templates/jobs
mkdir -p billing/templates/billing
mkdir -p templates          # global templates (base, landing)
mkdir -p static/css
mkdir -p exports

echo "✅ Django project scaffolded"

# ── 3. Write .env ────────────────────────────────────────────
cat > .env << 'EOF'
DEBUG=True
SECRET_KEY=dev-secret-key-change-in-production-abc123xyz
DATABASE_URL=postgresql://saas_user:saas_password@localhost:5432/saas_db
REDIS_URL=redis://localhost:6379/0
STRIPE_PUBLIC_KEY=pk_test_your_key_here
STRIPE_SECRET_KEY=sk_test_your_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_secret_here
EOF

cat > .env.production << 'EOF'
DEBUG=False
SECRET_KEY=CHANGE_THIS_TO_A_REAL_RANDOM_SECRET_KEY
DATABASE_URL=postgresql://saas_user:saas_password@postgres:5432/saas_db
REDIS_URL=redis://redis:6379/0
STRIPE_PUBLIC_KEY=pk_live_your_key_here
STRIPE_SECRET_KEY=sk_live_your_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_secret_here
POSTGRES_USER=saas_user
POSTGRES_PASSWORD=saas_password
POSTGRES_DB=saas_db
EOF

echo "✅ .env files written"

# ── 4. config/settings.py ───────────────────────────────────
cat > config/settings.py << 'EOF'
from pathlib import Path
from dotenv import load_dotenv
import os

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.getenv("SECRET_KEY", "insecure-fallback-key")
DEBUG = os.getenv("DEBUG", "False") == "True"
ALLOWED_HOSTS = ["*"]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Local apps
    "accounts",
    "jobs",
    "billing",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"

# Database
import dj_database_url
DATABASES = {
    "default": dj_database_url.config(
        default=os.getenv("DATABASE_URL", "sqlite:///db.sqlite3"),
        conn_max_age=600,
    )
}

AUTH_USER_MODEL = "accounts.User"
LOGIN_URL = "/accounts/login/"
LOGIN_REDIRECT_URL = "/jobs/"
LOGOUT_REDIRECT_URL = "/"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator", "OPTIONS": {"min_length": 8}},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "/static/"
STATICFILES_DIRS = [BASE_DIR / "static"]
STATIC_ROOT = BASE_DIR / "staticfiles"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# Celery
CELERY_BROKER_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
CELERY_RESULT_BACKEND = os.getenv("REDIS_URL", "redis://localhost:6379/0")
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TIMEZONE = "UTC"
CELERY_WORKER_CONCURRENCY = 1
CELERY_WORKER_PREFETCH_MULTIPLIER = 1

# Stripe
STRIPE_PUBLIC_KEY = os.getenv("STRIPE_PUBLIC_KEY", "")
STRIPE_SECRET_KEY = os.getenv("STRIPE_SECRET_KEY", "")
STRIPE_WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET", "")

# Exports
EXPORTS_DIR = BASE_DIR / "exports"
EOF

# ── 5. config/urls.py ───────────────────────────────────────
cat > config/urls.py << 'EOF'
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
EOF

cat > config/views.py << 'EOF'
from django.shortcuts import render

def landing(request):
    return render(request, "landing.html")
EOF

# ── 6. config/celery.py ─────────────────────────────────────
cat > config/celery.py << 'EOF'
import os
from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
app = Celery("targetify")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
EOF

cat > config/__init__.py << 'EOF'
from .celery import app as celery_app
__all__ = ("celery_app",)
EOF

echo "✅ Config files written"

# ── 7. accounts/models.py ───────────────────────────────────
cat > accounts/models.py << 'EOF'
from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    """Extended user — add fields here as needed."""
    class Meta:
        db_table = "users"
EOF

# ── 8. accounts/forms.py ────────────────────────────────────
cat > accounts/forms.py << 'EOF'
from django import forms
from django.contrib.auth.forms import UserCreationForm, AuthenticationForm
from .models import User

class RegisterForm(UserCreationForm):
    email = forms.EmailField(required=True)

    class Meta:
        model = User
        fields = ("username", "email", "password1", "password2")

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for field in self.fields.values():
            field.widget.attrs.update({"class": "w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"})

class LoginForm(AuthenticationForm):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for field in self.fields.values():
            field.widget.attrs.update({"class": "w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"})
EOF

# ── 9. accounts/views.py ────────────────────────────────────
cat > accounts/views.py << 'EOF'
from django.shortcuts import render, redirect
from django.contrib.auth import login, logout, authenticate
from django.contrib import messages
from .forms import RegisterForm, LoginForm

def register(request):
    if request.user.is_authenticated:
        return redirect("dashboard")
    if request.method == "POST":
        form = RegisterForm(request.POST)
        if form.is_valid():
            user = form.save()
            messages.success(request, "Account created! Please log in.")
            return redirect("login")
    else:
        form = RegisterForm()
    return render(request, "accounts/register.html", {"form": form})

def login_view(request):
    if request.user.is_authenticated:
        return redirect("dashboard")
    if request.method == "POST":
        form = LoginForm(request, data=request.POST)
        if form.is_valid():
            user = form.get_user()
            login(request, user)
            return redirect("dashboard")
    else:
        form = LoginForm()
    return render(request, "accounts/login.html", {"form": form})

def logout_view(request):
    logout(request)
    return redirect("landing")
EOF

# ── 10. accounts/urls.py ────────────────────────────────────
cat > accounts/urls.py << 'EOF'
from django.urls import path
from . import views

urlpatterns = [
    path("register/", views.register, name="register"),
    path("login/", views.login_view, name="login"),
    path("logout/", views.logout_view, name="logout"),
]
EOF

echo "✅ Accounts app written"

# ── 11. jobs/models.py ──────────────────────────────────────
cat > jobs/models.py << 'EOF'
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
EOF

# ── 12. jobs/forms.py ───────────────────────────────────────
cat > jobs/forms.py << 'EOF'
from django import forms

class NewJobForm(forms.Form):
    search_query = forms.CharField(
        max_length=255,
        widget=forms.TextInput(attrs={
            "class": "w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm",
            "placeholder": 'e.g. "plumber", "dentist", "web agency"',
        })
    )
    city = forms.CharField(
        max_length=255,
        required=False,
        widget=forms.TextInput(attrs={
            "class": "w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm",
            "placeholder": 'e.g. "Paris", "London", "New York"',
        })
    )
    max_results = forms.ChoiceField(
        choices=[(25, "25 leads"), (50, "50 leads"), (100, "100 leads"), (200, "200 leads"), (500, "500 leads")],
        initial=50,
        widget=forms.Select(attrs={
            "class": "w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm bg-white",
        })
    )
EOF

# ── 13. jobs/views.py ───────────────────────────────────────
cat > jobs/views.py << 'EOF'
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
EOF

# ── 14. jobs/urls.py ────────────────────────────────────────
cat > jobs/urls.py << 'EOF'
from django.urls import path
from . import views

urlpatterns = [
    path("", views.dashboard, name="dashboard"),
    path("new/", views.new_job, name="new_job"),
    path("<uuid:job_id>/", views.job_detail, name="job_detail"),
    path("<uuid:job_id>/download/", views.download_csv, name="download_csv"),
]
EOF

# ── 15. jobs/tasks.py ───────────────────────────────────────
cat > jobs/tasks.py << 'EOF'
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
EOF

echo "✅ Jobs app written"

# ── 16. billing/models.py ───────────────────────────────────
cat > billing/models.py << 'EOF'
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
EOF

# ── 17. billing/views.py ────────────────────────────────────
cat > billing/views.py << 'EOF'
from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required
from django.views.decorators.csrf import csrf_exempt
from django.http import HttpResponse, JsonResponse
from django.conf import settings
import stripe
import json

stripe.api_key = settings.STRIPE_SECRET_KEY

PLAN_PRICES = {
    "starter_monthly": {"price_id": "price_starter_monthly", "name": "Starter Monthly"},
    "starter_annual":  {"price_id": "price_starter_annual",  "name": "Starter Annual"},
    "pro_monthly":     {"price_id": "price_pro_monthly",      "name": "Pro Monthly"},
    "pro_annual":      {"price_id": "price_pro_annual",       "name": "Pro Annual"},
}

def pricing(request):
    return render(request, "billing/pricing.html")

@login_required
def checkout(request, plan):
    if plan not in PLAN_PRICES:
        return redirect("pricing")
    price = PLAN_PRICES[plan]
    session = stripe.checkout.Session.create(
        customer_email=request.user.email,
        payment_method_types=["card"],
        line_items=[{"price": price["price_id"], "quantity": 1}],
        mode="subscription",
        success_url=request.build_absolute_uri("/billing/success/"),
        cancel_url=request.build_absolute_uri("/billing/pricing/"),
        metadata={"user_id": str(request.user.id), "plan": plan},
    )
    return redirect(session.url)

@login_required
def success(request):
    return render(request, "billing/success.html")

@csrf_exempt
def stripe_webhook(request):
    payload = request.body
    sig = request.headers.get("stripe-signature")
    try:
        event = stripe.Webhook.construct_event(payload, sig, settings.STRIPE_WEBHOOK_SECRET)
    except Exception:
        return HttpResponse(status=400)

    if event["type"] == "checkout.session.completed":
        _handle_checkout(event["data"]["object"])
    elif event["type"] == "customer.subscription.deleted":
        _handle_canceled(event["data"]["object"])

    return JsonResponse({"status": "ok"})

def _handle_checkout(session):
    from .models import Subscription
    from accounts.models import User
    user_id = session["metadata"].get("user_id")
    plan = session["metadata"].get("plan", "starter_monthly")
    plan_name = "starter" if "starter" in plan else "pro"
    try:
        user = User.objects.get(id=user_id)
        sub, _ = Subscription.objects.get_or_create(user=user)
        sub.stripe_customer_id = session.get("customer", "")
        sub.plan_name = plan_name
        sub.status = "active"
        sub.monthly_lead_limit = 500 if plan_name == "starter" else 2000
        sub.save()
    except User.DoesNotExist:
        pass

def _handle_canceled(subscription):
    from .models import Subscription
    try:
        sub = Subscription.objects.get(stripe_subscription_id=subscription["id"])
        sub.plan_name = "free"
        sub.status = "canceled"
        sub.monthly_lead_limit = 10
        sub.save()
    except Subscription.DoesNotExist:
        pass
EOF

# ── 18. billing/urls.py ─────────────────────────────────────
cat > billing/urls.py << 'EOF'
from django.urls import path
from . import views

urlpatterns = [
    path("pricing/", views.pricing, name="pricing"),
    path("checkout/<str:plan>/", views.checkout, name="checkout"),
    path("success/", views.success, name="billing_success"),
    path("webhook/", views.stripe_webhook, name="stripe_webhook"),
]
EOF

echo "✅ Billing app written"

# ── 19. Scraper module ──────────────────────────────────────
mkdir -p scraper
touch scraper/__init__.py

cat > scraper/scraper_service.py << 'EOF'
"""
Sync wrapper around the async Playwright scraper.
Called by the Celery task in jobs/tasks.py.
"""
import asyncio
import time
from .analyser import analyze
from .export import export_file

MAX_RETRIES = 3

def run_scrape(
    search_query: str,
    city: str,
    max_results: int,
    output_path: str,
    on_result=None,
    existing_urls: set = None,
    user=None,
):
    return asyncio.run(
        _run_async(search_query, city, max_results, output_path, on_result, existing_urls or set(), user)
    )

async def _run_async(search_query, city, max_results, output_path, on_result, existing_urls, user):
    from playwright.async_api import async_playwright
    import asyncio as aio

    all_urls = set()
    all_results = []
    init_time = int(time.time())

    async with async_playwright() as pw:
        browser = await pw.firefox.launch(headless=True)
        sem = aio.Semaphore(10)

        # Collect URLs (capped at max_results)
        page = await browser.new_page()
        query = f"{search_query} {city}".strip()
        await page.goto(f"https://www.google.com/maps/search/{query}")
        try:
            await page.get_by_role("button", name="Tout refuser").click(timeout=5000)
        except Exception:
            pass
        await page.wait_for_selector("a.hfpxzc", timeout=15000)
        feed = page.locator("div[role='feed']")
        previous = 0
        while len(all_urls) < max_results:
            await feed.evaluate("el => el.scrollTo(0, el.scrollHeight)")
            await page.wait_for_timeout(2000)
            items = page.locator("a.hfpxzc")
            count = await items.count()
            if count == previous:
                break
            previous = count
            for i in range(count):
                href = await items.nth(i).get_attribute("href")
                if href and href not in all_urls and href not in existing_urls:
                    all_urls.add(href)
                if len(all_urls) >= max_results:
                    break
        await page.close()

        new_urls = list(all_urls)[:max_results]
        print(f"[Scraper] Collected {len(new_urls)} new URLs")

        # Record URLs for deduplication
        if user:
            from jobs.models import SearchedUrl
            for url in new_urls:
                SearchedUrl.objects.get_or_create(user=user, url=url)

        # Analyse each URL
        tasks = [analyze(browser, url, MAX_RETRIES, sem, search_query) for url in new_urls]
        results = await aio.gather(*tasks)
        valid = [r for r in results if r is not None]

        export_file(valid, filename=output_path, append=True)
        if on_result:
            for r in valid:
                on_result(r)
        all_results.extend(valid)

        await browser.close()

    elapsed = int(time.time()) - init_time
    print(f"Done in {elapsed // 60:02d}m{elapsed % 60:02d}s — {len(all_results)} results")
    return all_results
EOF

# Copy analyser and export from FastAPI project (same logic)
cat > scraper/analyser.py << 'EOF'
import random
import asyncio
from playwright.async_api import TimeoutError as PlaywrightTimeout

async def safe_get(locator, attribute=None, timeout=3000):
    try:
        if attribute:
            return await locator.get_attribute(attribute, timeout=timeout)
        return await locator.inner_text(timeout=timeout)
    except Exception:
        return None

async def analyze(browser, url: str, max_retries, sem, category) -> dict | None:
    async with sem:
        for attempt in range(1, max_retries + 1):
            page = await browser.new_page()
            try:
                await page.goto(url, timeout=15000, wait_until="domcontentloaded")
                try:
                    await page.get_by_role("button", name="Tout refuser").click(timeout=5000)
                    await page.wait_for_selector('[data-item-id]', timeout=10000)
                except Exception:
                    pass
                await page.wait_for_selector('[data-item-id]', timeout=10000)
                await asyncio.sleep(random.uniform(0.8, 1.5))

                name = await safe_get(page.locator("h1").first, timeout=5000)
                address_raw = await safe_get(page.locator('[data-item-id="address"]'), attribute="aria-label")
                address = address_raw.replace("Adresse\u00a0: ", "").strip() if address_raw else None
                website = await safe_get(page.locator('[data-item-id="authority"]'), attribute="aria-label")
                phone = await safe_get(
                    page.locator('[data-item-id^="phone"] div[class*="fontBody"]').first,
                    timeout=3000
                )
                lead_score = 0
                if not website:
                    lead_score += 40
                if not phone:
                    lead_score += 10

                await page.close()
                return {"url": url, "name": name, "category": category,
                        "address": address, "phone": phone, "website": website, "lead_score": lead_score}

            except (PlaywrightTimeout, Exception):
                await page.close()
                if attempt == max_retries:
                    return None
                await asyncio.sleep(random.uniform(1.0, 2.0))
EOF

cat > scraper/export.py << 'EOF'
import csv
import os

def export_file(targets: list, filename: str = "export.csv", append: bool = False):
    targets = [t for t in targets if t is not None]
    if not targets:
        return
    os.makedirs(os.path.dirname(filename) if os.path.dirname(filename) else ".", exist_ok=True)
    mode = "a" if append else "w"
    file_exists = append and os.path.exists(filename)
    with open(filename, mode, newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(targets[0].keys()))
        if not file_exists:
            writer.writeheader()
        writer.writerows(targets)
EOF

echo "✅ Scraper module written"

# ── 20. TEMPLATES ───────────────────────────────────────────

# base.html
cat > templates/base.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{% block title %}Targetify{% endblock %}</title>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-50 text-gray-900 min-h-screen flex flex-col">

  <nav class="bg-white border-b px-6 py-4 flex justify-between items-center">
    <a href="/" class="font-bold text-xl text-blue-600">Targetify</a>
    <div class="flex gap-4 items-center">
      {% if user.is_authenticated %}
        <a href="/jobs/" class="text-gray-600 hover:text-blue-600 text-sm">Dashboard</a>
        <a href="/accounts/logout/" class="text-sm text-gray-500 hover:text-red-600">Logout</a>
      {% else %}
        <a href="/accounts/login/" class="text-gray-600 hover:text-blue-600 text-sm">Login</a>
        <a href="/accounts/register/" class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700">Get Started</a>
      {% endif %}
    </div>
  </nav>

  <main class="max-w-5xl mx-auto px-4 py-8 w-full flex-1">
    {% if messages %}
      {% for message in messages %}
        <div class="mb-4 px-4 py-3 rounded text-sm
          {% if message.tags == 'error' %}bg-red-50 border border-red-200 text-red-700
          {% else %}bg-green-50 border border-green-200 text-green-700{% endif %}">
          {{ message }}
        </div>
      {% endfor %}
    {% endif %}
    {% block content %}{% endblock %}
  </main>

</body>
</html>
EOF

# landing.html
cat > templates/landing.html << 'EOF'
{% extends "base.html" %}
{% block title %}Targetify — Google Maps Lead Generation{% endblock %}
{% block content %}
<div class="text-center py-20">
  <h1 class="text-5xl font-bold mb-4">Find B2B Leads</h1>
  <p class="text-xl text-gray-600 mb-10">Search any city or industry — get business names, emails, phones, and websites in minutes.</p>
  <div class="flex gap-4 justify-center">
    <a href="/accounts/register/" class="bg-blue-600 text-white px-8 py-4 rounded-lg text-lg hover:bg-blue-700">Try for Free</a>
    <a href="/billing/pricing/" class="border border-gray-300 text-gray-700 px-8 py-4 rounded-lg text-lg hover:bg-gray-50">See Pricing</a>
  </div>
</div>
{% endblock %}
EOF

# accounts/register.html
cat > accounts/templates/accounts/register.html << 'EOF'
{% extends "base.html" %}
{% block title %}Create Account — Targetify{% endblock %}
{% block content %}
<div class="max-w-md mx-auto mt-10">
  <div class="bg-white rounded-xl shadow-sm border p-8">
    <h1 class="text-2xl font-bold mb-2">Create your account</h1>
    <p class="text-gray-500 mb-6">Start finding leads in minutes.</p>
    <form method="post" class="flex flex-col gap-4">
      {% csrf_token %}
      {% for field in form %}
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">{{ field.label }}</label>
          {{ field }}
          {% if field.errors %}<p class="text-red-500 text-xs mt-1">{{ field.errors.0 }}</p>{% endif %}
        </div>
      {% endfor %}
      <button type="submit" class="w-full bg-blue-600 text-white py-2 rounded-lg font-medium hover:bg-blue-700">Create Account</button>
    </form>
    <p class="text-center text-sm text-gray-500 mt-6">Already have an account? <a href="/accounts/login/" class="text-blue-600 hover:underline">Log in</a></p>
  </div>
</div>
{% endblock %}
EOF

# accounts/login.html
cat > accounts/templates/accounts/login.html << 'EOF'
{% extends "base.html" %}
{% block title %}Log In — Targetify{% endblock %}
{% block content %}
<div class="max-w-md mx-auto mt-10">
  <div class="bg-white rounded-xl shadow-sm border p-8">
    <h1 class="text-2xl font-bold mb-2">Welcome back</h1>
    <p class="text-gray-500 mb-6">Log in to your account.</p>
    <form method="post" class="flex flex-col gap-4">
      {% csrf_token %}
      {% for field in form %}
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">{{ field.label }}</label>
          {{ field }}
          {% if field.errors %}<p class="text-red-500 text-xs mt-1">{{ field.errors.0 }}</p>{% endif %}
        </div>
      {% endfor %}
      <button type="submit" class="w-full bg-blue-600 text-white py-2 rounded-lg font-medium hover:bg-blue-700">Log In</button>
    </form>
    <p class="text-center text-sm text-gray-500 mt-6">Don't have an account? <a href="/accounts/register/" class="text-blue-600 hover:underline">Sign up free</a></p>
  </div>
</div>
{% endblock %}
EOF

# jobs/dashboard.html
cat > jobs/templates/jobs/dashboard.html << 'EOF'
{% extends "base.html" %}
{% block title %}Dashboard — Targetify{% endblock %}
{% block content %}
<div class="flex justify-between items-center mb-8">
  <div>
    <h1 class="text-2xl font-bold">Dashboard</h1>
    <p class="text-gray-500 text-sm">{{ user.email }}</p>
  </div>
  <a href="/jobs/new/" class="bg-blue-600 text-white px-5 py-2 rounded-lg hover:bg-blue-700 font-medium">+ New Job</a>
</div>

{% if jobs %}
<div class="bg-white rounded-xl border overflow-hidden">
  <table class="w-full text-sm">
    <thead class="bg-gray-50 border-b">
      <tr>
        <th class="text-left px-5 py-3 font-medium text-gray-600">Query</th>
        <th class="text-left px-5 py-3 font-medium text-gray-600">City</th>
        <th class="text-left px-5 py-3 font-medium text-gray-600">Status</th>
        <th class="text-left px-5 py-3 font-medium text-gray-600">Results</th>
        <th class="text-left px-5 py-3 font-medium text-gray-600">Created</th>
        <th class="px-5 py-3"></th>
      </tr>
    </thead>
    <tbody class="divide-y">
      {% for job in jobs %}
      <tr class="hover:bg-gray-50">
        <td class="px-5 py-4 font-medium">{{ job.search_query }}</td>
        <td class="px-5 py-4 text-gray-500">{{ job.city|default:"—" }}</td>
        <td class="px-5 py-4">
          {% if job.status == "pending" %}<span class="bg-yellow-100 text-yellow-800 text-xs font-medium px-2.5 py-1 rounded-full">Pending</span>
          {% elif job.status == "running" %}<span class="bg-blue-100 text-blue-800 text-xs font-medium px-2.5 py-1 rounded-full">Running</span>
          {% elif job.status == "completed" %}<span class="bg-green-100 text-green-800 text-xs font-medium px-2.5 py-1 rounded-full">Completed</span>
          {% elif job.status == "failed" %}<span class="bg-red-100 text-red-800 text-xs font-medium px-2.5 py-1 rounded-full">Failed</span>
          {% endif %}
        </td>
        <td class="px-5 py-4 text-gray-500">{{ job.processed_targets }} / {{ job.max_results }}</td>
        <td class="px-5 py-4 text-gray-400 text-xs">{{ job.created_at|date:"d M Y, H:i" }}</td>
        <td class="px-5 py-4"><a href="/jobs/{{ job.id }}/" class="text-blue-600 hover:underline text-xs font-medium">View →</a></td>
      </tr>
      {% endfor %}
    </tbody>
  </table>
</div>
{% else %}
<div class="bg-white rounded-xl border p-16 text-center">
  <div class="text-4xl mb-4">🔍</div>
  <h2 class="text-lg font-semibold mb-1">No jobs yet</h2>
  <p class="text-gray-500 text-sm mb-6">Create your first scraping job to start finding leads.</p>
  <a href="/jobs/new/" class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 font-medium">Create your first job</a>
</div>
{% endif %}
{% endblock %}
EOF

# jobs/new_job.html
cat > jobs/templates/jobs/new_job.html << 'EOF'
{% extends "base.html" %}
{% block title %}New Job — Targetify{% endblock %}
{% block content %}
<div class="max-w-xl mx-auto">
  <a href="/jobs/" class="text-sm text-gray-500 hover:text-blue-600 mb-6 inline-block">← Back to dashboard</a>
  <div class="bg-white rounded-xl border p-8">
    <h1 class="text-2xl font-bold mb-1">New Scraping Job</h1>
    <p class="text-gray-500 text-sm mb-6">We'll search Google Maps and extract business leads matching your query.</p>
    {% if form.non_field_errors %}
      <div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-6 text-sm">{{ form.non_field_errors.0 }}</div>
    {% endif %}
    <form method="post" class="flex flex-col gap-5">
      {% csrf_token %}
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">What are you looking for?</label>
        {{ form.search_query }}
        <p class="text-gray-400 text-xs mt-1">The business type or industry you want to target.</p>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">City / Location</label>
        {{ form.city }}
        <p class="text-gray-400 text-xs mt-1">Optional — leave blank to search everywhere.</p>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Max results</label>
        {{ form.max_results }}
      </div>
      <div class="bg-blue-50 border border-blue-100 rounded-lg px-4 py-3 text-sm text-blue-700">
        ⏱ Scraping typically takes 5–25 minutes depending on the number of results. You can close this page — the job runs in the background.
      </div>
      <button type="submit" class="w-full bg-blue-600 text-white py-2.5 rounded-lg font-medium hover:bg-blue-700">Start Job</button>
    </form>
  </div>
</div>
{% endblock %}
EOF

# jobs/job_detail.html
cat > jobs/templates/jobs/job_detail.html << 'EOF'
{% extends "base.html" %}
{% block title %}Job Detail — Targetify{% endblock %}
{% block content %}
{% if job.status == "running" or job.status == "pending" %}
<meta http-equiv="refresh" content="10">
{% endif %}

<a href="/jobs/" class="text-sm text-gray-500 hover:text-blue-600 mb-6 inline-block">← Back to dashboard</a>

<div class="bg-white rounded-xl border p-6 mb-6">
  <div class="flex justify-between items-start">
    <div>
      <h1 class="text-xl font-bold mb-1">{{ job.search_query }}</h1>
      <p class="text-gray-500 text-sm">{{ job.city|default:"No location specified" }}</p>
    </div>
    <div>
      {% if job.status == "pending" %}<span class="bg-yellow-100 text-yellow-800 text-sm font-medium px-3 py-1 rounded-full">Pending</span>
      {% elif job.status == "running" %}<span class="bg-blue-100 text-blue-800 text-sm font-medium px-3 py-1 rounded-full">Running</span>
      {% elif job.status == "completed" %}<span class="bg-green-100 text-green-800 text-sm font-medium px-3 py-1 rounded-full">Completed</span>
      {% elif job.status == "failed" %}<span class="bg-red-100 text-red-800 text-sm font-medium px-3 py-1 rounded-full">Failed</span>
      {% endif %}
    </div>
  </div>
  <div class="grid grid-cols-3 gap-4 mt-6 pt-6 border-t text-center">
    <div><p class="text-2xl font-bold text-blue-600">{{ leads.count }}</p><p class="text-xs text-gray-500 mt-1">Leads found</p></div>
    <div><p class="text-2xl font-bold text-gray-700">{{ job.max_results }}</p><p class="text-xs text-gray-500 mt-1">Target results</p></div>
    <div><p class="text-2xl font-bold text-gray-700">{{ job.created_at|date:"d M" }}</p><p class="text-xs text-gray-500 mt-1">Created</p></div>
  </div>
  {% if job.status == "failed" and job.error_message %}
  <div class="mt-4 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded text-sm"><strong>Error:</strong> {{ job.error_message }}</div>
  {% endif %}
</div>

{% if leads %}
<div class="bg-white rounded-xl border overflow-hidden">
  <div class="px-5 py-4 border-b flex justify-between items-center">
    <h2 class="font-semibold">Leads ({{ leads.count }})</h2>
    {% if job.status == "completed" %}
    <a href="/jobs/{{ job.id }}/download/" class="bg-green-600 text-white text-sm px-4 py-1.5 rounded-lg hover:bg-green-700 font-medium">⬇ Download CSV</a>
    {% endif %}
  </div>
  <div class="overflow-x-auto">
    <table class="w-full text-sm">
      <thead class="bg-gray-50 border-b">
        <tr>
          <th class="text-left px-5 py-3 font-medium text-gray-600">Business</th>
          <th class="text-left px-5 py-3 font-medium text-gray-600">Phone</th>
          <th class="text-left px-5 py-3 font-medium text-gray-600">Email</th>
          <th class="text-left px-5 py-3 font-medium text-gray-600">Website</th>
          <th class="text-left px-5 py-3 font-medium text-gray-600">City</th>
        </tr>
      </thead>
      <tbody class="divide-y">
        {% for lead in leads %}
        <tr class="hover:bg-gray-50">
          <td class="px-5 py-3 font-medium">{{ lead.business_name|default:"—" }}</td>
          <td class="px-5 py-3 text-gray-500">{{ lead.phone|default:"—" }}</td>
          <td class="px-5 py-3 text-gray-500">{{ lead.email|default:"—" }}</td>
          <td class="px-5 py-3">
            {% if lead.website %}<a href="{{ lead.website }}" target="_blank" class="text-blue-600 hover:underline">{{ lead.website|truncatechars:30 }}</a>
            {% else %}<span class="text-gray-400">—</span>{% endif %}
          </td>
          <td class="px-5 py-3 text-gray-500">{{ lead.city|default:"—" }}</td>
        </tr>
        {% endfor %}
      </tbody>
    </table>
  </div>
</div>
{% elif job.status == "pending" %}
<div class="bg-white rounded-xl border p-12 text-center text-gray-400">
  <div class="text-3xl mb-3">⏳</div><p class="font-medium text-gray-600">Job is queued</p><p class="text-sm mt-1">It will start as soon as a worker is available.</p>
</div>
{% elif job.status == "running" %}
<div class="bg-white rounded-xl border p-12 text-center text-gray-400">
  <div class="text-3xl mb-3">⚙️</div><p class="font-medium text-gray-600">Scraping in progress...</p><p class="text-sm mt-1">This page auto-refreshes every 10 seconds.</p>
</div>
{% else %}
<div class="bg-white rounded-xl border p-12 text-center text-gray-400"><p class="text-sm">No leads found for this job.</p></div>
{% endif %}
{% endblock %}
EOF

# billing/pricing.html
cat > billing/templates/billing/pricing.html << 'EOF'
{% extends "base.html" %}
{% block title %}Pricing — Targetify{% endblock %}
{% block content %}
<div class="max-w-4xl mx-auto py-12">
  <h1 class="text-4xl font-bold text-center mb-2">Simple Pricing</h1>
  <p class="text-gray-500 text-center mb-12">No hidden fees. Cancel anytime.</p>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
    <!-- Free -->
    <div class="bg-white rounded-xl border p-6 flex flex-col">
      <h2 class="text-xl font-bold mb-1">Free</h2>
      <p class="text-3xl font-bold mb-4">€0<span class="text-sm font-normal text-gray-500">/mo</span></p>
      <ul class="text-sm text-gray-600 space-y-2 flex-1 mb-6">
        <li>✓ 10 leads/month</li><li>✓ 1 job at a time</li><li>✗ No CSV download</li>
      </ul>
      <a href="/accounts/register/" class="block text-center border border-blue-600 text-blue-600 py-2 rounded-lg hover:bg-blue-50">Get Started</a>
    </div>
    <!-- Starter -->
    <div class="bg-blue-600 text-white rounded-xl border p-6 flex flex-col shadow-lg">
      <h2 class="text-xl font-bold mb-1">Starter</h2>
      <p class="text-3xl font-bold mb-4">€19<span class="text-sm font-normal opacity-80">/mo</span></p>
      <ul class="text-sm space-y-2 flex-1 mb-6 opacity-90">
        <li>✓ 500 leads/month</li><li>✓ CSV download</li><li>✓ Job history</li>
      </ul>
      <a href="/billing/checkout/starter_monthly/" class="block text-center bg-white text-blue-600 py-2 rounded-lg font-medium hover:bg-blue-50">Subscribe</a>
    </div>
    <!-- Pro -->
    <div class="bg-white rounded-xl border p-6 flex flex-col">
      <h2 class="text-xl font-bold mb-1">Pro</h2>
      <p class="text-3xl font-bold mb-4">€49<span class="text-sm font-normal text-gray-500">/mo</span></p>
      <ul class="text-sm text-gray-600 space-y-2 flex-1 mb-6">
        <li>✓ 2000 leads/month</li><li>✓ Unlimited jobs</li><li>✓ Priority processing</li>
      </ul>
      <a href="/billing/checkout/pro_monthly/" class="block text-center border border-blue-600 text-blue-600 py-2 rounded-lg hover:bg-blue-50">Subscribe</a>
    </div>
  </div>
</div>
{% endblock %}
EOF

cat > billing/templates/billing/success.html << 'EOF'
{% extends "base.html" %}
{% block title %}Payment Successful — Targetify{% endblock %}
{% block content %}
<div class="text-center py-20">
  <div class="text-5xl mb-4">🎉</div>
  <h1 class="text-3xl font-bold mb-2">You're all set!</h1>
  <p class="text-gray-600 mb-8">Your subscription is now active. Start finding leads.</p>
  <a href="/jobs/" class="bg-blue-600 text-white px-8 py-3 rounded-lg hover:bg-blue-700 font-medium">Go to Dashboard</a>
</div>
{% endblock %}
EOF

echo "✅ All templates written"

# ── 21. requirements.txt ────────────────────────────────────
cat > requirements.txt << 'EOF'
django>=5.0
celery>=5.3
redis>=5.0
psycopg2-binary>=2.9
python-dotenv>=1.0
dj-database-url>=2.0
stripe>=7.0
bleach>=6.0
playwright>=1.40
requests>=2.31
beautifulsoup4>=4.12
EOF

# ── 22. docker-compose.yml ──────────────────────────────────
cat > docker-compose.yml << 'EOF'
services:
  postgres:
    image: postgres:15
    restart: unless-stopped
    env_file: .env.production
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U saas_user -d saas_db"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

  api:
    build: .
    restart: unless-stopped
    command: bash start.sh
    ports:
      - "8000:8000"
    env_file: .env.production
    volumes:
      - exports_data:/app/exports
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  worker:
    build: .
    restart: unless-stopped
    command: celery -A config.celery worker --loglevel=info --concurrency=1
    env_file: .env.production
    volumes:
      - exports_data:/app/exports
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

volumes:
  postgres_data:
  exports_data:
EOF

cat > docker-compose.dev.yml << 'EOF'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: saas_user
      POSTGRES_PASSWORD: saas_password
      POSTGRES_DB: saas_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7
    ports:
      - "6379:6379"

volumes:
  postgres_data:
EOF

# ── 23. Dockerfile ──────────────────────────────────────────
cat > Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y gcc libpq-dev curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN playwright install firefox && playwright install-deps firefox
COPY . .
RUN mkdir -p exports
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000"]
EOF

cat > start.sh << 'EOF'
#!/bin/bash
set -e
echo "Running migrations..."
python manage.py migrate
echo "Starting server..."
exec gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 2
EOF
chmod +x start.sh

# ── 24. .gitignore ──────────────────────────────────────────
cat > .gitignore << 'EOF'
.env
.env.production
.venv/
__pycache__/
*.pyc
.DS_Store
exports/
staticfiles/
db.sqlite3
EOF

echo ""
echo "============================================"
echo "✅  Targetify Django project is ready!"
echo "============================================"
echo ""
echo "NEXT STEPS:"
echo ""
echo "  1. Install dependencies:"
echo "     pip install -r requirements.txt"
echo ""
echo "  2. Start Postgres + Redis (dev):"
echo "     docker-compose -f docker-compose.dev.yml up -d"
echo ""
echo "  3. Run migrations:"
echo "     python manage.py migrate"
echo ""
echo "  4. Create superuser (for /admin):"
echo "     python manage.py createsuperuser"
echo ""
echo "  5. In terminal 1 — start Django:"
echo "     python manage.py runserver"
echo ""
echo "  6. In terminal 2 — start Celery worker:"
echo "     celery -A config.celery worker --loglevel=info"
echo ""
echo "  Then open: http://localhost:8000"
echo ""
echo "  Register > new job > scraping runs in background"
echo "============================================"
