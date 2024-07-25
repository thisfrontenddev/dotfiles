# My dotfiles

All of the configuration files that I use when doing a setup on a new Macbook. Scripts included should make it easy to setup a new Mac from scratch and more importantly, without too much overhead (ideally, only one entrypoint script should do all of the usually hands-on work for me).

Based on [Dotfiles: Best way to store in a bare git repository](https://www.atlassian.com/git/tutorials/dotfiles) from Atlassian's blog.

## Getting started

How to clone the repo :
```bash
git clone --bare git@github.com:thisfrontenddev/dotfiles.git $HOME/.cfg

# Define the alias in the current shell scope:
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# Checkout the actual content from the bare repository to your $HOME:
config checkout

# The step above might fail with a message like:

# error: The following untracked working tree files would be overwritten by checkout:
#    .bashrc
#    .gitignore
# Please move or remove them before you can switch branches.
# Aborting

# This is because your $HOME folder might already have some stock configuration
# files which would be overwritten by Git. The solution is simple: back up the files
# if you care about them, remove them if you don't care. I provide you with a possible
# rough shortcut to move all the offending files automatically to a backup folder:

mkdir -p .config-backup && \
config checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | \
xargs -I{} mv {} .config-backup/{}

# Re-run the check out if you had problems:
config checkout

# Set the flag showUntrackedFiles to no on this specific (local) repository:
config config --local status.showUntrackedFiles no
```

Executing the setup script :
```bash
./setup.sh
```

If the setup script is not working because of permissions, a simple `chmod` change will do the trick :
```bash
chmod ug+x ./setup.sh
```

## Good to know

- Some of the changes will need a full reboot to take effect.
- A few of the programs installed will need MacOS permissions, most notably **Accessibility**
- `yabai`, the window manager I use, will need some extra setup steps for all of it's features to work. Most of them will do, but it's worth remembering.

## Todos

- [ ] Create a simple script that'll automate the getting started steps
- [ ] Find `defaults` for MacOS that'll help me customize some deeply nested/protected settings such as Accessibility without breaking the OS's stability
- [ ] Some of those `defaults` will also need system events being sent in order to make them effective without rebooting
- [ ] Make a checklist of steps to decommission a computer before wiping the hard drive.
