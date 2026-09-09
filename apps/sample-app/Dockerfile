# Multi-stage: (1) test in a hermetic builder, (2) slim runtime only.
FROM python:3.14-slim AS builder
WORKDIR /build

ENV PIP_NO_CACHE_DIR=1

COPY requirements-dev.txt requirements.txt ./
RUN python -m pip install -r requirements-dev.txt

COPY app ./app
COPY tests ./tests
RUN python -m pytest -q

FROM python:3.14-slim AS runtime
WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    APP_ENV=dev \
    PIP_NO_CACHE_DIR=1

COPY requirements.txt ./
RUN python -m pip install -r requirements.txt \
    && useradd --create-home --uid 10001 appuser

COPY --from=builder /build/app ./app

USER appuser
EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request;urllib.request.urlopen('http://127.0.0.1:8000/health')"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
