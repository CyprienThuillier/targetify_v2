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
