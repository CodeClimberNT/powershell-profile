#opt-out of telemetry before doing anything, only if PowerShell is run as admin
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}


# Initial connectivity check job
$connectivityJob = Start-Job -ScriptBlock {
    Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1
}

# Module installation job
$moduleInstallJob = Start-Job -ScriptBlock {
    $modules = @(
        'Terminal-Icons',
        'PSCompletions',
        'Microsoft.WinGet.CommandNotFound'
    )
    
    $newlyInstalled = @()
    
    foreach ($module in $modules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Install-Module -Name $module -Scope CurrentUser -Force -SkipPublisherCheck
            $newlyInstalled += $module
        }
        # Import module regardless of whether it was just installed
        Import-Module -Name $module -Force
    }

    # Special handling for PSCompletions if newly installed
    if ($newlyInstalled -contains 'PSCompletions') {
        # Run first-time setup commands
        Add-Completions
        Invoke-Expression "psc menu config enable_menu 0"
    }

    # Return the list of newly installed modules
    $newlyInstalled
}

# Updates check job
$updateCheckJob = Start-Job -ScriptBlock {
    # Profile update check
    $url = "https://raw.githubusercontent.com/CodeClimberNT/powershell-profile/refs/heads/main/Microsoft.PowerShell_profile.ps1"
    try {
        $oldhash = Get-FileHash $PROFILE
        Invoke-RestMethod $url -OutFile "$env:temp/Microsoft.PowerShell_profile.ps1"
        $newhash = Get-FileHash "$env:temp/Microsoft.PowerShell_profile.ps1"
        if ($newhash.Hash -ne $oldhash.Hash) {
            Write-Output "Profile update available"
        }
    } catch { }
    
    # PowerShell update check
    try {
        $currentVersion = $PSVersionTable.PSVersion.ToString()
        $latestVersion = (Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest").tag_name.Trim('v')
        if ($currentVersion -lt $latestVersion) {
            Write-Output "PowerShell update available"
        }
    } catch { }
}

# Wait for critical jobs
$canConnectToGitHub = Receive-Job -Job $connectivityJob -Wait
Remove-Job $connectivityJob


# Admin Check and Prompt Customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()


# Utility Functions
function Test-CommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

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
Set-Alias -Name neofetch -Value $FETCH


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
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

# Open WinUtil
function winutil {
    Invoke-WebRequest -useb https://christitus.com/win | Invoke-Expression
    
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

if (Test-CommandExists sfsu) {
    Invoke-Expression (&sfsu hook)
}

Set-PSReadLineOption @PSROptions
Set-PSReadLineKeyHandler -Chord 'Ctrl+f' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Enter' -Function ValidateAndAcceptLine


if (Test-CommandExists starship) {
    Invoke-Expression (&starship init powershell)
}
elseif (Test-CommandExists oh-my-posh) {
    oh-my-posh init pwsh --config "https://raw.githubusercontent.com/CodeClimberNT/oh-my-posh/main/powerlevel10k_rainbow.omp.json" | Invoke-Expression
}
else {
    Write-Host "Neither starship nor oh-my-posh is installed. Consider installing one for a better prompt experience." -ForegroundColor Yellow
}

# import modules after starship or oh-my-posh to avoid visual bugs

# Import Modules and External Profiles
# Ensure Terminal-Icons module is installed before importing
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module -Name Terminal-Icons
}

if (Get-Module -ListAvailable -Name Microsoft.WinGet.CommandNotFound) {
    Import-Module -Name Microsoft.WinGet.CommandNotFound
}

# Install pscx module if not already installed - https://github.com/Pscx/Pscx
# if (Get-Module -ListAvailable -Name Pscx) {
#     Import-Module -Name Pscx
# }
# elseif (-not (Get-Module -ListAvailable -Name Pscx) -and $canConnectToGitHub ) {
#     Install-Module -Name Pscx -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber
#     Import-Module -Name Pscx
# }

function Add-Completions {
    Invoke-Expression("psc add arch basenc cargo choco date dd df du docker env factor fnm git head pip powershell python pdm scoop sfsu winget wt wsl")
}       

function Update-Psc {
    Invoke-Expression("psc update *")
}
# To update the psc modules at every session uncomment the line below
# update-psc

function Update-Pyenv {
    if (-not (Test-Path env:PYENV_HOME)) {
        Write-Error "PYENV_HOME environment variable is not set"
        return
    }
    Invoke-Expression(& { "${env:PYENV_HOME}\install-pyenv-win.ps1" })
}
# To update the pyenv at every session uncomment the line below
# Update-Pyenv

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

#region Command Line Tools Initialization
# Initialize fnm silently if it exists
if (Test-CommandExists fnm) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}


# if zoxide not installed try to install it
if (Test-CommandExists zoxide) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
else {
    Write-Host "zoxide command not found. Attempting to install via winget..."
    try {
        winget install -e --id ajeetdsouza.zoxide
        Write-Host "zoxide installed successfully. Initializing..."
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    }
    catch {
        Write-Error "Failed to install zoxide. Error: $_"
    }
}

if (Test-CommandExists zoxide) {
    Set-Alias -Name z -Value __zoxide_z -Option AllScope -Scope Global -Force
    Set-Alias -Name zi -Value __zoxide_zi -Option AllScope -Scope Global -Force
}
else {
    Write-Host "zoxide not found. Please install it manually."
}

function Set-PscDefaults {
    $pscCommands = @(
        "psc menu config enable_menu 0"
    )
    
    foreach ($command in $pscCommands) {
        Invoke-Expression $command
    }
}


if (Get-Module -ListAvailable -Name PSCompletions) {
    Import-Module -Name PSCompletions
}


Wait-Job $moduleInstallJob, $updateCheckJob | Out-Null
$newlyInstalledModules = Receive-Job $moduleInstallJob
$updateResults = Receive-Job $updateCheckJob
Remove-Job $moduleInstallJob, $updateCheckJob

# Report newly installed modules
if ($newlyInstalledModules.Count -gt 0) {
    Write-Host "Newly installed modules: $($newlyInstalledModules -join ', ')" -ForegroundColor Green
}

if ($updateResults -contains "Profile update available") {
    Write-Host "Profile updates are available. Run Update-Profile to apply." -ForegroundColor Yellow
}
if ($updateResults -contains "PowerShell update available") {
    Write-Host "PowerShell updates are available. Run Update-PowerShell to upgrade." -ForegroundColor Yellow
}

# Help Function
function Show-Help {
    @"
PowerShell Profile Help
=======================

Update-Profile - Checks for profile updates from a remote repository and updates if necessary.

Update-PowerShell - Checks for the latest PowerShell release and updates if a new version is available.

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

Update-Pyenv - Update pyenv installation

Clear-PSHistory  - Clear PowerShell History (It will search the .txt history file and delete it)

Use 'Show-Help' to display this help message.
"@
}
Write-Host "Use 'Show-Help' to display help"
