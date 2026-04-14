import subprocess
from flask import Flask

app = Flask(__name__)


@app.route("/status")
def check_status():
    result = subprocess.run(["systemctl", "status", "nginx"], capture_output=True, text=True, check=False)
    return result.stdout


@app.route("/uptime")
def check_uptime():
    result = subprocess.run(["uptime"], capture_output=True, text=True, check=False)
    return result.stdout


@app.route("/disk")
def check_disk():
    result = subprocess.run(["df", "-h"], capture_output=True, text=True, check=False)
    return result.stdout
