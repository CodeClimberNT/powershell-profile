# PowerShell Profile Initialization Script
# This script installs all required modules and tools

Write-Host "Initializing PowerShell Profile..." -ForegroundColor Cyan

# Required PowerShell Modules
$modules = @(
    'Terminal-Icons',
    'Microsoft.WinGet.CommandNotFound'
)

# Required External Tools (installed via winget)
$tools = @(
    @{ Id = 'ajeetdsouza.zoxide'; Name = 'zoxide' },
    @{ Id = 'Schniz.fnm'; Name = 'fnm (Fast Node Manager)' },
    @{ Id = 'sharkdp.fd'; Name = 'fd (fast find alternative)' },
    @{ Id = 'Starship.Starship'; Name = 'starship (prompt)' }
)

# Optional tools that enhance the experience
$optionalTools = @(
    @{ Id = 'Neovim.Neovim'; Name = 'Neovim' },
    @{ Id = 'sharkdp.bat'; Name = 'bat (better cat)' },
    @{ Id = 'BurntSushi.ripgrep.MSVC'; Name = 'ripgrep (fast grep)' },
    @{ Id = 'fastfetch-cli.fastfetch'; Name = 'fastfetch' }
)

Write-Host "`nInstalling PowerShell modules..." -ForegroundColor Yellow

foreach ($module in $modules) {
    Write-Host "Installing $module..." -NoNewline
    try {
        Install-Module -Name $module -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction Stop
        Write-Host " ✓" -ForegroundColor Green
    }
    catch {
        Write-Host " ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nInstalling essential tools via winget..." -ForegroundColor Yellow

foreach ($tool in $tools) {
    Write-Host "Installing $($tool.Name)..." -NoNewline
    try {
        winget install -e --id $tool.Id --silent --accept-package-agreements --accept-source-agreements
        Write-Host " ✓" -ForegroundColor Green
    }
    catch {
        Write-Host " ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nInstalling optional tools (you can skip these by pressing Ctrl+C)..." -ForegroundColor Yellow

foreach ($tool in $optionalTools) {
    Write-Host "Installing $($tool.Name)..." -NoNewline
    try {
        winget install -e --id $tool.Id --silent --accept-package-agreements --accept-source-agreements
        Write-Host " ✓" -ForegroundColor Green
    }
    catch {
        Write-Host " ✗ Failed or already installed" -ForegroundColor Yellow
    }
}

Write-Host "`n✅ Installation complete!" -ForegroundColor Green
Write-Host "Please restart your PowerShell session to use the new profile features." -ForegroundColor Cyan
Write-Host "After restart, use 'Show-Help' to see available commands." -ForegroundColor Cyan
