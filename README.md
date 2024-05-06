# powershell-profile
The profile was initially forked from [this](https://github.com/ChrisTitusTech/powershell-profile) repository
Rember to read what you are installing in your system! What could work for me may break other system if you don't know what you're doing!

# Module used
  - Terminal-Icons
  - zoxide (need fzf installed for advanced features)
  - Chocolatey
  - oh-my-posh / starship (default)

# Installation of Modules
All the modules except `startship` should download automatically if not installed and if a connection to the internet is detected

To download `startship` follow the [Official Documentation](https://starship.rs/installing), tipically the download should be done with a simple command in the terminal

## Attention
Use google and your brain to create your ideal personal space, you can use this profile as it is 
but it is meant to be a start from which you can create you very personal environment that make you feel comfortable when using the terminal.

## Tips
By default the update function for the profile and the powershell are not called automatically as they increase the powershell startup time. This time is very dependent on the machine, my recommendation is to decomment the line below the function definition to make the function autocall and see for yourself if the time it takes to startup a new instance fit your needs or not.
