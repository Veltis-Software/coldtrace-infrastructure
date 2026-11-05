param(
    [string]$IdentityUrl = 'http://127.0.0.1:18101',
    [string]$AssetUrl = 'http://127.0.0.1:18102',
    [string]$SubscriptionUrl = 'http://127.0.0.1:18107',
    [string]$GatewayUrl,
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
if ($GatewayUrl) {
    $IdentityUrl = $AssetUrl = $SubscriptionUrl = $GatewayUrl.TrimEnd('/')
}
$results = [System.Collections.Generic.List[object]]::new()
function Request([string]$Method, [string]$Url, $Body, $Headers = @{}) {
    $arguments = @{ Method = $Method; Uri = $Url; Headers = $Headers; SkipHttpErrorCheck = $true }
    if ($null -ne $Body) {
        $arguments.ContentType = 'application/json'
        $arguments.Body = $Body | ConvertTo-Json -Depth 8
    }
    $response = Invoke-WebRequest @arguments
    $payload = if ($response.Content) { try { $response.Content | ConvertFrom-Json } catch { $null } }
    @{ Status = [int]$response.StatusCode; Data = $payload; Headers = $response.Headers }
}
function Check([string]$Name, [bool]$Condition) {
    $results.Add([pscustomobject]@{ name = $Name; passed = $Condition })
    if (!$Condition) { throw "Boundary verification failed: $Name" }
}

try {
    $suffix = [Guid]::NewGuid().ToString('N').Substring(0, 12)
    $password = [Guid]::NewGuid().ToString('N') + 'Aa9!'
    $email = "operaciones.$suffix@frionorte.example"
    $registration = Request POST "$IdentityUrl/api/v1/organization-sign-ups" @{
        legalName = "Frio Norte $suffix S.A.C."; commercialName = 'Frio Norte'
        contactEmail = "contacto.$suffix@frionorte.example"
        firstName = 'Mariana'; lastName = 'Vargas'; email = $email; password = $password
    }
    Check 'organization-registration' ($registration.Status -eq 201)
    $org = $registration.Data.organization.id
    $login = Request POST "$IdentityUrl/api/v1/authentication/sign-in" @{ email = $email; password = $password }
    Check 'owner-sign-in' ($login.Status -eq 200 -and !!$login.Data.token)
    $headers = @{ Authorization = "Bearer $($login.Data.token)" }
    $session = Request GET "$IdentityUrl/api/v1/session/context" $null $headers
    Check 'authenticated-organization-scope' ($session.Status -eq 200 -and $session.Data.organizationId -eq $org)
    $subscription = $null
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        $subscription = Request GET "$SubscriptionUrl/api/v1/organizations/$org/subscription" $null $headers
        if ($subscription.Status -eq 200) { break }
        Start-Sleep -Seconds 1
    }
    Check 'eventual-base-subscription' ($subscription.Status -eq 200 -and $subscription.Data.organizationId -eq $org)
    $location = Request POST "$AssetUrl/api/v1/organizations/$org/locations" @{
        name = 'Centro de distribucion Callao'; type = 'WAREHOUSE'
        address = 'Av. Argentina 4210, Callao'; status = 'active'
    } $headers
    Check 'asset-location-created' ($location.Status -eq 201 -and $location.Data.organizationId -eq $org)
    $blocked = Request POST "$AssetUrl/api/v1/organizations/$org/locations" @{
        name = 'Centro de distribucion Pisco'; type = 'WAREHOUSE'; status = 'active'
    } $headers
    Check 'base-plan-limit-preserved' ($blocked.Status -eq 409 -and $blocked.Data.used -eq 1 -and $blocked.Data.limit -eq 1)
    $asset = Request POST "$AssetUrl/api/v1/organizations/$org/assets" @{
        locationId = $location.Data.id; uuid = [Guid]::NewGuid().ToString(); type = 'FREEZER'
        name = 'Camara de conservacion 01'; capacity = 450.0; status = 'active'
    } $headers
    Check 'asset-created-in-owner-schema' ($asset.Status -eq 201)
    $gateway = Request POST "$AssetUrl/api/v1/organizations/$org/gateways" @{
        locationId = $location.Data.id; uuid = [Guid]::NewGuid().ToString()
        name = 'Gateway Callao'; network = 'ethernet'; status = 'online'
    } $headers
    Check 'gateway-created-in-owner-schema' ($gateway.Status -eq 201)
    $device = Request POST "$AssetUrl/api/v1/organizations/$org/iot-devices" @{
        gatewayId = $gateway.Data.id; uuid = [Guid]::NewGuid().ToString(); deviceType = 'sensor'
        model = 'TH-120'; measurementType = 'temperature-humidity'
        measurementParameters = @('temperature', 'humidity'); readingFrequencySeconds = 30
        assetId = $asset.Data.id; status = 'online'; calibrationStatus = 'calibrated'
        lastCalibrationDate = '2026-10-01'; nextCalibrationDate = '2027-10-01'
    } $headers
    Check 'device-created-in-owner-schema' ($device.Status -eq 201)
    $sourcePath = "$AssetUrl/api/v1/organizations/$org/iot-devices/$($device.Data.id)/source-configuration"
    $profile = @{
        assetId = $asset.Data.id; expectedVersion = 0; sourceId = "probe-$suffix"
        transport = 'http'; profileVersion = 1; schemaVersion = 1
        temperatureUnit = 'C'; humidityUnit = '%RH'
        fields = @{ temperature = 'temperature'; humidity = 'humidity'; recordedAt = 'timestamp' }
        reason = 'Instalacion de sonda calibrada'
    }
    $configured = Request PUT $sourcePath $profile $headers
    Check 'source-configuration-preserves-actor-session' ($configured.Status -eq 200 -and $configured.Data.configurationVersion -eq 1)
    $profile.expectedVersion = 1; $profile.sourceId = "replacement-$suffix"
    $profile.reason = 'Sustitucion programada por calibracion'
    $replacement = Request PUT $sourcePath $profile $headers
    Check 'source-replacement-increments-version' ($replacement.Status -eq 200 -and $replacement.Data.configurationVersion -eq 2)
    $stale = Request PUT $sourcePath $profile $headers
    Check 'stale-source-write-rejected' ($stale.Status -eq 409)
    $history = Request GET "$sourcePath/history" $null $headers
    Check 'immutable-source-history-preserved' ($history.Status -eq 200 -and $history.Data.Count -eq 2)
    $export = Request GET "$AssetUrl/api/v1/organizations/$org/gateways/$($gateway.Data.id)/source-profiles" $null $headers
    Check 'edge-profile-export-preserved' ($export.Status -eq 200 -and $export.Data.sources.Count -eq 1 -and $export.Data.sources[0].sourceId -eq $profile.sourceId)
    $foreignOrg = $org + 1000000
    $foreign = Request GET "$AssetUrl/api/v1/organizations/$foreignOrg/locations" $null $headers
    Check 'cross-organization-read-denied' ($foreign.Status -eq 403)
    $foreignBilling = Request GET "$SubscriptionUrl/api/v1/organizations/$foreignOrg/subscription" $null $headers
    Check 'cross-organization-billing-denied' ($foreignBilling.Status -eq 403)
    $foreignUsers = Request GET "$IdentityUrl/api/v1/organizations/$foreignOrg/users" $null $headers
    Check 'cross-organization-user-list-denied' ($foreignUsers.Status -eq 403)
    $organizations = Request GET "$IdentityUrl/api/v1/organizations" $null $headers
    Check 'organization-catalog-is-tenant-scoped' ($organizations.Status -eq 200 -and @($organizations.Data).Count -eq 1 -and $organizations.Data[0].id -eq $org)
    $internal = Request GET "$AssetUrl/internal/assets/organizations/$org/usage" $null $headers
    if ($GatewayUrl) {
        Check 'gateway-does-not-expose-owner-api' ($internal.Status -eq 404)
        foreach ($resource in 'sensor-readings','incidents','notifications','reports','maintenance-schedules','technical-service-requests') {
            $response = Request GET "$GatewayUrl/api/v1/organizations/$org/$resource" $null $headers
            Check "public-$resource-owner-reachable" ($response.Status -eq 200)
        }
        $settings = Request PUT "$AssetUrl/api/v1/organizations/$org/asset-settings/default" @{
            minimumTemperature = 2; maximumTemperature = 8; minimumHumidity = 35; maximumHumidity = 80
            temperatureUnit = 'C'; humidityUnit = '%'; weightUnit = 'kg'
            calibrationFrequencyDays = 30; readingFrequencySeconds = 30; alertThresholdMinutes = 1
        } $headers
        Check 'owner-default-safe-range' ($settings.Status -in 200,201)
        $gatewayKey = [Guid]::NewGuid().ToString('N')
        $provision = Request POST "$GatewayUrl/api/v1/telemetry/provisioning" @{
            gatewayId = $gateway.Data.id; gatewayApiKey = $gatewayKey
        } $headers
        Check 'monitoring-provisions-from-identity-and-asset' ($provision.Status -eq 200 -and $provision.Data.devicesProvisioned -eq 1)
        $reading = @{
            deviceUuid = $device.Data.uuid; sequenceNumber = 1
            recordedAt = [DateTimeOffset]::UtcNow.ToString('o'); temperature = 4.2; humidity = 61.0
            sourceId = $profile.sourceId; profileVersion = 1; schemaVersion = 1
            temperatureUnit = 'C'; humidityUnit = '%RH'
        }
        $batch = @{ gatewayUuid = $gateway.Data.uuid; readings = @($reading) }
        $deviceHeaders = @{ 'X-Gateway-Key' = $gatewayKey; 'Idempotency-Key' = [Guid]::NewGuid().ToString() }
        $accepted = Request POST "$GatewayUrl/api/v1/telemetry/batches" $batch $deviceHeaders
        Check 'canonical-telemetry-accepted' ($accepted.Status -eq 202 -and $accepted.Data.accepted -eq 1)
        $duplicate = Request POST "$GatewayUrl/api/v1/telemetry/batches" $batch $deviceHeaders
        Check 'canonical-retry-is-idempotent' ($duplicate.Status -eq 202 -and $duplicate.Data.duplicated -eq 1)
        $state = Request GET "$GatewayUrl/api/v1/assets/$($asset.Data.id)/state" $null $headers
        Check 'asset-state-reflects-real-ingest' ($state.Status -eq 200 -and $state.Data.status -eq 'NORMAL')
        $readings = Request GET "$GatewayUrl/api/v1/organizations/$org/sensor-readings" $null $headers
        Check 'web-history-contains-one-reading' ($readings.Status -eq 200 -and @($readings.Data).Count -eq 1 -and $readings.Data[0].temperature -eq 4.2)
        $ai = Request POST "$GatewayUrl/api/v1/organizations/$org/dashboard/ai-interpretation" @{
            question = 'Como se encuentra la temperatura de conservacion?'
        } $headers
        Check 'advisory-access-respects-subscription' ($ai.Status -eq 409 -and $ai.Data.entitlementKey -eq 'ai-guidance')

        $period = @{
            title = 'Trazabilidad de conservacion Callao'
            periodStart = [DateTimeOffset]::UtcNow.AddHours(-1).ToString('o')
            periodEnd = [DateTimeOffset]::UtcNow.AddHours(1).ToString('o')
        }
        $reportReady = $false
        for ($attempt = 0; $attempt -lt 5 -and !$reportReady; $attempt++) {
            $job = Request POST "$GatewayUrl/api/v1/reports" $period $headers
            if ($job.Status -ne 202) { throw "Report submission returned HTTP $($job.Status)" }
            for ($poll = 0; $poll -lt 10; $poll++) {
                $reportResult = Request GET "$GatewayUrl/api/v1/reports/$($job.Data.id)/result" $null $headers
                if ($reportResult.Status -eq 200) {
                    $reportReady = $reportResult.Data.readingCount -eq 1
                    break
                }
                Start-Sleep -Seconds 1
            }
            if (!$reportReady) { Start-Sleep -Seconds 2 }
        }
        Check 'report-consumes-the-committed-reading-once' $reportReady
    } else {
        Check 'browser-token-is-not-workload-identity' ($internal.Status -eq 401)
    }
    $anonymous = Request GET "$AssetUrl/api/v1/organizations/$org/locations" $null
    Check 'anonymous-asset-read-denied' ($anonymous.Status -eq 401)
    $preflight = Request OPTIONS "$AssetUrl/api/v1/organizations/$org/locations" $null @{
        Origin = 'http://localhost:4200'; 'Access-Control-Request-Method' = 'POST'
        'Access-Control-Request-Headers' = 'authorization,content-type'
    }
    Check 'browser-cors-preflight' ($preflight.Status -eq 200 -and $preflight.Headers['Access-Control-Allow-Origin'] -contains 'http://localhost:4200')
} finally {
    $report = [ordered]@{
        verifiedAt = [DateTimeOffset]::UtcNow.ToString('o')
        identityUrl = $IdentityUrl; assetUrl = $AssetUrl; subscriptionUrl = $SubscriptionUrl
        checks = $results.ToArray()
    }
    $json = $report | ConvertTo-Json -Depth 8
    if ($OutputPath) { $json | Set-Content -LiteralPath $OutputPath -Encoding utf8 }
    $json
}
