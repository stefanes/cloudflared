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
Write-Host "Note: Choose any website that you have added into your account. The authentication is account-wide and you can use the same authentication flow for multiple hostnames in your account regardless of which you choose in this step." -ForegroundColor DarkGray
if (-Not (Test-Path -Path "$env:USERPROFILE\.cloudflared\cert.pem")) {
  & $CloudflaredPath tunnel login
}
else {
  Write-Host "Already logged in. To force a re-login, please remove '$env:USERPROFILE\.cloudflared\cert.pem'."
}

Write-Host "Creating tunnel..." -ForegroundColor Green
& $CloudflaredPath tunnel list | Tee-Object -Variable tunnelList | Out-Null
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
  & $CloudflaredPath tunnel create $TunnelName
  & $CloudflaredPath tunnel list | Tee-Object -Variable tunnelList | Out-Null
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
credentials-file: $env:USERPROFILE\.cloudflared\$tunnelUuid.json
logfile: $env:USERPROFILE\.cloudflared\$tunnelUuid.log
ingress:
  - hostname: $HostName
    service: $Service
    originRequest:
      noTLSVerify: true
"@
# Default services
foreach ($additionalService in $DefaultServices) {
  $config += @"

  - hostname: $($additionalService.domain).$HostName
    service: $($additionalService.service)
    originRequest:
      noTLSVerify: true
"@
}
# Additional services
foreach ($additionalService in $AdditionalServices) {
  $config += @"

  - hostname: $($additionalService.domain).$HostName
    service: $($additionalService.service)
    originRequest:
      noTLSVerify: true
"@
}
# Catch all service 
$config += @"

  - service: http_status:404
"@
$config | Out-File -FilePath "$env:USERPROFILE\.cloudflared\$tunnelUuid.yml"
Get-Content -Path "$env:USERPROFILE\.cloudflared\$tunnelUuid.yml"

Write-Host "Creating DNS entries..." -ForegroundColor Green
& $CloudflaredPath tunnel route dns -f $tunnelUuid "$HostName"
foreach ($additionalService in $DefaultServices) {
  & $CloudflaredPath tunnel route dns -f $tunnelUuid "$($additionalService.domain).$HostName"
}
foreach ($additionalService in $AdditionalServices) {
  & $CloudflaredPath tunnel route dns -f $tunnelUuid "$($additionalService.domain).$HostName"
}

Write-Host "Connecting tunnel..." -ForegroundColor Green
& $CloudflaredPath --no-autoupdate tunnel --metrics="0.0.0.0:36500" --config "$env:USERPROFILE\.cloudflared\$tunnelUuid.yml" run "$tunnelUuid"
