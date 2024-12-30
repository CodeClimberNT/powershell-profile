# Powershell-Profile
The profile was initially forked from [this](https://github.com/ChrisTitusTech/powershell-profile) repository
Remember to read what you are installing in your system! What could work for me may break other system if you don't know what you're doing!

# Module used
  - [Terminal-Icons](https://github.com/devblackops/Terminal-Icons)
  - [zoxide](https://github.com/ajeetdsouza/zoxide) (need [fzf](https://github.com/junegunn/fzf) installed for advanced features)
  - [Chocolatey](https://chocolatey.org/)
  - [oh-my-posh](https://ohmyposh.dev/) / [starship](https://starship.rs/) (default)
  - [fnm](https://github.com/Schniz/fnm)

# Installation of Modules
By default I hope the profile works even without any module installed. 

The current behavior is to download any missing module (except for `startship`) to have the best possible experience

> [!NOTE]
> To download `startship` follow the [Official Documentation](https://starship.rs/installing), tipically the download should be done with a simple command in the terminal

> [!WARNING]
> Use google and your brain to create your ideal personal space, you can use this profile as it is 
> but it is meant to be a start from which you can create you very personal environment that make you feel comfortable when using the terminal.

> [!TIP]
By default the update function for the powershell is not called automatically as this may increase the powershell startup time. This time is very dependent on the machine, my recommendation is to uncomment the line below the function definition `update-profile` to make the function automatically call at startup and see for yourself if the time it takes to startup a new instance fit your needs or not.
