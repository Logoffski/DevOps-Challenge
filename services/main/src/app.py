from flask import Flask, request, jsonify
import os
import requests
import urllib.parse

app = Flask(__name__)
VERSION = os.getenv("VERSION", "unknown")
AUXILIARY_URL = os.getenv("AUXILIARY_URL", "http://auxiliary-service.auxiliary-service.svc")

def fetch_aux(path):
    try:
        resp = requests.get(f"{AUXILIARY_URL}{path}", timeout=5)
        return resp.json()
    except Exception as e:
        return {"error": str(e)}

@app.route("/healthz", methods=["GET"])
def liveness():
    return jsonify({"status": "ok"}), 200

@app.route("/readyz", methods=["GET"])
def readiness():
    try:
        resp = requests.get(f"{AUXILIARY_URL}/readyz", timeout=2)
        if resp.status_code == 200:
            return jsonify({"status": "ready"}), 200
        return jsonify({"status": "not ready", "error": resp.text}), 503
    except Exception as e:
        return jsonify({"status": "not ready", "error": str(e)}), 503

@app.route('/buckets', methods=['GET'])
def get_buckets():
    aux_data = fetch_aux("/buckets")
    return jsonify({
        "main_version": VERSION,
        **aux_data
    })

@app.route('/parameters', methods=['GET'])
def get_parameters():
    aux_data = fetch_aux("/parameters")
    return jsonify({
        "main_version": VERSION,
        **aux_data
    })

@app.route('/parameter', methods=['GET'])
def get_parameter():
    name = request.args.get("name")
    if not name:
        return jsonify({"error": "Missing 'name' query parameter"}), 400
    ## Apparently we need to encode the URL again
    encoded = urllib.parse.quote(name, safe='')
    aux_data = fetch_aux(f"/parameter?name={encoded}")
    return jsonify({
        "main_version": VERSION,
        **aux_data
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)