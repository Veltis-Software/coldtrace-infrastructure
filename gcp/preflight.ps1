param(
    [string]$ProjectId = 'veltis-coldtrace-dev',
    [string]$ExpectedProjectNumber = '311618880556'
)
$ErrorActionPreference = 'Stop'

# Every command explicitly targets ColdTrace; do not change the global CLI project.
$projectJson = & gcloud projects describe $ProjectId --format=json
if ($LASTEXITCODE -ne 0) { throw 'Unable to read the ColdTrace project. Run gcloud auth login.' }
$project = $projectJson | ConvertFrom-Json
if ([string]$project.projectNumber -ne $ExpectedProjectNumber) {
    throw 'Project number differs from the expected ColdTrace project.'
}
if ($project.lifecycleState -ne 'ACTIVE') { throw 'The ColdTrace project is not active.' }

$billingJson = & gcloud billing projects describe $ProjectId --format=json
if ($LASTEXITCODE -ne 0) { throw 'Unable to verify billing access for the ColdTrace project.' }
$billing = $billingJson | ConvertFrom-Json

[pscustomobject]@{
    projectId = $project.projectId
    projectNumber = $project.projectNumber
    state = $project.lifecycleState
    billingEnabled = [bool]$billing.billingEnabled
    region = 'southamerica-west1'
    checkedAt = (Get-Date).ToUniversalTime().ToString('o')
    operation = 'read-only preflight'
} | ConvertTo-Json
