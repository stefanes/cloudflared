[CmdletBinding()]
param (
  [Alias('Path')]
  [string] $CloudflaredPath = "$PSScriptRoot\cloudflared-windows-amd64.exe",

  [Parameter(Mandatory = $true)]
  [Alias('Host')]
  [string] $HostName,

  [string] $Service = 'http://homeassistant.local:8123',

  [Object] $DefaultServices = @(
    @{
      domain  = 'status'
      service = 'http://homeassistant.local:4357'
    }
    @{
      domain  = 'router'
      service = 'http://192.168.1.1'
    }
  ),

  [Object] $AdditionalServices = @(),

  [Alias('Tunnel')]
  [string] $TunnelName = ($HostName -replace '[^a-z0-9]', '-')
)

Write-Host "Logging in to Cloudflare..." -ForegroundColor Green
if (-Not (Test-Path -Path "$env:USERPROFILE\.cloudflared\$TunnelName.pem")) {
  & $CloudflaredPath tunnel login
  Rename-Item -Path "$env:USERPROFILE\.cloudflared\cert.pem" -NewName "$TunnelName.pem"
} else {
  Write-Host "Already logged in. To force a re-login, please remove '$env:USERPROFILE\.cloudflared\$TunnelName.pem'."
}
$cert = "--origincert=$env:USERPROFILE\.cloudflared\$TunnelName.pem"

Write-Host "Creating tunnel..." -ForegroundColor Green
& $CloudflaredPath $cert tunnel list | Tee-Object -Variable tunnelList | Out-Null
$tunnelUuid = $null
foreach ($line in $tunnelList) {
  if ($line -match '^(?<uuid>[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})\s+(?<name>\S+)') {
    if ($Matches['name'] -eq $tunnelName) {
      Write-Host "Tunnel already exists."
      $tunnelUuid = $Matches['uuid']
    }
  }
}
if (-Not $tunnelUuid) {
  # Create new tunnel
  & $CloudflaredPath $cert --cred-file="$env:USERPROFILE\.cloudflared\$TunnelName.json" tunnel create $TunnelName
  & $CloudflaredPath $cert tunnel list | Tee-Object -Variable tunnelList | Out-Null
  foreach ($line in $tunnelList) {
    if ($line -match '^(?<uuid>[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})\s+(?<name>\S+)') {
      if ($Matches['name'] -eq $tunnelName) {
        $tunnelUuid = $Matches['uuid']
      }
    }
  }
}
Write-Host ($tunnelList | Out-String) -ForegroundColor DarkGray

Write-Host "Creating tunnel config..." -ForegroundColor Green
$config = @"
tunnel: $tunnelUuid
credentials-file: $env:USERPROFILE\.cloudflared\$TunnelName.json
logfile: $env:USERPROFILE\.cloudflared\$TunnelName.log
ingress:
  - hostname: $HostName
    service: $Service
    originRequest:
      noTLSVerify: true
"@
# Additional services
foreach ($additionalService in $AdditionalServices) {
  $config += @"

  - hostname: $($additionalService.domain).$HostName
    service: $($additionalService.service)
    originRequest:
      noTLSVerify: true
"@
}
# Default services
foreach ($additionalService in $DefaultServices) {
  if ($AdditionalServices.domain -notcontains $additionalService.domain) {
    $config += @"

  - hostname: $($additionalService.domain).$HostName
    service: $($additionalService.service)
    originRequest:
      noTLSVerify: true
"@
  }
}
# Catch all service
$config += @"

  - service: http_status:404
"@
$config | Out-File -FilePath "$env:USERPROFILE\.cloudflared\$TunnelName.yml"
Get-Content -Path "$env:USERPROFILE\.cloudflared\$TunnelName.yml"

Write-Host "Creating DNS entries..." -ForegroundColor Green
& $CloudflaredPath $cert tunnel route dns -f $tunnelUuid "$HostName"
foreach ($additionalService in $DefaultServices) {
  & $CloudflaredPath $cert tunnel route dns -f $tunnelUuid "$($additionalService.domain).$HostName"
}
foreach ($additionalService in $AdditionalServices) {
  & $CloudflaredPath $cert tunnel route dns -f $tunnelUuid "$($additionalService.domain).$HostName"
}

Write-Host "Connecting tunnel..." -ForegroundColor Green
& $CloudflaredPath $cert --no-autoupdate tunnel --config "$env:USERPROFILE\.cloudflared\$TunnelName.yml" run "$tunnelUuid"
