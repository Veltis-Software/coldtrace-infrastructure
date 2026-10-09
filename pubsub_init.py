"""Idempotent local emulator bootstrap; never authenticates to real Google Cloud."""
import json, os, time, urllib.error, urllib.request

host = os.environ.get('PUBSUB_EMULATOR_HOST')
if not host: raise SystemExit('PUBSUB_EMULATOR_HOST is required; refusing real cloud access')
project = os.environ.get('PUBSUB_PROJECT_ID', 'coldtrace-local')
base = f'http://{host}/v1/projects/{project}'
topics = ['threshold.breached', 'source.gap', 'readings.ingested', 'asset.settings-changed', 'incident.opened']
subscriptions = {'alert-service.threshold-breached': 'threshold.breached', 'alert-service.source-gap': 'source.gap', 'report-service.readings-ingested': 'readings.ingested', 'monitoring-service.asset-settings-changed': 'asset.settings-changed'}
def put(path, body):
    req = urllib.request.Request(base + path, data=json.dumps(body).encode(), headers={'Content-Type': 'application/json'}, method='PUT')
    try:
        with urllib.request.urlopen(req, timeout=5) as response: return response.status
    except urllib.error.HTTPError as exc:
        if exc.code == 409: return 409
        raise
for attempt in range(60):
    try:
        put('/topics/' + topics[0], {})
        break
    except urllib.error.URLError:
        if attempt == 59: raise
        time.sleep(1)
for topic in topics: put('/topics/' + topic, {})
for subscription, topic in subscriptions.items():
    body={'topic': f'projects/{project}/topics/{topic}', 'ackDeadlineSeconds': 30}
    if subscription.startswith('alert-service.'):
        body['pushConfig']={'pushEndpoint': os.environ.get('ALERT_PUSH_URL','http://host.docker.internal:8084/internal/pubsub/events')}
    put('/subscriptions/' + subscription, body)
    if 'pushConfig' in body:
        req=urllib.request.Request(base+'/subscriptions/'+subscription+':modifyPushConfig',
            data=json.dumps({'pushConfig':body['pushConfig']}).encode(),
            headers={'Content-Type':'application/json'},method='POST')
        with urllib.request.urlopen(req,timeout=5) as response: response.read()
print(json.dumps({'project': project, 'topics': topics, 'subscriptions': subscriptions}))
