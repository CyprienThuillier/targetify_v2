FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y gcc libpq-dev curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN playwright install firefox && playwright install-deps firefox
COPY . .
RUN mkdir -p exports
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000"]
