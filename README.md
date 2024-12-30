# Powershell-Profile
The profile was initially forked from [this](https://github.com/ChrisTitusTech/powershell-profile) repository
Remember to read what you are installing in your system! What could work for me may break other system if you don't know what you're doing!

# Module used
  - [Terminal-Icons](https://github.com/devblackops/Terminal-Icons)
  - [Chocolatey](https://chocolatey.org/)
  - [oh-my-posh](https://ohmyposh.dev/) / [starship](https://starship.rs/) (default)
  - [fnm](https://github.com/Schniz/fnm)
  - [zoxide](https://github.com/ajeetdsouza/zoxide) (need [fzf](https://github.com/junegunn/fzf) installed for advanced features)
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
