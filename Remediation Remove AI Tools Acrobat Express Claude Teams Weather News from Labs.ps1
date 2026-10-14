<#
    Intune Proactive Remediation - Remediation Script

    Purpose:
    Removes targeted AI apps, writing assistants, nuisanceware, PUA/PUP-style apps,
    Appx/MSIX packages, startup entries, residual folders, and known PUA registry artifacts.
#>

$ErrorActionPreference = 'SilentlyContinue'

function Write-Log {
    param([string]$Message)
    Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

# ============================================================
# Exclusions - Preserve Microsoft / Windows Copilot components
# ============================================================

$ExcludedNamePatterns = @(
    'Microsoft.Copilot',
    'Microsoft.Copilot*',
    'MicrosoftWindows.Client.CBS',
    'MicrosoftWindows.Client.WebExperience',
    'MicrosoftWindows.Client.AIX',
    'Microsoft.Windows.Ai.Copilot.Provider',
    'Microsoft.Copilot_8wekyb3d8bbwe',
    '*Microsoft.Windows.Copilot*',
    '*Windows Copilot*'
)

# ============================================================
# Win32 Targets - AI, writing tools, PUA/nuisanceware
# ============================================================

$Win32Targets = @(
    # Existing / productivity targets
    'Adobe Acrobat (64-bit)',
    'Adobe Acrobat Reader',
    'Adobe Refresh Manager',
    'Microsoft Teams',
    'Teams',

    # Major AI apps
    'Claude',
    'ChatGPT',
    'OpenAI ChatGPT',
    'Perplexity',
    'Perplexity AI',
    'Gemini',
    'Google Gemini',
    'Google AI Studio',
    'Poe',
    'LM Studio',
    'Jan',
    'AnythingLLM',
    'Cursor',
    'Windsurf',
    'Replit',
    'Ollama',
    'Open WebUI',

    # Coding assistants / AI IDEs
    'GitHub Copilot',
    'GitHub Copilot for Windows',
    'GitHub Copilot Chat',
    'Visual Studio Code - Insiders',
    'Trae',
    'Kiro',
    'Codeium',
    'Tabnine',
    'Blackbox',
    'Blackbox AI',
    'Continue',

    # Writing assistants
    'Grammarly',
    'Grammarly for Windows',
    'Grammarly Desktop',
    'Grammarly Editor',
    'QuillBot',
    'Wordtune',
    'ProWritingAid',
    'LanguageTool',
    'Ginger',
    'Jenni AI',
    'Paperpal',
    'Copy.ai',
    'Jasper',
    'Writesonic',
    'Rytr',
    'Hypotenuse AI',

    # Additional AI tools
    'Notion',
    'Notion AI',
    'Cogram',
    'DeepSeek',
    'DeepSeek AI',
    'Grok',
    'xAI',
    'You.com',
    'You.com Desktop',
    'Character.AI',
    'Pi',
    'Pi AI',
    'Mistral',
    'Le Chat',
    'Phind',
    'Monica',
    'Merlin',
    'Sider',
    'MaxAI',
    'HARPA AI',
    'Compose AI',
    'Fireflies',
    'Fireflies.ai',
    'Otter',
    'Otter.ai',
    'Fathom',
    'tl;dv',
    'Read AI',
    'Avoma',
    'Sembly',
    'Tactiq',
    'MeetGeek',
    'Krisp',

    # Optional - remove if your org wants to preserve this
    'Microsoft 365 Copilot Chat',

    # Tier 1 PUA / nuisanceware
    'OneLaunch',
    'OneLaunch Chromium',
    'Wave Browser',
    'WaveBrowser',
    'Wavesor Browser',
    'Wavesor',
    'Wavesor Software',
    'WebDiscover',
    'Web Discover Browser',
    'Search Protect',
    'SearchProtect',
    'PC App Store',
    'PC HelpSoft',
    'PC HelpSoft Driver Updater',
    'DriverPack Solution',
    'DriverPack',
    'SlimCleaner Plus',
    'SlimCleaner',
    'Reimage Repair',
    'Restoro',
    'Outbyte PC Repair',
    'Outbyte Driver Updater',
    'WinZip Driver Updater',
    'WinZip System Utilities Suite',
    'ZipRar',
    'PDFPower',
    'PDFPower Tool',
    'PDF Converter Hub',
    'FromDocToPDF',
    'MapsGalaxy',
    'MyWay Search Assistant',
    'Ask Toolbar',
    'Yahoo Toolbar',

    # Tier 2 PUA / nuisanceware
    'CCleaner',
    'CCleaner Browser',
    'Avast Secure Browser',
    'AVG Secure Browser',
    'Avast Cleanup',
    'AVG TuneUp',
    'McAfee WebAdvisor',
    'Norton Safe Web',
    'Norton Security Scan',
    'Avira Phantom VPN',
    'Opera',
    'Opera GX',
    'Brave',
    'Maxthon',
    'CryptoTab Browser',
    'uTorrent',
    'BitTorrent',
    'qBittorrent',
    'IObit Uninstaller',
    'IObit Driver Booster',
    'Advanced SystemCare',
    'Auslogics BoostSpeed',
    'Glary Utilities',
    'Wise Care 365',
    'Driver Easy',
    'Snappy Driver Installer',
    'Driver Talent',
    'DriverMax'
)

# ============================================================
# Appx / MSIX Targets
# ============================================================

$AppxTargets = @(
    # Existing targets
    'AdobeAcrobatReaderCoreApp',
    'AdobeSystemsIncorporated.AdobePhotoshopExpress',
    'MicrosoftTeams',
    'MSTeams',
    'Microsoft.BingWeather',
    'Microsoft.BingNews',

    # Major AI apps
    'AnthropicPBC.Claude',
    'OpenAI.ChatGPT-Desktop',
    'OpenAI.ChatGPT',
    'PerplexityAI.Perplexity',
    'Google.Gemini',
    'Poe',
    'Quora.Poe',
    'LMStudio',
    'Jan',
    'AnythingLLM',
    'Cursor',
    'Windsurf',
    'Replit',
    'Ollama',
    'OpenWebUI',

    # Writing tools
    'Grammarly',
    'Grammarly.Desktop',
    'Grammarly.Grammarly',
    'QuillBot',
    'Wordtune',
    'ProWritingAid',
    'LanguageTool',
    'Ginger',

    # Additional AI apps
    'DeepSeek',
    'DeepSeekAI',
    'xAI.Grok',
    'Notion',
    'NotionAI',
    'Youcom',
    'CharacterAI',
    'MistralAI',
    'Phind',
    'BlackboxAI',
    'Monica',
    'Merlin',
    'Sider',
    'MaxAI',
    'OtterAI',
    'FirefliesAI',
    'Fathom',
    'ReadAI',

    # PUA / nuisanceware Appx names, where applicable
    'OneLaunch',
    'WaveBrowser',
    'Wavesor',
    'WebDiscover',
    'PCAppStore',
    'DriverPack',
    'CCleaner',
    'AvastSecureBrowser',
    'AVGSecureBrowser',
    'Opera',
    'OperaGX',
    'Brave',
    'CryptoTab'
)

# ============================================================
# Wildcard AI / writing tool patterns
# ============================================================

$AINamePatterns = @(
    # Major AI platforms
    '*ChatGPT*',
    '*OpenAI*',
    '*Claude*',
    '*Anthropic*',
    '*Perplexity*',
    '*Gemini*',
    '*Google AI Studio*',
    '*Poe*',
    '*DeepSeek*',
    '*Grok*',
    '*xAI*',
    '*Mistral*',
    '*Le Chat*',
    '*You.com*',
    '*Character.AI*',
    '*CharacterAI*',
    '*Pi AI*',
    '*Inflection*',
    '*Phind*',

    # Local LLM / AI runtime tools
    '*LM Studio*',
    '*LM*Studio*',
    '*Jan*',
    '*AnythingLLM*',
    '*Ollama*',
    '*Open WebUI*',
    '*OpenWebUI*',
    '*GPT4All*',
    '*LocalAI*',
    '*Text Generation WebUI*',
    '*ComfyUI*',
    '*Stable Diffusion*',
    '*InvokeAI*',
    '*Fooocus*',
    '*KoboldCpp*',

    # AI coding tools / IDEs
    '*Cursor*',
    '*Windsurf*',
    '*Replit*',
    '*GitHub Copilot*',
    '*Codeium*',
    '*Tabnine*',
    '*Blackbox*',
    '*Blackbox AI*',
    '*Trae*',
    '*Kiro*',
    '*Continue*',

    # Writing assistants
    '*Grammarly*',
    '*QuillBot*',
    '*Wordtune*',
    '*ProWritingAid*',
    '*LanguageTool*',
    '*Ginger*',
    '*Jenni AI*',
    '*Paperpal*',
    '*Copy.ai*',
    '*Jasper*',
    '*Writesonic*',
    '*Rytr*',
    '*Hypotenuse AI*',

    # Meeting / transcription AI tools
    '*Otter*',
    '*Otter.ai*',
    '*Fireflies*',
    '*Fathom*',
    '*tl;dv*',
    '*Read AI*',
    '*Avoma*',
    '*Sembly*',
    '*Tactiq*',
    '*MeetGeek*',
    '*Krisp*',

    # Productivity / browser assistant tools
    '*Notion AI*',
    '*Cogram*',
    '*Monica*',
    '*Merlin*',
    '*Sider*',
    '*MaxAI*',
    '*HARPA*',
    '*Compose AI*'
)

# ============================================================
# PUA / nuisanceware patterns - Tier 1 and Tier 2
# ============================================================

$PUANamePatterns = @(
    # Tier 1
    '*OneLaunch*',
    '*Wave Browser*',
    '*WaveBrowser*',
    '*Wavesor*',
    '*WebDiscover*',
    '*Web Discover*',
    '*Search Protect*',
    '*SearchProtect*',
    '*PC App Store*',
    '*PC HelpSoft*',
    '*DriverPack*',
    '*SlimCleaner*',
    '*Reimage*',
    '*Restoro*',
    '*Outbyte*',
    '*WinZip Driver Updater*',
    '*WinZip System Utilities*',
    '*ZipRar*',
    '*PDFPower*',
    '*PDF Converter Hub*',
    '*FromDocToPDF*',
    '*MapsGalaxy*',
    '*MyWay*',
    '*Ask Toolbar*',
    '*Yahoo Toolbar*',

    # Tier 2
    '*CCleaner*',
    '*Avast Secure Browser*',
    '*AVG Secure Browser*',
    '*Avast Cleanup*',
    '*AVG TuneUp*',
    '*McAfee WebAdvisor*',
    '*Norton Safe Web*',
    '*Norton Security Scan*',
    '*Avira Phantom VPN*',
    '*Opera*',
    '*Opera GX*',
    '*Brave*',
    '*Maxthon*',
    '*CryptoTab*',
    '*uTorrent*',
    '*BitTorrent*',
    '*qBittorrent*',
    '*IObit*',
    '*Driver Booster*',
    '*Advanced SystemCare*',
    '*Auslogics*',
    '*Glary Utilities*',
    '*Wise Care 365*',
    '*Driver Easy*',
    '*Snappy Driver Installer*',
    '*Driver Talent*',
    '*DriverMax*'
)

# ============================================================
# Helper functions
# ============================================================

function Test-IsExcluded {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }

    foreach ($pattern in $ExcludedNamePatterns) {
        if ($Name -like $pattern) { return $true }
    }

    return $false
}

function Test-IsTargetApp {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    if (Test-IsExcluded -Name $Name) { return $false }

    if ($Win32Targets -contains $Name) { return $true }

    foreach ($pattern in $AINamePatterns) {
        if ($Name -like $pattern) { return $true }
    }

    foreach ($pattern in $PUANamePatterns) {
        if ($Name -like $pattern) { return $true }
    }

    return $false
}

function Get-UserSIDs {
    Get-ChildItem Registry::HKEY_USERS -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match '^S-1-5-21-.+' } |
        Select-Object -ExpandProperty PSChildName
}

# ============================================================
# Stop target processes
# ============================================================

function Stop-TargetProcesses {
    Write-Log "Stopping target processes..."

    $ProcessNames = @(
        # AI / writing / assistant processes
        'Grammarly',
        'Grammarly.Desktop',
        'ChatGPT',
        'Claude',
        'Perplexity',
        'Cursor',
        'Windsurf',
        'Notion',
        'Ollama',
        'LM Studio',
        'Jan',
        'Replit',
        'Codeium',
        'Tabnine',
        'Blackbox',
        'Monica',
        'Merlin',
        'Sider',
        'Otter',
        'Fireflies',
        'Fathom',

        # PUA processes
        'OneLaunch',
        'OneLaunchTray',
        'WaveBrowser',
        'Wavesor',
        'WebDiscoverBrowser',
        'WebDiscover',
        'SearchProtect',
        'PCAppStore',
        'DriverPack',
        'SlimCleaner',
        'ReimageRepair',
        'Restoro',
        'Outbyte',
        'WinZipDriverUpdater',
        'CCleaner',
        'CCleaner64',
        'AvastBrowser',
        'AVGBrowser',
        'Opera',
        'launcher',
        'brave',
        'BraveBrowser',
        'CryptoTab',
        'uTorrent',
        'BitTorrent',
        'qbittorrent',
        'IObitUninstaller',
        'DriverBooster',
        'AdvancedSystemCare',
        'BoostSpeed',
        'Integrator',
        'WiseCare365',
        'DriverEasy',
        'DriverTalent',
        'DriverMax'
    )

    foreach ($proc in $ProcessNames) {
        try {
            Get-Process -Name $proc -ErrorAction SilentlyContinue |
                Stop-Process -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Log "Failed stopping process: $proc"
        }
    }
}

# ============================================================
# Convert uninstall string to silent command
# ============================================================

function Convert-UninstallStringToSilent {
    param(
        [string]$UninstallString,
        [string]$DisplayName
    )

    if ([string]::IsNullOrWhiteSpace($UninstallString)) { return $null }

    $cmd = $UninstallString

    # MSI handling
    if ($cmd -match 'msiexec') {
        $cmd = $cmd -replace '/I', '/X'
        $cmd = $cmd -replace '/i', '/x'

        if ($cmd -notmatch '/qn') {
            $cmd = "$cmd /qn"
        }

        if ($cmd -notmatch '/norestart') {
            $cmd = "$cmd /norestart"
        }

        return $cmd
    }

    # Best effort handling for common EXE uninstallers
    if ($cmd -notmatch '/quiet|/silent|/S|--silent|--uninstall|/VERYSILENT') {
        if ($DisplayName -match 'ChatGPT|Claude|Perplexity|Cursor|Windsurf|Poe|LM Studio|Jan|AnythingLLM|Ollama|Grammarly|Notion|QuillBot|Wordtune|Codeium|Tabnine|OneLaunch|Wave|Wavesor|WebDiscover|Opera|Brave|CCleaner|Avast|AVG|IObit|Driver|Restoro|Outbyte') {
            $cmd = "$cmd /S"
        }
        else {
            $cmd = "$cmd /quiet /norestart"
        }
    }

    return $cmd
}

function Invoke-UninstallCommand {
    param(
        [string]$Command,
        [string]$DisplayName
    )

    if ([string]::IsNullOrWhiteSpace($Command)) {
        Write-Log "No uninstall command available for $DisplayName"
        return
    }

    Write-Log "Uninstalling: $DisplayName"

    try {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$Command`"" -Wait -WindowStyle Hidden
    }
    catch {
        Write-Log "Failed to uninstall $DisplayName. Error: $($_.Exception.Message)"
    }
}

# ============================================================
# Uninstall machine-wide Win32 apps
# ============================================================

function Uninstall-Win32AppByRegistry {
    Write-Log "Checking machine-wide installed applications..."

    $registryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($path in $registryPaths) {
        $apps = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue

        foreach ($app in $apps) {
            if (Test-IsTargetApp -Name $app.DisplayName) {
                Write-Log "Found machine app: $($app.DisplayName)"

                if ($app.QuietUninstallString) {
                    Invoke-UninstallCommand -Command $app.QuietUninstallString -DisplayName $app.DisplayName
                }
                elseif ($app.UninstallString) {
                    $silentCommand = Convert-UninstallStringToSilent -UninstallString $app.UninstallString -DisplayName $app.DisplayName
                    Invoke-UninstallCommand -Command $silentCommand -DisplayName $app.DisplayName
                }
                else {
                    Write-Log "No uninstall string found for $($app.DisplayName)"
                }
            }
        }
    }
}

# ============================================================
# Uninstall per-user Win32 apps from loaded user hives
# ============================================================

function Uninstall-PerUserWin32Apps {
    Write-Log "Checking per-user installed applications..."

    $sids = Get-UserSIDs

    foreach ($sid in $sids) {
        $userPath = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $apps = Get-ItemProperty -Path $userPath -ErrorAction SilentlyContinue

        foreach ($app in $apps) {
            if (Test-IsTargetApp -Name $app.DisplayName) {
                Write-Log "Found per-user app: $($app.DisplayName) SID: $sid"

                if ($app.QuietUninstallString) {
                    Invoke-UninstallCommand -Command $app.QuietUninstallString -DisplayName $app.DisplayName
                }
                elseif ($app.UninstallString) {
                    $silentCommand = Convert-UninstallStringToSilent -UninstallString $app.UninstallString -DisplayName $app.DisplayName
                    Invoke-UninstallCommand -Command $silentCommand -DisplayName $app.DisplayName
                }
                else {
                    Write-Log "No uninstall string found for $($app.DisplayName) SID: $sid"
                }
            }
        }
    }
}

# ============================================================
# Remove Appx / MSIX packages
# ============================================================

function Remove-AppxEverywhere {
    Write-Log "Removing installed Appx packages..."

    $installed = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue

    foreach ($pkg in $installed) {
        $name = $pkg.Name
        $family = $pkg.PackageFamilyName
        $isTarget = $false

        if (Test-IsExcluded -Name $name -or Test-IsExcluded -Name $family) { continue }

        if ($AppxTargets -contains $name) {
            $isTarget = $true
        }
        else {
            foreach ($pattern in ($AINamePatterns + $PUANamePatterns)) {
                if ($name -like $pattern -or $family -like $pattern) {
                    $isTarget = $true
                    break
                }
            }
        }

        if ($isTarget) {
            try {
                Write-Log "Removing Appx: $name"
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            }
            catch {
                Write-Log "Error removing Appx $name : $($_.Exception.Message)"
            }
        }
    }

    Write-Log "Removing provisioned Appx packages..."

    $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue

    foreach ($prov in $provisioned) {
        $name = $prov.DisplayName
        $isTarget = $false

        if (Test-IsExcluded -Name $name) { continue }

        if ($AppxTargets -contains $name) {
            $isTarget = $true
        }
        else {
            foreach ($pattern in ($AINamePatterns + $PUANamePatterns)) {
                if ($name -like $pattern) {
                    $isTarget = $true
                    break
                }
            }
        }

        if ($isTarget) {
            try {
                Write-Log "Removing provisioned package: $name"
                Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue
            }
            catch {
                Write-Log "Error removing provisioned package $name : $($_.Exception.Message)"
            }
        }
    }
}

# ============================================================
# Remove startup entries
# ============================================================

function Remove-TargetStartupEntries {
    Write-Log "Checking startup entries..."

    $StartupPatterns = @(
        # AI / writing tools
        '*Grammarly*',
        '*ChatGPT*',
        '*Claude*',
        '*Perplexity*',
        '*Cursor*',
        '*Windsurf*',
        '*Notion*',
        '*Ollama*',
        '*LM Studio*',
        '*QuillBot*',
        '*Wordtune*',
        '*Monica*',
        '*Merlin*',
        '*Sider*',
        '*Otter*',
        '*Fireflies*',
        '*Fathom*',

        # PUA startup patterns
        '*OneLaunch*',
        '*Wave Browser*',
        '*WaveBrowser*',
        '*Wavesor*',
        '*WebDiscover*',
        '*SearchProtect*',
        '*Search Protect*',
        '*PC App Store*',
        '*PC HelpSoft*',
        '*DriverPack*',
        '*SlimCleaner*',
        '*Reimage*',
        '*Restoro*',
        '*Outbyte*',
        '*WinZip Driver Updater*',
        '*CCleaner*',
        '*Avast Secure Browser*',
        '*AVG Secure Browser*',
        '*Avast Cleanup*',
        '*AVG TuneUp*',
        '*McAfee WebAdvisor*',
        '*Norton Safe Web*',
        '*Norton Security Scan*',
        '*Avira Phantom VPN*',
        '*Opera*',
        '*Opera GX*',
        '*Brave*',
        '*Maxthon*',
        '*CryptoTab*',
        '*uTorrent*',
        '*BitTorrent*',
        '*qBittorrent*',
        '*IObit*',
        '*Advanced SystemCare*',
        '*Auslogics*',
        '*Glary Utilities*',
        '*Wise Care 365*',
        '*Driver Easy*',
        '*Snappy Driver Installer*',
        '*Driver Talent*',
        '*DriverMax*'
    )

    $StartupRunPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
    )

    foreach ($path in $StartupRunPaths) {
        if (Test-Path $path) {
            $props = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue

            foreach ($property in $props.PSObject.Properties) {
                foreach ($pattern in $StartupPatterns) {
                    if ($property.Name -like $pattern -or [string]$property.Value -like $pattern) {
                        Write-Log "Removing startup entry: $($property.Name) from $path"
                        Remove-ItemProperty -Path $path -Name $property.Name -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }

    $UserSIDs = Get-UserSIDs

    foreach ($sid in $UserSIDs) {
        $userRunPath = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Run"

        if (Test-Path $userRunPath) {
            $props = Get-ItemProperty -Path $userRunPath -ErrorAction SilentlyContinue

            foreach ($property in $props.PSObject.Properties) {
                foreach ($pattern in $StartupPatterns) {
                    if ($property.Name -like $pattern -or [string]$property.Value -like $pattern) {
                        Write-Log "Removing user startup entry: $($property.Name) from SID $sid"
                        Remove-ItemProperty -Path $userRunPath -Name $property.Name -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }
}

# ============================================================
# Remove residual folders
# ============================================================

function Remove-ResidualTargetFolders {
    Write-Log "Checking for residual target folders..."

    $FolderPatterns = @(
        # AI / writing / assistant app folders
        '*Grammarly*',
        '*ChatGPT*',
        '*Claude*',
        '*Perplexity*',
        '*Cursor*',
        '*Windsurf*',
        '*Notion*',
        '*Ollama*',
        '*LM Studio*',
        '*Jan*',
        '*AnythingLLM*',
        '*OpenWebUI*',
        '*Open WebUI*',
        '*DeepSeek*',
        '*Grok*',
        '*QuillBot*',
        '*Wordtune*',
        '*Codeium*',
        '*Tabnine*',
        '*Blackbox*',
        '*Monica*',
        '*Merlin*',
        '*Sider*',
        '*Otter*',
        '*Fireflies*',
        '*Fathom*',

        # PUA folders - Tier 1 and Tier 2
        '*OneLaunch*',
        '*Wave Browser*',
        '*WaveBrowser*',
        '*Wavesor*',
        '*WebDiscover*',
        '*Web Discover*',
        '*SearchProtect*',
        '*Search Protect*',
        '*PC App Store*',
        '*PC HelpSoft*',
        '*DriverPack*',
        '*SlimCleaner*',
        '*Reimage*',
        '*Restoro*',
        '*Outbyte*',
        '*WinZip Driver Updater*',
        '*ZipRar*',
        '*PDFPower*',
        '*MyWay*',
        '*Ask Toolbar*',
        '*CCleaner*',
        '*Avast Secure Browser*',
        '*AVG Secure Browser*',
        '*Avast Cleanup*',
        '*AVG TuneUp*',
        '*McAfee WebAdvisor*',
        '*Norton Safe Web*',
        '*Norton Security Scan*',
        '*Avira Phantom VPN*',
        '*Opera*',
        '*Opera GX*',
        '*Brave*',
        '*Maxthon*',
        '*CryptoTab*',
        '*uTorrent*',
        '*BitTorrent*',
        '*qBittorrent*',
        '*IObit*',
        '*Advanced SystemCare*',
        '*Auslogics*',
        '*Glary Utilities*',
        '*Wise Care 365*',
        '*Driver Easy*',
        '*Snappy Driver Installer*',
        '*Driver Talent*',
        '*DriverMax*'
    )

    $UserProfileRoots = Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -notin @(
                'Public',
                'Default',
                'Default User',
                'All Users',
                'defaultuser0'
            )
        }

    foreach ($profile in $UserProfileRoots) {
        $SearchFolders = @(
            "$($profile.FullName)\AppData\Local",
            "$($profile.FullName)\AppData\Roaming",
            "$($profile.FullName)\AppData\Local\Programs",
            "$($profile.FullName)\AppData\LocalLow"
        )

        foreach ($folder in $SearchFolders) {
            if (Test-Path $folder) {
                foreach ($pattern in $FolderPatterns) {
                    Get-ChildItem -Path $folder -Directory -Filter $pattern -ErrorAction SilentlyContinue | ForEach-Object {
                        try {
                            Write-Log "Removing residual folder: $($_.FullName)"
                            Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        catch {
                            Write-Log "Failed removing residual folder: $($_.FullName)"
                        }
                    }
                }
            }
        }
    }

    $MachineFolderRoots = @(
        "$env:ProgramFiles",
        "${env:ProgramFiles(x86)}",
        "$env:ProgramData"
    )

    foreach ($root in $MachineFolderRoots) {
        if (Test-Path $root) {
            foreach ($pattern in $FolderPatterns) {
                Get-ChildItem -Path $root -Directory -Filter $pattern -ErrorAction SilentlyContinue | ForEach-Object {
                    try {
                        Write-Log "Removing machine residual folder: $($_.FullName)"
                        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    catch {
                        Write-Log "Failed removing machine residual folder: $($_.FullName)"
                    }
                }
            }
        }
    }
}

# ============================================================
# Remove known PUA registry artifacts
# ============================================================

function Remove-PUARegistryArtifacts {
    Write-Log "Checking for known PUA registry artifacts..."

    $UserSIDs = Get-UserSIDs

    foreach ($sid in $UserSIDs) {
        $KnownPUAKeys = @(
            "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Uninstall\WaveBrowser",
            "Registry::HKEY_USERS\$sid\Software\Wavesor",
            "Registry::HKEY_USERS\$sid\Software\WaveBrowser",
            "Registry::HKEY_USERS\$sid\Software\OneLaunch",
            "Registry::HKEY_USERS\$sid\Software\WebDiscover",
            "Registry::HKEY_USERS\$sid\Software\SearchProtect",
            "Registry::HKEY_USERS\$sid\Software\PC HelpSoft",
            "Registry::HKEY_USERS\$sid\Software\Restoro",
            "Registry::HKEY_USERS\$sid\Software\Outbyte"
        )

        foreach ($key in $KnownPUAKeys) {
            if (Test-Path $key) {
                try {
                    Write-Log "Removing PUA registry artifact: $key"
                    Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Log "Failed removing PUA registry artifact: $key"
                }
            }
        }
    }

    $MachinePUAKeys = @(
        'HKLM:\Software\Wavesor',
        'HKLM:\Software\WaveBrowser',
        'HKLM:\Software\OneLaunch',
        'HKLM:\Software\WebDiscover',
        'HKLM:\Software\SearchProtect',
        'HKLM:\Software\PC HelpSoft',
        'HKLM:\Software\Restoro',
        'HKLM:\Software\Outbyte',
        'HKLM:\Software\WOW6432Node\Wavesor',
        'HKLM:\Software\WOW6432Node\WaveBrowser',
        'HKLM:\Software\WOW6432Node\OneLaunch',
        'HKLM:\Software\WOW6432Node\WebDiscover',
        'HKLM:\Software\WOW6432Node\SearchProtect',
        'HKLM:\Software\WOW6432Node\PC HelpSoft',
        'HKLM:\Software\WOW6432Node\Restoro',
        'HKLM:\Software\WOW6432Node\Outbyte'
    )

    foreach ($key in $MachinePUAKeys) {
        if (Test-Path $key) {
            try {
                Write-Log "Removing machine PUA registry artifact: $key"
                Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-Log "Failed removing machine PUA registry artifact: $key"
            }
        }
    }
}

# ============================================================
# Main execution
# ============================================================

Write-Log "Starting remediation process..."

Stop-TargetProcesses
Uninstall-Win32AppByRegistry
Uninstall-PerUserWin32Apps
Remove-AppxEverywhere
Remove-TargetStartupEntries
Remove-ResidualTargetFolders
Remove-PUARegistryArtifacts

Write-Log "Remediation complete."
exit 0