<#
.DESCRIPTION
    Remediation script to create Fortinet VPN profile via Intune.
#>

$VPNName = "Young Harris College"
$Server = "vpn.yhc.edu:10443"
$TunnelPath = "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$VPNName"

try {
    if (-not (Test-Path $TunnelPath)) {
        New-Item -Path $TunnelPath -Force | Out-Null
    }

    $properties = @{
        Description          = $VPNName
        Server               = $Server
        promptusername       = 0
        promptcertificate    = 0
        ServerCert           = "1"
        sso_enabled          = 1
        use_external_browser = 0
    }

    foreach ($name in $properties.Keys) {
        $value = $properties[$name]
        $type = if ($value -is [int]) { 'DWord' } else { 'String' }

        New-ItemProperty -Path $TunnelPath -Name $name -Value $value -PropertyType $type -Force -ErrorAction SilentlyContinue | Out-Null
    }

    if (Test-Path $TunnelPath) {
        Write-Output "VPN profile '$VPNName' created successfully."
        exit 0
    } else {
        Write-Output "Failed to create VPN profile."
        exit 1
    }

} catch {
    Write-Output "Error occurred: $_"
    exit 1
}
