# ---- builder stage ----
FROM python:3.12-slim AS builder

WORKDIR /build

# Install deps into an isolated prefix so we can copy only them to the final image
COPY requirements.txt .
RUN pip install --prefix=/install --no-cache-dir -r requirements.txt


# ---- final stage ----
FROM python:3.12-slim

# Non-root user — never run as root in production
RUN useradd --create-home --shell /bin/bash appuser

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application code
COPY app/ ./app/

USER appuser

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
