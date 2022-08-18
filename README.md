# GoulagOs

GoulagOs is my own archlinux distribution.

### **Description**

Installing:
- `config` file and `scripts` folder 
- [dotfiles](https://gitlab.com/Mageas/dotfiles)
- [sysfiles](https://gitlab.com/Mageas/sysfiles)

### **Requirements**

All the `suck` scripts from my [sysfiles](https://gitlab.com/Mageas/sysfiles)

### **Warning**

**!! Use the install.sh script at your own risks, it might break your distribution !!**

| variable                  | default value                                  | description                  |
| ------------------------- | ---------------------------------------------- | ---------------------------- |
| `INSTALL_DIRECTORY`       | `${HOME}/.goulagos`                            | install directory path       |
| `LOGS_FILE`               | `${INSTALL_DIRECTORY}/logs`                    | log file path                |
| `DOTFILES`                | `https://gitea.heartnerds.org/Mageas/dotfiles` | dotfiles link                |
| `DOTFILES_DIRECTORY`      | `${HOME}/.dots`                                | dotfiles directory path      |
| `SYSFILES`                | `https://gitea.heartnerds.org/Mageas/sysfiles` | sysfiles link                |
| `SYSFILES_DIRECTORY`      | `/opt/sysfiles`                                | sysfiles directory path      |
| `SUCKLESS_BASE_LINK`      | `https://gitea.heartnerds.org/Mageas`          | base link for suckless       |

### **The softwares I use**

All the packages I use are located in `config` and `scripts`.
