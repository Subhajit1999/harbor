FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Render (and most PaaS hosts) inject the port to listen on via $PORT —
# shell form so the env var actually expands, unlike Docker's exec-form CMD.
CMD uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}
