# ========================
# Configuration
# ========================
$softLimitDays = 30
$hardLimitDays = 45
$notifyStartDays = 29

$restrictedStart = [DateTime]::ParseExact("07:45", "HH:mm", $null)
$restrictedEnd   = [DateTime]::ParseExact("17:30", "HH:mm", $null)

# ========================
# Uptime Calculation
# ========================
$currentTime = Get-Date
$lastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$uptimeDays = ($currentTime - $lastBoot).Days
$timeOfDay = $currentTime.TimeOfDay

# ========================
# Toast Notification Function (native, no modules)
# ========================
function Show-RestartToast {
    param (
        [string]$Title,
        [string]$Message
    )

    $template = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$Title</text>
      <text>$Message</text>
    </binding>
  </visual>
</toast>
"@

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($template)

    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("IT Support")
    $notifier.Show($toast)
}

# ========================
# HARD LIMIT — FORCE REBOOT
# ========================
if ($uptimeDays -ge $hardLimitDays) {
    Write-Output "Hard limit reached ($uptimeDays days). Forcing reboot."
    Restart-Computer -Force
    exit 0
}

# ========================
# TOAST NOTIFICATION WINDOW
# ========================
if ($uptimeDays -ge $notifyStartDays -and $uptimeDays -lt $softLimitDays) {

    Show-RestartToast `
        -Title "Restart Required" `
        -Message "Your device has not restarted in $uptimeDays days. Please restart within 24 hours to avoid automatic reboot."

    Write-Output "Toast notification displayed."
    exit 0
}

# ========================
# SOFT LIMIT — BUSINESS HOURS LOGIC
# ========================
if ($uptimeDays -ge $softLimitDays) {

