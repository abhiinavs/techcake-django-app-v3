from django.conf import settings
from django.core.cache import cache
from django.http import JsonResponse
from django.shortcuts import render


def index(request):
    # Visit counter backed by the cache (Redis/ElastiCache when REDIS_URL is set).
    try:
        visits = cache.incr("techcake:visits")
    except ValueError:
        cache.set("techcake:visits", 1)
        visits = 1
    except Exception:
        visits = None  # Cache unavailable; page still renders.

    return render(
        request,
        "congrats/index.html",
        {"visits": visits, "version": settings.APP_VERSION},
    )


def health(request):
    """Health check that reports the currently deployed version."""
    return JsonResponse({
        "status": "ok",
        "version": settings.APP_VERSION,
    })
