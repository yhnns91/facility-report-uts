# Image backend: Facility Report API (Python, tanpa framework)
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    DATA_FILE=/var/lib/backend_data/facility_reports.json
WORKDIR /app
COPY app.py .
EXPOSE 5000

# Docker HEALTHCHECK: python:3.11-slim tidak punya curl, jadi pakai urllib.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health', timeout=2)" || exit 1

CMD ["python", "app.py"]
