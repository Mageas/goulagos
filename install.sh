#!/usr/bin/env bash

#
# Script by mageas (https://gitlab.com/Mageas)
#

CURRENT_DIRECTORY="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTS_DIRECTORY="${CURRENT_DIRECTORY}/scripts"
[ -f "${CURRENT_DIRECTORY}/config" ] && source "${CURRENT_DIRECTORY}/config"
[ "${INSTALL_DIRECTORY}" = "" ] && INSTALL_DIRECTORY="${HOME}/.goulagos"
[ "${LOGS_FILE}" = "" ] && LOGS_FILE="${INSTALL_DIRECTORY}/logs"
[ "${DOTFILES}" = "" ] && DOTFILES="https://gitea.heartnerds.org/Mageas/dotfiles"
[ "${DOTFILES_DIRECTORY}" = "" ] && DOTFILES_DIRECTORY="${HOME}/.dots"
[ "${SYSFILES}" = "" ] && SYSFILES="https://gitea.heartnerds.org/Mageas/sysfiles"
[ "${SYSFILES_DIRECTORY}" = "" ] && SYSFILES_DIRECTORY="/opt/sysfiles"
[ "${SUCKLESS_BASE_LINK}" = "" ] && SUCKLESS_BASE_LINK="https://gitea.heartnerds.org/Mageas"
HOSTNAME=$(hostnamectl --static)


function EXPECT() {
    set -e
    expect 2>/dev/null <<END_EXPECT
        spawn ${@}
        expect {
            "doas \(${USER}@${HOSTNAME}\) password:" {send -- "${USER_PASSWORD}\r"}
            "\[sudo\] password for ${USER}:" {send -- "${USER_PASSWORD}\r"}
        }
        expect eof
        catch wait result
        exit [lindex \$result 3]
END_EXPECT
}


function LOG_TO_FILE() {
    echo "${1}" >> ${LOGS_FILE}
}

function LOG() {
    echo -e "\033[35m\033[1m[LOG] ${1}\033[0m\n"
    LOG_TO_FILE "[LOG] ${1}"
}

function ERROR() {
    LOG_TO_FILE "[ERROR] ${1}"
    echo -e "\033[0;31m\033[1m[ERROR] ${1}\033[0m\n"
    exit 1
}


function check_privileges() {
    if [ "$(id -u)" = 0 ]; then
        echo "####################################"
        echo "This script MUST NOT be run as root!"
        echo "####################################"
        exit 1
    fi

    doas echo ""
    [[ ${?} -eq 1 ]] && ERROR "[check_privileges]: Your root password is wrong"

    read -p "Please retype your password: " -s USER_PASSWORD
    EXPECT doas echo "" || ERROR "[check_privileges]: Your root password is wrong"
}


function script_config() {
    [[ -d ${INSTALL_DIRECTORY} ]] && ERROR "[init_directory]: Install directory already exist"
    mkdir -p ${INSTALL_DIRECTORY} || ERROR "[init_directory]: Unable to create the install direcroty"
    rm -rf ${LOGS_FILE}

    git config --global user.email "example@mail.com"
    git config --global user.name "example"

    doas sed -i '/^#\ParallelDownloads =/{N;s/#//g}' /etc/pacman.conf \
        || LOG "[init_directory]: Unable to activate the parallel downloads"
}


function install_pacman_packages() {
    doas pacman -Sy --noconfirm archlinux-keyring \
        || ERROR "[update_and_install_dependencies]: Unable to update archlinux keyring"

    doas pacman -Syu --noconfirm \
        || ERROR "[update_and_install_dependencies]: Unable to update the system"
        
    for _package in "${PACMAN_PACKAGES[@]}"; do
        doas pacman -S --needed --noconfirm ${_package} \
            || LOG "[install_pacman_packages]: Unable to install ${_package}"
    done
}

function remove_sudo() {
    doas pacman -Rns --noconfirm sudo \
        || LOG "[remove_sudo]: Unable to uninstall sudo"
    doas ln -sf /bin/doas /bin/sudo
}


function install_aur_packages() {
    rustup install stable || ERROR "[install_aur_packages]: Unable to configure rustup"
    rustup default stable || ERROR "[install_aur_packages]: Unable to configure rustup"

    if [ ! -x "$(command -v paru)" ]; then
        git clone https://aur.archlinux.org/paru.git "${INSTALL_DIRECTORY}/paru" \
            && cd "${INSTALL_DIRECTORY}/paru" && makepkg -si --noconfirm --needed \
            || ERROR "[install_aur_packages]: Unable to install paru"
    fi

    for _package in "${AUR_PACKAGES[@]}"; do
        paru -S --noconfirm --noprovides --skipreview ${_package} \
            || LOG "[install_aur_packages]: Unable to install ${_package}"
    done
}


function install_flatpak_packages() {
    for _flatpak in "${FLATPAK_PACKAGES[@]}"; do
        local _name=$(echo ${_flatpak} | awk '{print $1}')
        local _path=$(echo ${_flatpak} | awk '{print $2}')
        local _bin=$(echo ${_flatpak} | awk '{print $3}')

        flatpak install -y ${_name} \
            || LOG "[install_flatpak_packages]: Unable to install ${_name}"

        [ -z "${_path}" ] || [ -z "${_bin}" ] && continue
        doas ln -sf ${_path} ${_bin} \
            || LOG "[install_flatpak_packages]: Unable to link ${_name} from (${_path}) to (${_bin})"
    done
}


function install_dotfiles () {
    git clone ${DOTFILES} ${DOTFILES_DIRECTORY} \
        && cd "${DOTFILES_DIRECTORY}" \
        && stow -R */ \
        || ERROR "[install_dotfiles]: Unable to install sysfiles"

    doas git clone ${SYSFILES} ${SYSFILES_DIRECTORY} \
        && cd "${SYSFILES_DIRECTORY}" \
        || ERROR "[install_dotfiles]: Unable to install root dotfiles"

    for directory in $( ls -p | grep / ); do
        CONFLICTS=$(stow --no --verbose ${directory} 2>&1 | awk '/\* existing target is/ {print $NF}')
        for f in ${CONFLICTS[@]}; do
            [[ -f "/${f}" || -L "/${f}" ]] && doas rm "/${f}"
        done
    done
    doas stow -R */ \
        || ERROR "[install_dotfiles]: Unable to install sysfiles"
}


function install_suckless () {
    for _suckless in "${SUCKLESS[@]}"; do
        git clone --recurse-submodules "${SUCKLESS_BASE_LINK}/${_suckless}" "${INSTALL_DIRECTORY}/${_suckless}" \
            && cd "${INSTALL_DIRECTORY}/${_suckless}/${_suckless}" && EXPECT suckupdate \
            || ERROR "[install_suckless]: Unable to install ${_suckless}"
    done
}


function config_fstab(){
    for _disk in "${DISKS_TO_MOUNT[@]}"; do
        local _uuid=$(echo ${_disk} | awk '{print $1}')
        [[ -n $(grep ${_uuid} "/etc/fstab") ]] && echo " >> Skipping ${_uuid}" || echo "${_disk}" | doas tee -a /etc/fstab
    done
}


function custom_scripts() {
    for _script in "${CUSTOM_SCRIPTS[@]}"; do
        source "${SCRIPTS_DIRECTORY}/${_script}"
    done
}


inc=1
function status () {
    for i in $(seq 1 $((${#1}+14))); do echo -n "#"; done; echo
    echo "## ($(printf "%02d" ${inc})/$(printf "%02d" ${number_of_steps})) ${1} ##"; inc=$((${inc}+1))
    for i in $(seq 1 $((${#1}+14))); do echo -n "#"; done; echo
}


number_of_steps=10


status "Checking script privileges"
check_privileges

status "Configuring the script directory"
script_config

status "Installing community packages"
install_pacman_packages

status "Removing sudo"
remove_sudo

status "Installing aur packages"
install_aur_packages

status "Installing flatpak packages"
install_flatpak_packages

status "Installing dotfiles"
install_dotfiles

status "Installing suckless softwares"
install_suckless

status "Configuring fstab"
config_fstab

status "Custom scripts"
custom_scripts
