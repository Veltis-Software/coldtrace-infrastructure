# Google Cloud deployment

Release `v1.0.0` runs in project `veltis-coldtrace-dev`, region `us-east1`.

| Resource | Configuration |
|---|---|
| Cloud Run | `coldtrace-web` (public), `coldtrace-gateway`, `coldtrace-identity`, `coldtrace-asset`, `coldtrace-monitoring`, `coldtrace-alert`, `coldtrace-report`, `coldtrace-subscription`, `coldtrace-maintenance`, `coldtrace-ai` (private, `roles/run.invoker` per caller service account) |
| Artifact Registry | Docker repository `coldtrace-services`, one image per service tagged `v1.0.0` |
| Cloud SQL | MySQL 8.4 instance `coldtrace-mysql-dev`; one `ct_*` schema and user per stateful service |
| Pub/Sub | Topics `readings.ingested`, `threshold.breached`, `incident.opened`, `source.gap`, `source.configuration-changed` and `asset.settings-changed`, with authenticated push subscriptions to the consumer services |
| Secret Manager | One database password per service, `coldtrace-jwt`, `coldtrace-internal-key` and `coldtrace-ai-provider-key` |

## Service-to-service calls

Each private service runs with its own service account. Services that call
other owners include two sidecars:

- `cloud-sql-proxy`, which exposes the instance on `127.0.0.1:3306`.
- `private-proxy`, which listens on one local port per owner, declared in
  `COLDTRACE_PRIVATE_UPSTREAMS` as a JSON map of port to Cloud Run URL, and adds
  a Cloud Run identity token to each request.

The application variables (`IDENTITY_URL`, `ASSET_URL`, `MAINTENANCE_URL`, …)
point to those local ports. Every owner a service calls must appear in its
upstream map and grant `roles/run.invoker` to the caller's service account.

## Release procedure

1. Build each image from the `v1.0.0` tag and push it to `coldtrace-services`.
2. Deploy the revision with `gcloud run services replace` or `gcloud run deploy`,
   keeping the environment variables and secret references of the service.
3. Apply schema changes through the Flyway migrations of each service, which
   run at startup.
4. Verify `/actuator/health` through the gateway and the public web URL.
