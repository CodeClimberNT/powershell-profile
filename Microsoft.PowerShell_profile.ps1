#region Initial Setup
# Telemetry opt-out, only if PowerShell is run as admin
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

#region Script Variables
$script:ToolCache = @{}
$script:ModuleCache = @{}
$script:ConfigurationComplete = $false
$script:PendingJobs = @()

#region Core Functions
function Test-CommandExists {
    param([string]$command)
    if ($script:ToolCache.ContainsKey($command)) {
        return $script:ToolCache[$command]
    }
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    $script:ToolCache[$command] = $exists
    return $exists
}

function Start-AsyncOperation {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Name
    )
    $job = Start-Job -Name $Name -ScriptBlock $ScriptBlock
    $script:PendingJobs += @{
        Job  = $job
        Name = $Name
    }
}


function Initialize-PSCompletions {
    try {
        # Check if already configured
        if ($script:ModuleCache['PSCompletionsConfigured']) {
            return $true
        }

        # Force module import first
        Import-Module -Name PSCompletions -Force -ErrorAction Stop
        Start-Sleep -Seconds 3  # Increase wait time for module to fully load

        # Verify module is properly loaded
        if (-not (Get-Module -Name PSCompletions)) {
            Write-Warning "PSCompletions module failed to load"
            return $false
        }

        # Verify psc command exists
        if (-not (Get-Command 'psc' -ErrorAction SilentlyContinue)) {
            Write-Warning "psc command not available after module import"
            return $false
        }

        Write-Verbose "Configuring PSCompletions..."
        # Use direct command execution without script block
        Invoke-Expression "psc add arch basenc cargo choco date dd df du docker env factor fnm git head pip powershell python pdm scoop sfsu winget wt wsl"
        Start-Sleep -Seconds 1
        Invoke-Expression "psc menu config enable_menu 0"
        
        $script:ModuleCache['PSCompletionsConfigured'] = $true
        return $true
    }
    catch {
        Write-Warning "PSCompletions configuration failed: $_"
        return $false
    }
}

function Import-RequiredModules {
    $modules = @(
        @{
            Name          = 'Terminal-Icons'
            InstallParams = @{
                Name               = 'Terminal-Icons'
                Force              = $true
                SkipPublisherCheck = $true
            }
        },
        @{
            Name          = 'PSCompletions'
            InstallParams = @{
                Name               = 'PSCompletions'
                Force              = $true
                SkipPublisherCheck = $true
                Scope              = 'CurrentUser'
            }
        },
        @{
            Name          = 'Microsoft.WinGet.CommandNotFound'
            InstallParams = @{
                Name               = 'Microsoft.WinGet.CommandNotFound'
                Force              = $true
                SkipPublisherCheck = $true
            }
        }
    )
    
    foreach ($module in $modules) {
        try {
            # Install if needed
            if (-not (Get-Module -ListAvailable -Name $module.Name)) {
                Write-Verbose "Installing module: $($module.Name)"
                $params = $module.InstallParams
                Install-Module @params
                Start-Sleep -Seconds 2
            }

            # Import module
            Import-Module -Name $module.Name -Force -ErrorAction Stop
            $script:ModuleCache[$module.Name] = $true
            Write-Verbose "Module $($module.Name) imported successfully"

            # Handle PSCompletions setup
            if ($module.Name -eq 'PSCompletions') {
                Start-Sleep -Seconds 2
                $retryCount = 1
                $success = $false
                
                for ($i = 1; $i -le $retryCount -and -not $success; $i++) {
                    Write-Verbose "Attempting to initialize PSCompletions (Attempt $i of $retryCount)"
                    $success = Initialize-PSCompletions
                    if (-not $success) {
                        Start-Sleep -Seconds 2
                    }
                }
            }
        }
        catch {
            Write-Warning "Failed to process module $($module.Name): $_"
        }
    }
}



#region Shell Enhancements
function Initialize-ShellEnhancements {
    $tools = @(
        @{Name = 'starship'; Init = { Invoke-Expression (&starship init powershell) } },
        @{Name = 'zoxide'; Init = { 
                if (Test-CommandExists 'zoxide') {
                    Invoke-Expression (& { (zoxide init powershell | Out-String) })
                    # Add proper null checks and error handling for zoxide aliases
                    $zoxide_z = Get-Command __zoxide_z -ErrorAction SilentlyContinue
                    $zoxide_zi = Get-Command __zoxide_zi -ErrorAction SilentlyContinue
                    
                    if ($zoxide_z) {
                        New-Alias -Name 'z' -Value $zoxide_z.Name -ErrorAction SilentlyContinue -Force
                    }
                    if ($zoxide_zi) {
                        New-Alias -Name 'zi' -Value $zoxide_zi.Name -ErrorAction SilentlyContinue -Force
                    }
                }
            }
        },
        @{Name = 'fnm'; Init = { 
                if (Test-CommandExists 'fnm') {
                    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression 
                }
            }
        }
    )

    foreach ($tool in $tools) {
        if (-not [string]::IsNullOrWhiteSpace($tool.Name) -and (Test-CommandExists $tool.Name)) {
            try {
                & $tool.Init
            }
            catch {
                Write-Warning "Failed to initialize $($tool.Name): $_"
            }
        }
    }
}

#region Initialization Flow
Import-RequiredModules

Start-AsyncOperation -Name "ConnectivityCheck" -ScriptBlock {
    Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1
}

Start-AsyncOperation -Name "UpdateCheck" -ScriptBlock {
    try {
        $url = "https://raw.githubusercontent.com/CodeClimberNT/powershell-profile/refs/heads/main/Microsoft.PowerShell_profile.ps1"
        $oldhash = Get-FileHash $PROFILE
        $newContent = Invoke-RestMethod $url
        $tempFile = [System.IO.Path]::GetTempFileName()
        $newContent | Set-Content $tempFile
        $newhash = Get-FileHash $tempFile
        Remove-Item $tempFile
        if ($newhash.Hash -ne $oldhash.Hash) {
            return "Profile update available"
        }
    }
    catch {}
    
    try {
        $currentVersion = $PSVersionTable.PSVersion.ToString()
        $latestVersion = (Invoke-RestMethod "https://api.github.com/repos/PowerShell/PowerShell/releases/latest").tag_name.Trim('v')
        if ($currentVersion -lt $latestVersion) {
            return "PowerShell update available"
        }
    }
    catch {}
}


# Initialize shell enhancements immediately for available tools
Initialize-ShellEnhancements


#region Configuration
# Admin Check and Prompt Customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

# Shell Configuration
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

# Editor Configuration
$EDITOR = if (Test-CommandExists code) { 'code' }
elseif (Test-CommandExists nvim) { 'nvim' }
elseif (Test-CommandExists notepad++) { 'notepad++' }
elseif (Test-CommandExists sublime_text) { 'sublime_text' }
else { 'notepad' }

if (-not [string]::IsNullOrWhiteSpace($EDITOR)) {
    Set-Alias -Name vim -Value $EDITOR -ErrorAction SilentlyContinue
}


#region Tool Installation and Updates
function Install-RequiredTools {
    param([bool]$hasInternet)
    if (-not $hasInternet) { return }

    $toolsToInstall = @(
        @{Name = 'zoxide'; WinGetId = 'ajeetdsouza.zoxide' },
        @{Name = 'fzf'; WinGetId = 'junegunn.fzf' },
        @{Name = 'starship'; WinGetId = 'Starship.Starship' }
    )

    foreach ($tool in $toolsToInstall) {
        if (-not (Test-CommandExists $tool.Name)) {
            Write-Host "Installing $($tool.Name)..."
            winget install --silent --exact --id $tool.WinGetId --accept-source-agreements
        }
    }
}

if (Get-Command sfsu -ErrorAction SilentlyContinue) {
    Invoke-Expression (&sfsu hook)
}


#region Aliases
$FETCH = if (Test-CommandExists fastfetch) { 'fastfetch' }
if (-not [string]::IsNullOrWhiteSpace($FETCH)) {
    Set-Alias -Name neofetch -Value $FETCH -ErrorAction SilentlyContinue
}

#region Utility Functions
# Profile Management
function Edit-Profile { vim $PROFILE }
function Update-Profile { & $PROFILE }

function touch($file) { "" | Out-File $file -Encoding ASCII }
function ff($name) {
    Get-ChildItem -Recurse -Filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.directory)\$($_)"
    }
}



# Set UNIX-like aliases for the admin command, so sudo <command> will run the command with elevated rights.
Set-Alias -Name su -Value admin

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
function uptime {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        Get-WmiObject win32_operatingsystem | Select-Object @{Name = 'LastBootUpTime'; Expression = { $_.ConverttoDateTime($_.lastbootuptime) } } | Format-Table -HideTableHeaders
    }
    else {
        net statistics workstation | Select-String "since" | ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
    }
}

# Quick Access to System Information
function sysinfo { Get-ComputerInfo }


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
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Warning "Cannot export environment variable: Name is null or empty"
        return
    }
    Set-Item -Force -Path "env:$name" -Value $value
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

# Network Utilities
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

function flushdns {
    Clear-DnsClientCache
    Write-Host "DNS has been flushed"
}

# Open WinUtil
function winutil {
    Invoke-WebRequest -useb https://christitus.com/win | Invoke-Expression
    
}

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

# Clipboard Utilities
function cpy { Set-Clipboard $args[0] }

function pst { Get-Clipboard }

# Compute file hashes - useful for checking successful downloads 
function md5 { Get-FileHash -Algorithm MD5 $args }
function sha1 { Get-FileHash -Algorithm SHA1 $args }
function sha256 { Get-FileHash -Algorithm SHA256 $args }


#region Final Setup
# Display status messages
if ($newlyInstalledModules.Count -gt 0) {
    Write-Host "Newly installed modules: $($newlyInstalledModules -join ', ')" -ForegroundColor Green
}

# Display update notifications
foreach ($update in $updateResults) {
    Write-Host $update -ForegroundColor Yellow
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


#region Final Setup
function Initialize-Profile {
    $script:PendingJobs | ForEach-Object {
        $result = Receive-Job -Job $_.Job -Wait
        Remove-Job $_.Job
        
        switch ($_.Name) {
            "ConnectivityCheck" {
                if ($result) {
                    Install-RequiredTools -hasInternet $true
                    Import-RequiredModules  # Re-import after installations
                }
            }
            "UpdateCheck" {
                if ($result) {
                    Write-Host $result -ForegroundColor Yellow
                }
            }
        }
    }
    
    $script:ConfigurationComplete = $true
    Write-Host "Profile initialization complete. Use 'Show-Help' for available commands." -ForegroundColor Green
}

# Start initialization
Start-Job -Name "ProfileInit" -ScriptBlock ${function:Initialize-Profile} | Out-Null



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