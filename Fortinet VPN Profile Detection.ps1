<#
.DESCRIPTION
    Detection script for Fortinet VPN profile via Intune.
#>

$VPNName = "Young Harris College"
$vpnKeyPath = "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$VPNName"

if (Test-Path $vpnKeyPath) {
    Write-Output "VPN profile '$VPNName' exists."
    exit 0
} else {
    Write-Output "VPN profile '$VPNName' not found."
    exit 1
}
