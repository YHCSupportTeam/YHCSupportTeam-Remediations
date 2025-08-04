# Remediation script to silently upgrade all winget packages
try {
    Start-Process "winget" -ArgumentList "upgrade --all --silent" -NoNewWindow -Wait
    exit 0
} catch {
    exit 1
}
