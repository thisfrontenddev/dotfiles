# My dotfiles

All of the configuration files that I use when doing a setup on a new Macbook. Scripts included should make it easy to setup a new Mac from scratch and more importantly, without too much overhead (ideally, only one entrypoint script should do all of the usually hands-on work for me).

Based on [Dotfiles: Best way to store in a bare git repository](https://www.atlassian.com/git/tutorials/dotfiles) from Atlassian's blog.

## Getting started

How to clone the repo :
```bash
git clone --bare <git-repo-url> $HOME/.cfg
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

- [ ] Find `defaults` for MacOS that'll help me customize some deeply nested/protected settings such as Accessibility without breaking the OS's stability
- [ ] Some of those `defaults` will also need system events being sent in order to make them effective without rebooting
- [ ] Make a checklist of steps to decommission a computer before wiping the hard drive.
