from flask import Flask, jsonify
import os
import requests

app = Flask(__name__)
VERSION = os.getenv("VERSION", "unknown")
AUXILIARY_URL = os.getenv("AUXILIARY_URL", "http://auxiliary-service.auxiliary-service.svc")

def fetch_aux(path):
    try:
        resp = requests.get(f"{AUXILIARY_URL}{path}", timeout=5)
        return resp.json()
    except Exception as e:
        return {"error": str(e)}

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

@app.route('/parameter/<name>', methods=['GET'])
def get_parameter(name):
    aux_data = fetch_aux(f"/parameter/{name}")
    return jsonify({
        "main_version": VERSION,
        **aux_data
    })

@app.route('/version', methods=['GET'])
def get_versions():
    aux_data = fetch_aux("/version")
    return jsonify({
        "main_version": VERSION,
        **aux_data
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)