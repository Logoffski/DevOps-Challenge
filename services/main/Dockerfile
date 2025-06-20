FROM python:3.10-slim
WORKDIR /main
COPY src/app.py .
RUN pip install flask
EXPOSE 8000
CMD ["python", "app.py"]