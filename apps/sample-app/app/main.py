import os

from fastapi import FastAPI

app = FastAPI(title="jenkins-multi-agent sample-app", version="0.1.0")


def _env() -> str:
    return os.getenv("APP_ENV", "dev")


@app.get("/")
def root():
    return {"app": "sample-app", "environment": _env()}


@app.get("/health")
def health():
    return {"status": "ok", "environment": _env()}
