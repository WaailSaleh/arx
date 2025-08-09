FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Create app dir
WORKDIR /app

# Install runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install python deps
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy app
COPY app.py ./

# Volume for saves
VOLUME ["/data"]

# Env
ENV SAVES_DIR=/data \
    PORT=8080 \
    DOCKER_LABEL_SERVICE=palworld-server

EXPOSE 8080

CMD ["python", "app.py"]