"""Create explicitly synthetic academic resources through the owning APIs.

Run only against the local TP1 stack. Credentials are supplied through environment
variables; bearer tokens and gateway keys are never written to evidence files.
"""
import json
import os
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

BASE = os.environ.get("COLDTRACE_TEST_URL", "http://127.0.0.1:18080")
if not BASE.startswith(("http://127.0.0.1:", "http://localhost:")):
    raise SystemExit("This fixture script requires an explicitly local academic stack")


def request(path, method="GET", body=None, headers=None):
    data = None if body is None else json.dumps(body).encode()
    values = {"Content-Type": "application/json", **(headers or {})}
    try:
        with urllib.request.urlopen(urllib.request.Request(BASE + path, data=data,
                                    method=method, headers=values), timeout=15) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as failure:
        raise RuntimeError(f"{method} {path}: {failure.code} {failure.read().decode()}") from None


_, user = request("/api/v1/authentication/sign-in", "POST", {
    "email": os.environ["COLDTRACE_TEST_EMAIL"],
    "password": os.environ["COLDTRACE_TEST_PASSWORD"],
})
auth = {"Authorization": "Bearer " + user["token"]}
org = user["organizationId"]
prefix = f"/api/v1/organizations/{org}"


def ensure(collection, label, body):
    _, rows = request(prefix + "/" + collection, headers=auth)
    for row in rows:
        if row.get("name") == label or row.get("model") == label:
            return row
    _, row = request(prefix + "/" + collection, "POST", body, auth)
    return row


location = ensure("locations", "Academic test warehouse", {
    "name": "Academic test warehouse", "type": "WAREHOUSE", "status": "active",
    "description": "Synthetic Sprint 1 acceptance environment",
})
asset = ensure("assets", "Academic cold room", {
    "name": "Academic cold room", "type": "COLD_ROOM", "status": "active",
    "uuid": str(uuid.uuid4()), "locationId": location["id"], "capacity": 100,
    "description": "Synthetic acceptance asset; no real customer data",
})
gateway = ensure("gateways", "Academic edge gateway", {
    "name": "Academic edge gateway", "uuid": str(uuid.uuid4()), "network": "academic-local",
    "status": "online", "locationId": location["id"],
})
settings = {
    "assetTypes": ["COLD_ROOM"], "iotDeviceTypes": ["TEMPERATURE_SENSOR"],
    "minimumTemperature": 2, "maximumTemperature": 8,
    "minimumHumidity": 40, "maximumHumidity": 80,
    "calibrationFrequencyDays": 30, "temperatureUnit": "C", "humidityUnit": "%",
    "weightUnit": "kg", "readingFrequencySeconds": 10, "alertThresholdMinutes": 1,
}
request(prefix + f"/assets/{asset['id']}/settings", "PUT", settings, auth)
device = ensure("iot-devices", "Academic sensor", {
    "model": "Academic sensor", "uuid": str(uuid.uuid4()), "gatewayId": gateway["id"],
    "assetId": asset["id"], "deviceType": "TEMPERATURE_SENSOR", "measurementType": "temperature",
    "measurementParameters": ["temperature", "humidity"], "readingFrequencySeconds": 10,
    "status": "online", "calibrationStatus": "calibrated",
    "lastCalibrationDate": datetime.now(timezone.utc).date().isoformat(),
    "nextCalibrationDate": (datetime.now(timezone.utc) + timedelta(days=30)).date().isoformat(),
})
key = os.environ["COLDTRACE_TEST_GATEWAY_KEY"]
_, provisioned = request("/api/v1/telemetry/provisioning", "POST", {
    "gatewayId": gateway["id"], "gatewayApiKey": key,
}, auth)
now = datetime.now(timezone.utc)
sequence = int(time.time() * 1000)
readings = [{"deviceUuid": device["uuid"], "sequenceNumber": sequence + i,
             "recordedAt": (now - timedelta(seconds=70 - i * 10)).isoformat(),
             "temperature": 12, "humidity": 60} for i in range(8)]
batch_key = str(uuid.uuid4())
batch = {"gatewayUuid": gateway["uuid"], "readings": readings}
headers = {"X-Gateway-Key": key, "Idempotency-Key": batch_key}
status, accepted = request("/api/v1/telemetry/batches", "POST", batch, headers)
_, repeated = request("/api/v1/telemetry/batches", "POST", batch, headers)
assert status == 202 and accepted["accepted"] == 8
assert repeated["accepted"] == 0 and repeated["duplicated"] == 8
result = {"environment": "local synthetic academic fixture", "executedAt": now.isoformat(),
          "organizationId": org, "assetId": asset["id"], "gatewayId": gateway["id"],
          "deviceId": device["id"], "provisioning": provisioned,
          "accepted": accepted, "repeated": repeated}
output = Path(os.environ.get("COLDTRACE_TEST_OUTPUT", "academic-flow-result.json"))
output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result))
