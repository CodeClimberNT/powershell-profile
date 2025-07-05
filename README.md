# PowerShell Profile

## Features

- **Zoxide integration** - Fast directory navigation
- **UNIX-like aliases** - Familiar commands for cross-platform users
- **Essential utilities** - File operations, git shortcuts, system info

## Quick Installation

1. **Run the initialization script** (installs all dependencies):
   ```powershell
   .\Initialize-PowerShellProfile.ps1
   ```

2. **Restart PowerShell** to load the new profile

3. **Use `Show-Help`** to see available commands

## Manual Installation

If you prefer to install dependencies manually:

### Required PowerShell Modules
```powershell
Install-Module -Name Terminal-Icons -Scope CurrentUser -Force
Install-Module -Name Microsoft.WinGet.CommandNotFound -Scope CurrentUser -Force
```

### Required Tools (via winget)
```powershell
# Essential tools
winget install ajeetdsouza.zoxide        # Fast directory navigation
winget install Schniz.fnm               # Node.js version manager
winget install sharkdp.fd               # Fast find alternative
winget install Starship.Starship        # Fast, cross-platform prompt

# Optional but recommended
winget install Neovim.Neovim            # Text editor
winget install sharkdp.bat              # Better cat
winget install BurntSushi.ripgrep.MSVC  # Fast grep
winget install fastfetch-cli.fastfetch  # System info
```

## Dependencies

### PowerShell Modules
- `Terminal-Icons` - File icons in terminal
- `Microsoft.WinGet.CommandNotFound` - Command suggestions

### External Tools
- `zoxide` - Smart directory navigation
- `fnm` - Fast Node.js manager
- `fd` - Fast file finder
- `starship` - Fast, cross-platform prompt
- `nvim` - Text editor (assumed primary)
- `sfsu` - Shell completion utility

### Assumed Available
The profile assumes these tools are installed and available in PATH:
- Git
- Neovim (nvim)
- fastfetch
- sfsu (shell completion)
- starship (prompt)
  - [starship](https://github.com/starship/starship)

# Installation of Modules
By default I hope the profile works even without any module installed. 

The current behavior is to download any missing module to have the best possible experience.
This includes both powershell modules and system application using winget

> [!WARNING]
> Use google and your brain to create your ideal personal space, you can use this profile as it is 
> but it is meant to be a start from which you can create you very personal environment that make you feel comfortable when using the terminal.

> [!TIP]
> By default the update function for the powershell is not called automatically as this may increase the powershell startup time. This time is very dependent on the machine, my recommendation is to uncomment the line below the function definition `update-profile` to make the function automatically call at startup and see for yourself if the time it takes to startup a new instance fit your needs or not.


### Note
This file should be stored in `$PROFILE.CurrentUserAllHosts`

If `$PROFILE.CurrentUserAllHosts` doesn't exist, you can make one with the following:

```powershell
New-Item $PROFILE.CurrentUserAllHosts -ItemType File -Force`
```

This will create the file and the containing subdirectory if it doesn't already 

As a reminder, to enable unsigned script execution of local scripts on client Windows, 
you need to run this line (or similar) from an elevated PowerShell prompt:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
```

This is the default policy on `Windows Server 2012 R2` and above for server Windows. 
For  more information about execution policies, run 

```powershell
Get-Help about_Execution_Policies.
```

## Profile Philosophy

- **No command existence checks** - Tools are assumed available
- **No background jobs** - All operations are synchronous
- **Immediate tool initialization** - No lazy loading

## Available Commands

### File Operations
- `touch <file>` - Create empty file
- `ff <name>` - Find files recursively
- `nf <name>` - Create new file
- `mkcd <dir>` - Create and change directory
- `unzip <file>` - Extract zip file

### System Utilities
- `admin` / `su` - Run as administrator
- `uptime` - System uptime
- `sysinfo` - System information
- `flushdns` - Clear DNS cache
- `Get-PubIP` - Get public IP
- `winutil` - Run WinUtil script

### Git Shortcuts
- `gs` - git status
- `ga` - git add .
- `gc <msg>` - git commit -m
- `gp` - git push
- `gcom <msg>` - add, commit
- `lazyg <msg>` - add, commit, push

### Navigation
- `docs` - Go to Documents
- `dtop` - Go to Desktop
- `g` - Go to GitHub directory (via zoxide)
- `z <dir>` - Smart directory change
- `zi` - Interactive directory picker

### Text Processing
- `grep <pattern> [dir]` - Search in files
- `sed <file> <find> <replace>` - Replace text
- `head <file> [n]` - First n lines
- `tail <file> [n]` - Last n lines

### Clipboard & Hashing
- `cpy <text>` - Copy to clipboard
- `pst` - Paste from clipboard
- `md5 <file>` - MD5 hash
- `sha1 <file>` - SHA1 hash
- `sha256 <file>` - SHA256 hash

### Aliases
- `vim` → `nvim`
- `n` → `notepad`
- `fetch` → `fastfetch`
- `la` - List all files
- `ll` - List hidden files
- `k9 <name>` - Kill process

## Customization

Edit the profile:
```powershell
Edit-Profile
```

## Performance Notes

This profile prioritizes startup speed over error handling. If a tool is missing, you may see errors. This is intentional - install the missing tool rather than having the profile check for its existence on every startup.

## Troubleshooting

If commands don't work:
1. Ensure all dependencies are installed via `Initialize-PowerShellProfile.ps1`
2. Restart PowerShell completely
3. Check that tools are in your PATH
4. Use `Show-Help` to verify profile loaded correctly
