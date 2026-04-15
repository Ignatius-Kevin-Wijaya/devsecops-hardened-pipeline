import os
from flask import Flask, jsonify, request

app = Flask(__name__)


@app.route("/healthz")
def health():
    return jsonify({"status": "healthy"}), 200


@app.route("/readyz")
def ready():
    return jsonify({"status": "ready"}), 200


@app.route("/api/v1/info")
def info():
    return jsonify({
        "service": "devsecops-demo",
        "version": os.getenv("APP_VERSION", "0.1.0"),
    }), 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
