FROM python:3.10-slim

## Create a non-root user
RUN useradd --create-home --shell /bin/bash appuser

WORKDIR /auxiliary

## Set default version
ARG VERSION=dev
ENV VERSION=$VERSION

## Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

## Copy app code
COPY src/app.py .

## Switch to a non-root user
RUN chown -R appuser:appuser /auxiliary
USER appuser

EXPOSE 8001
CMD ["python", "app.py"]