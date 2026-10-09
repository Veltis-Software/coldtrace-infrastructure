# Local infrastructure

Copy `.env.example` to `.env`, then `docker compose up -d`.
MySQL has eight schemas and eight users; each has privileges only in its own
schema. The Pub/Sub emulator listens on 8681; bootstrap is idempotent and
explicitly refuses to run without an emulator host. No Google credentials
are needed. `docker compose --profile apps up --build -d` also runs monitoring,
alert and gateway. The schemas for later contexts are infrastructure preparation,
not implemented microservices.

The default application configuration does not provision synthetic devices.
For a local fixture run only, add SPRING_PROFILES_ACTIVE=demo and
DEMO_SENSORS=50 to monitoring. Never enable this profile in the cloud.

Monitoring publishes its outbox to the emulator. Alert consumes threshold
and gap pushes and stores in-app notifications. For the Compose applications,
set ALERT_PUSH_URL=http://alert:8080/internal/pubsub/events when running
pubsub-init; the default endpoint targets services running on the host.
After restarting the emulator, rerun pubsub-init because its state is ephemeral.
Cloud authenticated push delivery is not implemented by the local-only receiver.

For the prepared sibling repositories use `compose.repositories.yaml` instead
of `compose.yaml`. The consolidated source uses `compose.yaml` and the root
build context. `compose.demo.yaml` is an explicit local fixture override.
For a reproducible disposable demo the commands may use `--env-file .env.example`.
The example credentials are local fixtures only.
