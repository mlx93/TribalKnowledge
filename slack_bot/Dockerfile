# Tribal Knowledge Slack Bot
# Build: docker build -t tribal-slack-bot .
# Run: docker run --env-file .env tribal-slack-bot

FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code into slack_bot package
COPY . ./slack_bot/

# Create data directory for SQLite
RUN mkdir -p /data

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV THREAD_CONTEXT_DB=/data/thread_contexts.db
ENV LOG_LEVEL=INFO

# Run the bot as a module
CMD ["python", "-m", "slack_bot.app"]

