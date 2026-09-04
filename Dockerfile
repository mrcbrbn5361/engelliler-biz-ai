FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY engelliler-ai/ ./engelliler-ai/
COPY .env.example .env.example

EXPOSE 8000
WORKDIR /app/engelliler-ai

CMD ["uvicorn", "api_server:app", "--host", "0.0.0.0", "--port", "8000"]
