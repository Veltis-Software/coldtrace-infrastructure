param(
  [ValidateSet('identity','asset','monitoring','alert','report','subscription')]
  [string]$Service
)
$ErrorActionPreference='Stop'
$project='veltis-coldtrace-dev'
$number=gcloud projects describe $project --format='value(projectNumber)'
if($LASTEXITCODE -ne 0 -or $number -ne '311618880556'){throw 'Unexpected Google Cloud project'}
# The TCP listener is local to the SQL proxy sidecar. The proxy authenticates
# the connection to Cloud SQL and encrypts remote database traffic.
$url="jdbc:mysql://127.0.0.1:3306/ct_${Service}?serverTimezone=UTC&allowPublicKeyRetrieval=true"
gcloud --quiet run services update "coldtrace-$Service" --project=$project --region=us-east1 --container=$Service "--update-env-vars=DB_URL=$url"
if($LASTEXITCODE -ne 0){throw "Database connection update failed for $Service"}
