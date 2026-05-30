# APX - ArchLinux Penetration-Testing eXtended

APX is a minimal, performance-focused Arch Linux distribution tailored for penetration testing, offensive security workflows, and advanced research environments.

Built on top of Arch Linux with automation-first principles, APX aims to provide a reproducible, lightweight, and customizable security workstation optimized for virtualized environments.

![APX Wallpaper](APX-Playbook/files/wallpaper.png)

---

## Features

* Minimal and clean XFCE desktop environment
* Lightweight design optimized for long working sessions
* Arch Linux rolling-release base
* BlackArch repository integration
* Automated image builds using Packer
* Infrastructure-as-Code provisioning with Ansible
* Virtual machine optimized (QEMU/KVM)
* Modern Unix commands and tools
* Offensive security and research focused tooling
* Reproducible builds and deployment pipeline

---

## Project Goals

APX is designed to provide:

* A stable penetration testing environment
* Fast deployment inside virtual machines
* Reproducible infrastructure and configurations
* Minimal resource consumption
* Long-term maintainability
* Flexible customization for researchers and red teams

Unlike traditional penetration testing distributions, APX focuses on simplicity, automation, and transparency rather than shipping thousands of preinstalled tools by default.

---

## Tech Stack

| Component             | Technology      |
| --------------------- | --------------- |
| Base Distribution     | Arch Linux      |
| Desktop Environment   | XFCE            |
| Build Automation      | Packer          |
| Provisioning          | Ansible         |
| Virtualization        | QEMU/KVM        |
| Filesystem            | EXT4            |
| Bootloader            | GRUB            |
| Repository Extensions | BlackArch + AUR |

---

## Build Pipeline

The APX build process is fully automated:

![APX Pipeline](APX-Build-Diagram.jpeg)

---

## Current Status

APX is currently under active development.

Development To-Do list:

* Support for (VMWare - VBox)
* Support build on (Fedora , Arch)
* Cleanup process (Remove packer user and create an already identified user)

---

## Requirements

Recommended host environment:

* Linux host system
* QEMU/KVM support
* Hardware virtualization enabled
* Minimum 4 CPU cores
* Minimum 8 GB RAM
* At least 40 GB free disk space

---

## Building APX

```bash
git clone https://github.com/r0ttenbeef/APX-Linux.git

cd APX-Linux

sudo ./Initiate_APX_Build.sh -u <Current_Host_User> -v kvm -s 25
```

---

## Disclaimer

APX is intended for:

* authorized penetration testing
* security research
* malware analysis
* educational purposes
* lab environments

Users are responsible for complying with local laws and regulations.

---

## License

MIT License
