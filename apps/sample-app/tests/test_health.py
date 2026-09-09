import os

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_default_env():
    os.environ.pop("APP_ENV", None)
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok", "environment": "dev"}


def test_health_env_injected():
    os.environ["APP_ENV"] = "staging"
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["environment"] == "staging"


def test_root():
    resp = client.get("/")
    assert resp.status_code == 200
    assert resp.json()["app"] == "sample-app"
