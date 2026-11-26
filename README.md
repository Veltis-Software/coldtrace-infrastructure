# ColdTrace Infrastructure

Docker Compose starts the API Gateway, the eight microservices, the web
application, MySQL 8 and a local Pub/Sub emulator. MySQL gives each stateful
service its own schema and restricted account. AI Assistance runs without a
database.

## Local environment

Clone the following repositories as sibling directories of this one, on their
`main` branch (release `v1.0.0`):

| Repository | Role |
|---|---|
| coldtrace-shared | Shared build context for Gateway, Monitoring, Alert and Report |
| coldtrace-api-gateway | Entry point |
| coldtrace-identity-service | Identity and access |
| coldtrace-asset-service | Asset management |
| coldtrace-monitoring-service | Telemetry and asset state |
| coldtrace-alert-service | Incidents and notifications |
| coldtrace-report-service | Traceability reports |
| coldtrace-subscription-service | Plans and billing |
| coldtrace-maintenance-service | Preventive maintenance |
| coldtrace-ai-assistance-service | AI assistance |
| coldtrace-web-app | Web application |

Copy `.env.example` to `.env` and run:

```sh
docker compose -f compose.repositories.yaml --profile apps --profile web up --build -d
```

The Gateway listens on loopback port 28080, the web application on port 24200
and MySQL on port 23306. API documents are available under
`/<service>/v3/api-docs`, such as `/monitoring/v3/api-docs`. The database
bootstrap runs only when MySQL initializes a fresh volume.

Once `http://127.0.0.1:28080/actuator/health` returns HTTP 200, run
`pwsh -File tests/Verify-ServiceBoundaries.ps1 -GatewayUrl http://127.0.0.1:28080`.
The script registers a disposable organization, checks its ownership
boundaries and exercises source revision, provisioning, canonical ingestion,
deduplication and reading history.

The Pub/Sub bootstrap creates topics and push subscriptions with container DNS
names. After an emulator restart, run
`docker compose -f compose.repositories.yaml run --rm pubsub-init`. To load a
Monitoring fixture, add `-f compose.yaml -f compose.demo.yaml` to the Compose
command.

## Google Cloud

The release is deployed in project `veltis-coldtrace-dev`, region `us-east1`.
See [CLOUD_DEPLOYMENT.md](CLOUD_DEPLOYMENT.md) for the resources and their
configuration. `gcp/preflight.ps1` verifies the active account, project and
billing before any change.
