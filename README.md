# ColdTrace Infrastructure

Docker Compose starts the API Gateway, the eight service repositories, MySQL 8
and a local Pub/Sub emulator. MySQL gives each stateful service a schema and
restricted account. AI Assistance runs without a database.

## Local environment

Clone the service repositories into sibling directories at the revisions in
the table below. The technical common library lives in
`libraries/coldtrace-shared` inside this repository.

| Repository | Integration branch |
|---|---|
| coldtrace-identity-service | feature/extract-identity |
| coldtrace-asset-service | feature/extract-asset |
| coldtrace-subscription-service | feature/extract-subscription |
| coldtrace-maintenance-service | feature/extract-maintenance |
| coldtrace-ai-assistance-service | feature/extract-ai-assistance |
| coldtrace-api-gateway | feature/complete-service-extraction |
| coldtrace-monitoring-service | feature/complete-service-extraction |
| coldtrace-alert-service | feature/complete-service-extraction |
| coldtrace-report-service | feature/complete-service-extraction |
| coldtrace-web-app | feature/complete-service-extraction |

Copy `.env.example` to `.env` for the isolated local environment and run:

```sh
docker compose --profile apps --profile web up --build -d
```

Use a fresh Compose project when verifying a schema migration. The Gateway
listens on loopback port 28080 and MySQL on loopback port 23306. The Web image
listens on port 24200 and proxies API requests to the Gateway. Configure Edge
to use the Gateway. API documents are available under
`/<service>/v3/api-docs`, such as `/monitoring/v3/api-docs`.
The database bootstrap runs only when MySQL initializes a fresh volume.

Run `pwsh -File tests/Verify-ServiceBoundaries.ps1 -GatewayUrl http://127.0.0.1:28080`
against an isolated Compose environment. The script registers a disposable
organization, checks its ownership boundaries and exercises source revision,
provisioning, canonical ingestion, deduplication and reading history.

The Pub/Sub bootstrap creates topics and subscriptions with container DNS
names. After emulator restart, run `docker compose run --rm pubsub-init` to
recreate that configuration. To generate an explicit Monitoring fixture, add
`-f compose.yaml -f compose.demo.yaml` to the Compose command.

## Deployment boundaries

The push receiver and relay are local-emulator implementations. Cloud requires
authenticated publishing, push OIDC verification, secrets and MySQL connectivity.
See `CLOUD_PREPARATION.md` for proposed names, cost constraints and background
execution considerations. CI validates Compose and bootstrap syntax.
