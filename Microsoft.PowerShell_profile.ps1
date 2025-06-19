#opt-out of telemetry before doing anything, only if PowerShell is run as admin
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

$modules = @(
    'Terminal-Icons',
    # 'PSCompletions',
    'Microsoft.WinGet.CommandNotFound'
)

# Utility Functions (moved up for use in jobs)
function Test-CommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

# Skip connectivity check for instant startup - assume connected
$canConnectToGitHub = $true

# Background maintenance (runs after profile loads)
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    # Clean up any background jobs on exit
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
}

# Background module installation and updates (completely silent)
if ($canConnectToGitHub) {
    $null = Start-Job -Name "ProfileMaintenance" -ArgumentList $modules -ScriptBlock {
        param($moduleList)
        $installed = @()
        
        # Install missing modules
        foreach ($module in $moduleList) {
            if (-not (Get-Module -ListAvailable -Name $module)) {
                try {
                    Install-Module -Name $module -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction Stop
                    $installed += $module
                }
                catch {
                    # Silent fail
                }
            }
        }
        # Configure PSCompletions if newly installed
        if ($installed -contains 'PSCompletions') {
            try {
                Import-Module -Name PSCompletions -Force
                if (Get-Command psc -ErrorAction SilentlyContinue) {
                    psc add cargo checo docker fnm git pip powershell scoop sfsu winget wsl
                    psc menu config enable_menu 0
                }
            }
            catch {
                # Silent fail
            }
        }
        
        return $installed
    }
    
    # Install zoxide if missing
    if (-not (Test-CommandExists zoxide)) {
        $null = Start-Job -Name "ZoxideInstall" -ScriptBlock {
            try {
                winget install -e --id ajeetdsouza.zoxide --silent
            }
            catch {
                # Silent fail
            }
        }
    }
}

# Background updates check (completely silent)
if ($canConnectToGitHub) {
    $null = Start-Job -Name "UpdateCheck" -ArgumentList $PROFILE -ScriptBlock {
        param($ProfilePath)
        $results = @()
        
        # Profile update check
        try {
            if ($ProfilePath -and (Test-Path $ProfilePath)) {
                $url = "https://raw.githubusercontent.com/CodeClimberNT/powershell-profile/refs/heads/main/Microsoft.PowerShell_profile.ps1"
                $oldhash = Get-FileHash $ProfilePath
                $tempPath = Join-Path $env:TEMP "Microsoft.PowerShell_profile.ps1"
                Invoke-RestMethod $url -OutFile $tempPath -TimeoutSec 10
                $newhash = Get-FileHash $tempPath
                if ($newhash.Hash -ne $oldhash.Hash) {
                    $results += "Profile update available"
                }
                # Clean up temp file
                if (Test-Path $tempPath) {
                    Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
                }
            }
        }
        catch {
            # Silent fail - don't block startup
        }
        
        # PowerShell update check
        try {
            $currentVersion = $PSVersionTable.PSVersion.ToString()
            $latestVersion = (Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest" -TimeoutSec 10).tag_name.Trim('v')
            if ($currentVersion -lt $latestVersion) {
                $results += "PowerShell update available"
            }
        }
        catch {
            # Silent fail - don't block startup
        }
        
        return $results
    }
}

# Admin Check and Prompt Customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

# Editor Configuration
$EDITOR = if (Test-CommandExists nvim) { 'nvim' }
elseif (Test-CommandExists pvim) { 'pvim' }
elseif (Test-CommandExists vim) { 'vim' }
elseif (Test-CommandExists vi) { 'vi' }
elseif (Test-CommandExists code) { 'code' }
elseif (Test-CommandExists notepad++) { 'notepad++' }
elseif (Test-CommandExists sublime_text) { 'sublime_text' }
else { 'notepad' }
Set-Alias -Name vim -Value $EDITOR
Set-Alias -Name n -Value notepad

$FETCH = if (Test-CommandExists neofetch) { 'neofetch' }
elseif (Test-CommandExists fastfetch) { 'fastfetch' }
if ($FETCH) { Set-Alias -Name fetch -Value $FETCH }

function Edit-Profile {
    vim $PROFILE
}

function Update-Profile {
    & $profile
}

function touch($file) { "" | Out-File $file -Encoding ASCII }
function ff($name) {
    Get-ChildItem -Recurse -Filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.directory)\$($_)"
    }
}

# Network Utilities
function Get-PubIP { 
    if ($canConnectToGitHub) {
        try {
            (Invoke-WebRequest http://ifconfig.me/ip -TimeoutSec 5).Content
        }
        catch {
            Write-Warning "Failed to get public IP: $_"
        }
    }
    else {
        Write-Warning "No internet connectivity detected"
    }
}

# Open WinUtil
function winutil {
    if ($canConnectToGitHub) {
        try { Invoke-WebRequest -useb https://christitus.com/win | Invoke-Expression }
        catch { Write-Warning "Failed to run WinUtil" }
    }
    else { Write-Warning "No internet connectivity" }
}

# System Utilities
function admin {
    if ($args.Count -gt 0) {
        $argList = "& '$args'"
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
    }
    else {
        Start-Process wt -Verb runAs
    }
}

# Set UNIX-like aliases for the admin command, so sudo <command> will run the command with elevated rights.
Set-Alias -Name su -Value admin

# System Utilities
function uptime {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        Get-WmiObject win32_operatingsystem | Select-Object @{Name = 'LastBootUpTime'; Expression = { $_.ConverttoDateTime($_.lastbootuptime) } } | Format-Table -HideTableHeaders
    }
    else {
        net statistics workstation | Select-String "since" | ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
    }
}

function unzip ($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}

function grep($regex, $dir) {
    if ( $dir ) {
        Get-ChildItem $dir | Select-String $regex
        return
    }
    $input | Select-String $regex
}

function df {
    Get-Volume
}

function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
    Set-Item -Force -Path "env:$name" -Value $value;
}

function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
    Get-Process $name
}

function head {
    param($Path, $n = 10)
    Get-Content $Path -Head $n
}

function tail {
    param($Path, $n = 10)
    Get-Content $Path -Tail $n
}

# Quick File Creation
function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }

# Directory Management
function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }

### Quality of Life Aliases

# Navigation Shortcuts
function docs { Set-Location -Path $HOME\Documents }

function dtop { Set-Location -Path $HOME\Desktop }

# Quick Access to Editing the Profile
function ep { vim $PROFILE }

# Simplified Process Management
function k9 { Stop-Process -Name $args[0] }

# Enhanced Listing
function la { Get-ChildItem -Path . -Force | Format-Table -AutoSize }
function ll { Get-ChildItem -Path . -Force -Hidden | Format-Table -AutoSize }

# Git Shortcuts
function gs { git status }

function ga { git add . }

function gc { param($m) git commit -m "$m" }

function gp { git push }

function g { z Github }

function gcom {
    git add .
    git commit -m "$args"
}
function lazyg {
    git add .
    git commit -m "$args"
    git push
}

# Quick Access to System Information
function sysinfo { Get-ComputerInfo }

# Networking Utilities
function flushdns {
    Clear-DnsClientCache
    Write-Host "DNS has been flushed"
}

# Clipboard Utilities
function cpy { Set-Clipboard $args[0] }

function pst { Get-Clipboard }

# Compute file hashes - useful for checking successful downloads 
function md5 { Get-FileHash -Algorithm MD5 $args }
function sha1 { Get-FileHash -Algorithm SHA1 $args }
function sha256 { Get-FileHash -Algorithm SHA256 $args }

# Enhanced PowerShell Experience
Set-PSReadLineOption -Colors @{
    Command   = 'Yellow'
    Parameter = 'Green'
    String    = 'DarkCyan'
}

$PSROptions = @{
    ContinuationPrompt = '  '
    Colors             = @{
        Parameter        = $PSStyle.Foreground.Magenta
        Selection        = $PSStyle.Background.Black
        InLinePrediction = $PSStyle.Foreground.BrightYellow + $PSStyle.Background.BrightBlack
    }
}

Set-PSReadLineOption @PSROptions
Set-PSReadLineKeyHandler -Chord 'Ctrl+f' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Enter' -Function ValidateAndAcceptLine

# Initialize prompt tools immediately (but optimized)
if (Test-CommandExists starship) {
    Invoke-Expression (&starship init powershell)
}
elseif (Test-CommandExists oh-my-posh) {
    oh-my-posh init pwsh --config "https://raw.githubusercontent.com/CodeClimberNT/oh-my-posh/main/powerlevel10k_rainbow.omp.json" | Invoke-Expression
}

# Initialize essential tools
if (Test-CommandExists zoxide) {
    try {
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
        Set-Alias -Name z -Value __zoxide_z -Option AllScope -Scope Global -Force
        Set-Alias -Name zi -Value __zoxide_zi -Option AllScope -Scope Global -Force
    }
    catch {
        # Silent fail for speed
    }
}

if (Test-CommandExists sfsu) {
    Invoke-Expression (&sfsu hook)
}

if (Test-CommandExists fnm) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}

#rgb(232, 8, 46) PSCompletions functions (commented out - uncomment to use)
# function Add-Completions {
#     if (Get-Command psc -ErrorAction SilentlyContinue) {
#         Invoke-Expression("psc add cargo choco docker fnm git pip powershell scoop sfsu winget wsl")
#     }
# }       

# function Update-Psc {
#     if (Get-Command psc -ErrorAction SilentlyContinue) {
#         Invoke-Expression("psc update *")
#     }
# }

# function Set-PscDefaults {
#     if (Get-Command psc -ErrorAction SilentlyContinue) {
#         $pscCommands = @(
#             "psc menu config enable_menu 0"
#         )
        
#         foreach ($command in $pscCommands) {
#             Invoke-Expression $command
#         }
#     }
# }

function Clear-PSHistory {
    # Get the path of the PSReadline history file
    $historyPath = (Get-PSReadlineOption).HistorySavePath

    # Check if the history file exists before attempting to delete
    if (Test-Path -Path $historyPath) {
        # Delete the history file
        Remove-Item -Path $historyPath -Force
        Write-Host "History cleared. Changes will take effect in new sessions."
    }
    else {
        Write-Host "No history file found at the specified path."
    }
}

# Import essential modules at startup (optimized with better error handling)
foreach ($module in $modules) {
    if (Get-Module -ListAvailable -Name $module) {
        try {
            Import-Module -Name $module -Force -ErrorAction Stop
        }
        catch {
            # Silent fail for specific problematic modules
            if ($module -eq 'Microsoft.WinGet.CommandNotFound') {
                # This module sometimes has dependency issues - skip silently
                continue
            }
            # For other modules, continue silently but could log if needed
        }
    }
}

# Additional module management functions
function Import-ProfileModules {
    Write-Host "Re-importing profile modules..." -ForegroundColor Yellow
    foreach ($module in $script:modules) {
        if (Get-Module -ListAvailable -Name $module) {
            try {
                Import-Module -Name $module -Force
                Write-Host "Imported: $module" -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to import $module`: $($_.Exception.Message)"
                # Try alternative import for WinGet module
                if ($module -eq 'Microsoft.WinGet.CommandNotFound') {
                    try {
                        Import-Module -Name $module -Force -SkipEditionCheck
                        Write-Host "Imported: $module (with SkipEditionCheck)" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "$module failed to import - may have dependency issues" -ForegroundColor Red
                    }
                }
            }
        }
        else {
            Write-Host "$module not available" -ForegroundColor Yellow
        }
    }
}

# Function to check background job results (call manually when needed)
function Get-BackgroundUpdates {
    $jobs = Get-Job -Name "UpdateCheck", "ProfileMaintenance", "ZoxideInstall" -ErrorAction SilentlyContinue
    
    foreach ($job in $jobs) {
        if ($job.State -eq 'Completed') {
            $result = Receive-Job $job
            
            switch ($job.Name) {
                "UpdateCheck" {
                    if ($result -contains "Profile update available") {
                        Write-Host "Profile updates are available. Run Update-Profile to apply." -ForegroundColor Yellow
                    }
                    if ($result -contains "PowerShell update available") {
                        Write-Host "PowerShell updates are available. Consider updating PowerShell." -ForegroundColor Yellow
                    }
                }
                "ProfileMaintenance" {
                    if ($result -and $result.Count -gt 0) {
                        Write-Host "Newly installed modules: $($result -join ', ')" -ForegroundColor Green
                    }
                }
                "ZoxideInstall" {
                    if ($result) {
                        Write-Host "Zoxide installed successfully. Restart PowerShell to use it." -ForegroundColor Green
                    }
                }
            }
            Remove-Job $job -Force
        }
        elseif ($job.State -eq 'Failed') {
            Remove-Job $job -Force
        }
    }
}


# Help Function
function Show-Help {
    @"
PowerShell Profile Help
=======================

Update-Profile - Reloads the current PowerShell profile.

Get-BackgroundUpdates - Check status of background jobs (module installs, updates).

Edit-Profile - Opens the current user's profile for editing using the configured editor.

touch <file> - Creates a new empty file.

ff <name> - Finds files recursively with the specified name.

Get-PubIP - Retrieves the public IP address of the machine.

winutil - Runs the WinUtil script from Chris Titus Tech.

uptime - Displays the system uptime.

reload-profile - Reloads the current user's PowerShell profile.

unzip <file> - Extracts a zip file to the current directory.

hb <file> - Uploads the specified file's content to a hastebin-like service and returns the URL.

grep <regex> [dir] - Searches for a regex pattern in files within the specified directory or from the pipeline input.

df - Displays information about volumes.

sed <file> <find> <replace> - Replaces text in a file.

which <name> - Shows the path of the command.

export <name> <value> - Sets an environment variable.

pkill <name> - Kills processes by name.

pgrep <name> - Lists processes by name.

head <path> [n] - Displays the first n lines of a file (default 10).

tail <path> [n] - Displays the last n lines of a file (default 10).

nf <name> - Creates a new file with the specified name.

mkcd <dir> - Creates and changes to a new directory.

docs - Changes the current directory to the user's Documents folder.

dtop - Changes the current directory to the user's Desktop folder.

ep - Opens the profile for editing.

k9 <name> - Kills a process by name.

la - Lists all files in the current directory with detailed formatting.

ll - Lists all files, including hidden, in the current directory with detailed formatting.

gs - Shortcut for 'git status'.

ga - Shortcut for 'git add .'.

gc <message> - Shortcut for 'git commit -m'.

gp - Shortcut for 'git push'.

g - Changes to the GitHub directory.

gcom <message> - Adds all changes and commits with the specified message.

lazyg <message> - Adds all changes, commits with the specified message, and pushes to the remote repository.

sysinfo - Displays detailed system information.

flushdns - Clears the DNS cache.

cpy <text> - Copies the specified text to the clipboard.

pst - Retrieves text from the clipboard.

Clear-PSHistory  - Clear PowerShell History (It will search the .txt history file and delete it)

Use 'Show-Help' to display this help message.
"@
}

# Profile loaded - use 'Show-Help', 'Import-ProfileModules', or 'Initialize-AllTools' as needed

Write-Host "Profile loaded - use '" -NoNewline
Write-Host "Show-Help" -ForegroundColor Cyan -NoNewline
Write-Host "', '" -NoNewline
Write-Host "Import-ProfileModules" -ForegroundColor Magenta -NoNewline
Write-Host "', or '" -NoNewline
Write-Host "Get-BackgroundUpdates" -ForegroundColor Green -NoNewline
Write-Host "' as needed"
