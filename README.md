# ColdTrace Infrastructure

Docker Compose runs MySQL 8, the local Pub/Sub emulator, Monitoring, Alert, Report and
API Gateway. MySQL has a schema and restricted user per bounded context;
schemas for later contexts are preparation, not implemented services.

## Local environment

Clone the service repositories into sibling directories; `develop` contains
the current development increment. The technical common library lives in `libraries/coldtrace-shared` inside this
repository; no additional shared repository is required.
The existing IAM backend must run on the host at port 8090 with its own DB.

```sh
cp .env.example .env
docker compose -f compose.repositories.yaml --profile apps up --build -d
```

For explicit synthetic fixtures, add `-f compose.demo.yaml`. `.env.example`
contains local-only credentials; configure independent secrets outside local
development. The consolidated source uses `compose.yaml` instead of
`compose.repositories.yaml`.

| Component | Host port |
|---|---|
| API Gateway | 18080 |
| Monitoring / Swagger | 18083 |
| Alert / Swagger | 18084 |
| Report / Swagger | 18085 |
| MySQL | 13306 |
| Pub/Sub emulator | 8681 |

`pubsub_init.py` creates topics/subscriptions and updates push endpoints
idempotently. For Docker apps the default sets the receiver to
`http://alert:8080/internal/pubsub/events`; host processes use the default
host.docker.internal endpoint. After emulator restart, run
`docker compose run --rm pubsub-init` again because emulator state is ephemeral.

## Deployment boundaries

The push receiver and relay are local-emulator implementations. Cloud requires
authenticated publishing, push OIDC verification, secrets and MySQL connectivity.
See `CLOUD_PREPARATION.md` for proposed names, cost constraints and background
execution considerations. CI validates Compose and bootstrap syntax.
