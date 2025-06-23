FROM python:3.10-slim

WORKDIR /main

## Set default version
ARG VERSION=dev
ENV VERSION=$VERSION

## Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

## Copy app code
COPY src/app.py .

## Switch to a non-root user
RUN chown -R appuser:appuser /main
USER appuser

EXPOSE 8000
CMD ["python", "app.py"]