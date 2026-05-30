#!/usr/bin/env bash

set -eux

sudo pacman -S --noconfirm openvpn wpa_supplicant iw wireless_tools networkmanager network-manager-applet git bash-completion tmux pkgstats ttf-bitstream-vera adobe-source-sans-pro-fonts ttf-droid ttf-anonymous-pro inetutils openbsd-netcat nmap gvfs-mtp lightdm-gtk-greeter-settings xdg-user-dirs light-locker gnome-keyring ffmpegthumbnailer firefox zip unzip unrar ntfs-3g viewnior evince mpv

sudo systemctl enable lightdm NetworkManager
