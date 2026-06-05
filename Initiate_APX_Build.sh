#!/bin/bash
Red='\033[0;31m'
Green='\033[0;32m'
Yellow='\033[0;33m'
Blue='\033[0;34m'
off='\033[0m'

err="[${Red}-${off}]"
warn="[${Yellow}!${off}]"
prog="[${Blue}*${off}]"
done="[${Green}+${off}]"

version="1.0"
author="r0ttenbeef"

print_ok(){
    echo -e "$done $1"
}

print_warn(){
    echo -e "$warn $1"
}

print_prog(){
    echo -e "$prog $1"
}

print_err(){
    echo -e "$err $1"
}

CheckRoot(){
    if [ "$EUID" -ne 0 ]; then 
        print_err "Cannot use the script without root access."
        exit 1
    fi
}

InternetConnection() {
    if ping -c 1 8.8.8.8 &>/dev/null; then
        return 0 # true
    else
        return 1 # false
    fi
}

PackageManager() {
    if command -v apt-get &>/dev/null; then
        echo "debian"
    elif command -v dnf &>/dev/null; then
        echo "fedora"
    elif command -v pacman &>/dev/null; then
        echo "arch"
    else
        echo "none"
    fi
}

InstallKVMPackages() {
    local pm
    pm=$(PackageManager)

    if [ "$pm" == "debian" ]; then
        packages=( "qemu-system" "qemu-utils" "qemu-kvm" "libvirt-daemon-system" "virt-manager" "libxml2-dev" "bridge-utils" "ansible" "cloud-image-utils" "cpu-checker" )
        
        apt-get update &>/dev/null
        print_prog "Installing required KVM packages - Checks if packages are already installed"
        for pkg in "${packages[@]}"; do    
            if ! dpkg -l "$pkg" &>/dev/null; then
                print_prog "Installing $pkg"
                apt-get install -y -qqq "$pkg" &>/dev/null
                if [ $? -ne 0 ]; then print_err "Error while installing packages"; exit 1; fi
            fi
        done

    elif [ "$pm" == "fedora" ]; then
        packages=( "qemu-kvm" "qemu-img" "libvirt" "virt-install" "virt-manager" "libxml2-devel" "ansible" )
        
        print_prog "Installing required KVM packages on Fedora"
        for pkg in "${packages[@]}"; do    
            if ! rpm -q "$pkg" &>/dev/null; then
                print_prog "Installing $pkg"
                dnf install -y "$pkg" &>/dev/null
                if [ $? -ne 0 ]; then print_err "Error while installing packages"; exit 1; fi
            fi
        done

    elif [ "$pm" == "pacman" ]; then
        print_err "Arch Linux not supported yet"
        exit 1
    else
        print_err "Unknown Distro, Not supported"
        exit 1
    fi
}

ConfigureKVM() { 
    if id "$1" &>/dev/null; then
        print_prog "Adding user to KVM groups"
        if ! id -nG "$1" | grep -qw "libvirt"; then
            print_prog "Adding user to libvirt group"
            usermod -aG libvirt "$1"
        fi
        if ! id -nG "$1" | grep -qw "kvm"; then
            print_prog "Adding user to kvm group"
            usermod -aG kvm "$1"
        fi
        print_ok "Enabling and starting libvirtd service"
        systemctl enable --now libvirtd &> /dev/null
        systemctl start libvirtd &>/dev/null
        print_warn "If you faced any issues with permissions related to KVM, please log out and log back in to apply the new group memberships."
    else
        print_err "User provided does not exist."
        exit 1
    fi
}

InstallPacker() {
    local pm
    pm=$(PackageManager)

    if [ "$pm" == "debian" ]; then
        if ! dpkg -l packer &>/dev/null; then
            print_prog "Installing packer"
            curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
            apt-get update &>/dev/null
            apt-get install -y -qqq packer &>/dev/null
        fi
    elif [ "$pm" == "fedora" ]; then
        if ! which packer &>/dev/null; then
            if [ ! $(rpm -q packer &>/dev/null) ]; then
                print_prog "Installing packer"
                dnf install -y dnf-plugins-core &>/dev/null
                dnf config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo &>/dev/null
                dnf -y install packer &>/dev/null
                if [ $? -ne 0 ];then print_err "Error while installing packer on fedora - Please try to install it manually"; exit 1; fi
            fi
        fi
    fi
}

DownloadArch() {
    local download_dir="iso"
    local latest_mirror="https://geo.mirror.pkgbuild.com/iso/latest"
    local iso_file="archlinux-x86_64.iso"

    if [ ! -d "$download_dir" ]; then mkdir -p iso; fi

    if InternetConnection; then
        print_prog "Downloading ArchLinux from nearest mirror"
        if [[ -f "iso/$iso_file" && -f "iso/sha256sums.txt" && -f "iso/$iso_file.sig" ]]; then
            print_prog "ISO file already exists, skipping download"
            return
        fi
        wget -c -q --show-progress "$latest_mirror/$iso_file" "$latest_mirror/sha256sums.txt" "$latest_mirror/$iso_file.sig" -P iso/
        print_prog "Verifying downloaded ISO image"
        cd iso || exit 1
        
        # Fixed the string evaluation for verification output
        if sha256sum -c sha256sums.txt --ignore-missing 2>/dev/null | grep -q "OK" && gpg --auto-key-retrieve --verify "$iso_file.sig" "$iso_file" &>/dev/null; then
            print_ok "SHA256 hash and signature verified"
        else
            print_err "ISO file is corrupted and not verified"
            exit 1
        fi
        cd - >/dev/null || exit 1
    else
        print_err "No internet connection available to download ISO."
        exit 1
    fi 
}

GenerateSSHKey() {
    if [ ! -d ssh_keys ]; then
        print_prog "Generating temporary SSH Keys to be used later"
        mkdir ssh_keys
        ssh-keygen -t ed25519 -C "Temporary SSH key for ansible only" -f ssh_keys/id_ed25519 -N "" &>/dev/null
    fi
}

StartPackerBuild() {
    packer plugins install github.com/hashicorp/ansible

    size_on_archinstall=$((disk_size - 4))
    sed -i "s/\"unit\": \"GiB\", \"value\": .[0-9]*/\"unit\": \"GiB\", \"value\": $size_on_archinstall/g" http/user_configuration.json

    disk_size="${disk_size}000"
    export PKR_VAR_disk_size=$disk_size

    packer init .
    PACKER_LOG_PATH=packer.log packer build apx.pkr.hcl

    if [ $? -eq 0 ]; then
        chown -R "$1":"$current_user" output
        print_ok "Packer build completed successfully"
    else
        print_err "Packer build failed, check packer.log for details"
        exit 1
    fi
}

HelpMenu() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -u, --user <username>          Specify your current host username (Required)
  -v, --hypervisor <hypervisor>  Specify the hypervisor you will use (kvm,vbox,vmware)
  -s, --disk-size <SIZE_GB>      Specify the disk size of the generated image in GB (EX: 10)
  -h, --help                     Display this help menu and exit
EOF
}

CheckRoot

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) HelpMenu; exit 0;;
        -u|--user) if [[ -z "${2:-}" ]]; then print_err "Error: --user requires an argument." >&2; exit 1; fi; current_user="$2"; shift 2;;
        -v|--hypervisor) if [[ -z "${2:-}" ]]; then print_err "Error: --hypervisor requires an argument." >&2; exit 1; fi; hypervisor="$2"; shift 2;;
        -s|--disk-size) if [[ -z "${2:-}" ]]; then print_err "Error: --disk-size requires an argument." >&2; exit 1; fi; disk_size=$2; shift 2;;
        -*) print_err "Error: Unexpected option: $1" >&2; exit 1;;
        *) print_err "Error: Unexpected argument: $1" >&2; exit 1;;
    esac
done

if [[ -z "$current_user" ]] || [[ -z "$hypervisor" ]] || [[ -z "$disk_size" ]]; then
    print_err "Error: Missing required arguments, Please use -h for help." >&2
    exit 1
fi

print_ok "Initiating APX-VM Build"

case $hypervisor in
    kvm) InstallKVMPackages; ConfigureKVM "$current_user";;
    vbox) print_err "VirtualBox not supported yet"; exit 1 ;;
    vmware) print_err "VMware not supported yet"; exit 1 ;;
    *) print_err "Error: Hypervisor not supported yet."; exit 1 ;;
esac

InstallPacker
DownloadArch
GenerateSSHKey
StartPackerBuild "$current_user"
