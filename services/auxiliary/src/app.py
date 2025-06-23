from flask import Flask, request, jsonify
import os
import boto3

app = Flask(__name__)

VERSION = os.getenv("VERSION", "unknown")
REGION = os.getenv("AWS_REGION")
                   
@app.route("/healthz", methods=["GET"])
def liveness():
    return jsonify({"status": "ok"}), 200

@app.route("/readyz", methods=["GET"])
def readiness():
    try:
        ssm = boto3.client("ssm", region_name=REGION)
        ssm.describe_parameters(MaxResults=1)
        return jsonify({"status": "ready"}), 200
    except Exception as e:
        return jsonify({"status": "not ready", "error": str(e)}), 503


@app.route('/buckets', methods=['GET'])
def list_buckets():
    s3 = boto3.client('s3')
    buckets = s3.list_buckets()
    bucket_names = [b['Name'] for b in buckets.get('Buckets', [])]
    return jsonify({
        "buckets": bucket_names,
        "auxiliary_version": VERSION
    })

@app.route('/parameters', methods=['GET'])
def list_parameters():
    ssm = boto3.client("ssm", region_name=REGION)
    response = ssm.describe_parameters()
    parameter_names = [p['Name'] for p in response.get('Parameters', [])]
    return jsonify({
        "parameters": parameter_names,
        "auxiliary_version": VERSION
    })

@app.route('/parameter', methods=['GET'])
def get_parameter():
    name = request.args.get("name")
    if not name:
        return jsonify({"error": "Missing 'name' query parameter"}), 400
    ssm = boto3.client("ssm", region_name=REGION)
    response = ssm.get_parameter(Name=name, WithDecryption=True)
    return jsonify({
        "name": name,
        "value": response['Parameter']['Value'],
        "auxiliary_version": VERSION
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8001)