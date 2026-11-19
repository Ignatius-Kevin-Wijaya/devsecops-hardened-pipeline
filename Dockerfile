FROM python:3.12-slim AS builder

WORKDIR /build
COPY src/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim

RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r -g 10001 appuser \
    && useradd -r -u 10001 -g appuser -s /sbin/nologin appuser

COPY --from=builder /install /usr/local
COPY src/app.py /app/app.py

WORKDIR /app

# Numeric UID so the kubelet can verify runAsNonRoot; a user name cannot be checked.
USER 10001:10001

EXPOSE 8080

# The root filesystem is read-only in Kubernetes, so worker heartbeat files go to the /dev/shm tmpfs.
ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--worker-tmp-dir", "/dev/shm", "app:app"]
