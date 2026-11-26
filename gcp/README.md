# ColdTrace development project

The development project is `veltis-coldtrace-dev` (number `311618880556`), named
Coldtrace v2. Region `southamerica-west1` follows the architecture report. All
commands must specify this project explicitly. The local Google Cloud CLI default
belongs to another project and is not changed by these scripts.

```powershell
./gcp/preflight.ps1
```

The preflight reads project metadata and billing status and rejects a project
number mismatch. It does not enable APIs, create resources or deploy services.
`development.env.example` contains resource identifiers, not credentials.

## Deployment sequence

1. Complete authenticated Pub/Sub publishing and OIDC push verification. The
   emulator-only receivers must not be exposed as production push handlers.
2. Provision MySQL schemas and restricted service users using the existing
   ownership/migration rules. Choose and authorize a bounded database cost first.
3. Configure Secret Manager, service identities, Artifact Registry and API access.
4. Deploy Monitoring, Alert and Reports from their owning repositories, with
   configured IAM/Asset URLs. Deploy API Gateway with the resulting upstream URLs.
5. Expose only the intended entry point. Verify tenant authorization, authenticated
   event delivery, idempotency, report generation and loss/recovery behavior.
6. Capture resource names, revision/image identities, API responses and running
   URLs; record the evidence against the sprint backlog.

Cloud Run scale-to-zero is suitable for intermittent demonstrations but does not
keep scheduled gap/outbox tasks continuously running. A continuously evaluated
availability scenario needs CPU outside requests or a separately designed
execution trigger. One minimum instance does not establish redundancy.

The edge agent runs at the sensor site with persistent SQLite storage. It is not
deployed on ephemeral Cloud Run storage. The brownfield backend supplies IAM/Asset
until those capabilities are extracted; it cannot be retired while routes still
depend on it.

Cloud SQL MySQL is not a permanently free-tier database. Cloud Run, Pub/Sub,
Artifact Registry and build/storage usage also need quota and cost checks before
deployment. A linked billing account does not authorize an unbounded database or
continuous instance spend. Pricing references: [Cloud Run](https://cloud.google.com/run/pricing),
[Cloud SQL](https://cloud.google.com/sql/pricing),
[budgets](https://docs.cloud.google.com/billing/docs/how-to/budgets).
