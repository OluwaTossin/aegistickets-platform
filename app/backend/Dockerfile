# Using cached alpine image
FROM alpine:latest

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install Python 3 and dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    postgresql-libs \
    gcc \
    python3-dev \
    musl-dev \
    postgresql-dev

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip3 install --no-cache-dir --break-system-packages -r requirements.txt

# Clean up build dependencies
RUN apk del gcc python3-dev musl-dev postgresql-dev

# Copy application code
COPY . .

# Create non-root user
RUN adduser -D -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')" || exit 1

CMD ["gunicorn", "-w", "2", "-k", "gthread", "--threads", "8", "-b", "0.0.0.0:8000", "wsgi:app"]
