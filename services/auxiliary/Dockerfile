FROM python:3.10-slim
WORKDIR /auxiliary
COPY src/app.py .
RUN pip install flask
EXPOSE 8001
CMD ["python", "app.py"]