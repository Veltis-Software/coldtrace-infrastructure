# ColdTrace common library

Technical contracts shared by extracted services: event envelopes, correlation IDs, idempotency keys and IAM session DTOs. Business rules remain owned by each bounded context.

Build with Java 21 using `mvn verify` or install locally with `mvn install`. Independent consumers pin the infrastructure commit containing this library in CI and provide its directory as the Docker build context named `shared`.

This library replaces the additional coldtrace-shared repository to retain the 14 repositories specified in the project report. Its migration does not change the artifact coordinates `com.acme.coldtrace:coldtrace-shared:0.1.0-SNAPSHOT`.
