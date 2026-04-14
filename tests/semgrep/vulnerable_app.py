import subprocess
import os
from flask import Flask, request

app = Flask(__name__)


@app.route("/run")
def run_command():
    cmd = request.args.get("cmd")
    subprocess.run(cmd, shell=True)
    return "executed"


@app.route("/system")
def system_command():
    cmd = request.form.get("command")
    os.system(cmd)
    return "executed"


@app.route("/call")
def call_command():
    payload = request.json.get("payload")
    subprocess.call(payload, shell=True)
    return "executed"
