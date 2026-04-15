FROM python:3.12-slim AS builder

WORKDIR /build
COPY src/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim

RUN groupadd -r appuser && useradd -r -g appuser -s /sbin/nologin appuser

COPY --from=builder /install /usr/local
COPY src/app.py /app/app.py

WORKDIR /app

USER appuser

EXPOSE 8080

ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
