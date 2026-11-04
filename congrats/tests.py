"""Test suite for the Techcake app.

Run it with no database server:
DB_ENGINE=sqlite python manage.py test
"""

from django.core.cache import cache
from django.test import TestCase, override_settings


class HomePageTests(TestCase):
    def setUp(self):
        cache.clear()

    def test_home_page_renders(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Techcake")

    @override_settings(APP_VERSION="test-1234")
    def test_home_page_shows_version(self):
        self.assertContains(self.client.get("/"), "test-1234")

    def test_visit_counter_increments(self):
        first = self.client.get("/").context["visits"]
        second = self.client.get("/").context["visits"]
        self.assertEqual(second, first + 1)


class HealthCheckTests(TestCase):
    def test_health_ok(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")

    @override_settings(APP_VERSION="v3-test")
    def test_health_reports_version(self):
        response = self.client.get("/health")
        self.assertEqual(response.json()["version"], "v3-test")

    def test_health_does_not_require_database_connection(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            set(response.json().keys()),
            {"status", "version"},
        )
