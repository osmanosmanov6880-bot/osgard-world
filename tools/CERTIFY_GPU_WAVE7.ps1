param([string]$ReportDirectory = "")
$ErrorActionPreference = 'Stop'
if (-not $ReportDirectory) {
    $ReportDirectory = Join-Path $PSScriptRoot 'GPU_REPORTS_WAVE6'
}
Write-Host 'OSGARD WAVE 7 — PHYSICAL GPU REPORT AUDITOR' -ForegroundColor Cyan
Write-Host 'Measures are ONLY taken from reports produced by the actual Windows executables.'
if (-not (Test-Path $ReportDirectory)) {
    Write-Host "MISSING_REPORTS: $ReportDirectory" -ForegroundColor Yellow
    exit 2
}
$driverNames = @()
try {
    $driverNames = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name })
} catch {
    Write-Host "GPU inventory unavailable: $($_.Exception.Message)" -ForegroundColor Yellow
}
$games = @('vector','chronos')
$qualities = @('ultra','balanced')
$screenModes = @('1080','1440')
$results = @()
foreach ($game in $games) {
    foreach ($screen in $screenModes) {
        foreach ($quality in $qualities) {
            $name = "${game}_${screen}_${quality}.json"
            $path = Join-Path $ReportDirectory $name
            if (-not (Test-Path $path)) {
                $results += [pscustomobject]@{ File=$name; Status='INCOMPLETE'; FPS=$null; P95=$null; Adapter='' }
                continue
            }
            try {
                $data = Get-Content -Raw -Path $path -Encoding UTF8 | ConvertFrom-Json
                $physicalCandidate = $data.physical_gpu_validation_candidate -eq $true
                $methodOk = $data.rendering_method -eq 'forward_plus'
                $notSoftware = $data.is_software_renderer -eq $false
                $durationOk = [double]$data.measurement_seconds -ge 24.0
                $samplesOk = [int]$data.frames -ge 100
                $adapter = [string]$data.adapter
                $adapterOk = $adapter.Length -gt 2 -and $adapter -notmatch '(?i)llvmpipe|swiftshader|basic render|softpipe|vmware|virtualbox'
                $imageX = if ($screen -eq '1080') { 1920 } else { 2560 }
                $imageY = if ($screen -eq '1080') { 1080 } else { 1440 }
                $dimensionsOk = [int]$data.res_x -eq $imageX -and [int]$data.res_y -eq $imageY
                if (-not ($physicalCandidate -and $methodOk -and $notSoftware -and $durationOk -and $samplesOk -and $adapterOk -and $dimensionsOk)) {
                    $status = 'NOT_HARDWARE_VALIDATED'
                } elseif ([double]$data.mean_fps -ge 60.0 -and [double]$data.p95_frame_ms -le 16.67) {
                    $status = 'PASS_60FPS'
                } else {
                    $status = 'PERFORMANCE_FAIL'
                }
                $results += [pscustomobject]@{
                    File=$name; Status=$status; FPS=[math]::Round([double]$data.mean_fps,2)
                    P95=[math]::Round([double]$data.p95_frame_ms,2); Adapter=$adapter
                }
            } catch {
                $results += [pscustomobject]@{ File=$name; Status='INVALID_JSON'; FPS=$null; P95=$null; Adapter='' }
            }
        }
    }
}
$results | Format-Table -AutoSize
$passCount = @($results | Where-Object { $_.Status -eq 'PASS_60FPS' }).Count
$validatedCount = @($results | Where-Object { $_.Status -in @('PASS_60FPS','PERFORMANCE_FAIL') }).Count
$overall = if ($passCount -eq 8) { 'HARDWARE_PASS_ALL_EIGHT' } elseif ($validatedCount -eq 8) { 'HARDWARE_MEASURED_PERFORMANCE_NOT_MET' } else { 'NOT_CERTIFIED_OR_INCOMPLETE' }
$report = [ordered]@{
    schema = 'osgard.wave7.gpu-signoff.v1'
    status = $overall
    actual_gpu_inventory = $driverNames
    measurement_count = $results.Count
    hardware_validated_measurements = $validatedCount
    passing_measurements = $passCount
    target_fps = 60
    target_p95_ms = 16.67
    results = @($results)
    created_utc = (Get-Date).ToUniversalTime().ToString('o')
    limitation = 'Running this script does not itself run GPU hardware. The originating Windows benchmark JSON must come from physical GPU execution.'
}
$output = Join-Path $ReportDirectory 'OSGARD_WAVE7_GPU_CERTIFICATION.json'
$report | ConvertTo-Json -Depth 7 | Out-File -FilePath $output -Encoding UTF8
Write-Host "WAVE7 RESULT: $overall; saved $output" -ForegroundColor Cyan
if ($overall -eq 'HARDWARE_PASS_ALL_EIGHT') { exit 0 }
exit 1
