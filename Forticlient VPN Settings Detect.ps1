<#
  .DESCRIPTION
    This script will detect if VPN profile is present
#>

# Defining variables for the VPN connection
$VPNName = "Young Harris College"

if ((Test-Path -LiteralPath "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$VPNName") -ne $true) {
  Write-Host "Not existing"
  Exit 1
}
Else {
  Write-Host "OK"
  Exit 0
}
