#!/bin/bash

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
    echo -e $done $1
}

print_warn(){
    echo -e $warn $1
}

print_prog(){
    echo -e $prog $1
}

print_err(){
    echo -e $err $1
}

CheckRoot(){
    if [ $EUID != 0 ];then print_err "Cannot use the script without root access.";exit 1;fi
}

InternetConnection() {
    if [ $(ping -c 1 8.8.8.8 > /dev/null 2>&1) ]; then
        return true
    else
        return false
    fi
}

PackageManager() {
    if [ $(command -v apt) ];then
        dist="debian"
    elif [ $(command -v pacman) ];then
        dist="arch"
    elif [ $(command -v dnf) ];then
        dist="fedora"
    else
        dist="none"
    fi

    echo $dist
}

InstallKVMPackages() {
    packages=( "qemu-system" "qemu-utils" "qemu-kvm" "libvirt-daemon-system" "virt-manager" "libxml2-dev" "bridge-utils" "ovmf" "ansible" "cloud-image-utils" "cpu-checker" )

    if [ $(PackageManager -eq "debian") ];then
        apt-get update &>/dev/null
        print_prog "Installing required KVM packages - Checks if packages is already installed"
        for pkg in "${packages[@]}";do    
            if ! dpkg -l $pkg &>/dev/null;then
                print_prog "Installing $pkg"
                apt-get install -y -qqq $pkg &>/dev/null
                if [ $? -ne 0 ];then print_err "Error while installing packages"; exit 1;fi
            fi
        done

    elif [ $(PackageManager -eq "pacman") ];then
        print_err "Distro not supported yet"
        exit 1
    elif [ $(PackageManager -eq "dnf") ];then
        print_err "Distro not supported yet"
        exit 1
    else
        print_err "Unknown Distro, Not supported"
    fi
}

ConfigureKVM() { 
    if [ $(cat /etc/passwd | grep $1) ];then
        print_prog "Adding user to KVM groups"
        usermod -aG libvirt,kvm $1
        print_ok "Enabling and starting libvirtd service"
        systemctl enable --now libvirtd &> /dev/null
        systemctl start libvirtd
    else
        print_err "User provided is not exist."
        exit 1
    fi

}

InstallPacker() {
    if [[ $(PackageManager -eq "debian") ]];then
        if ! dpkg -l packer &>/dev/null;then
            print_prog "Installing packer"
            curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
            apt-get update &>/dev/null
            apt-get install -y -qqq packer &>/dev/null
        fi
    fi
}

DownloadArch() {
    download_dir="iso"
    latest_mirror="https://geo.mirror.pkgbuild.com/iso/latest"
    iso_file="archlinux-x86_64.iso"

    if [ ! -d $download_dir ]; then mkdir iso;fi

    if [ InternetConnection ]; then
        print_prog "Downloading ArchLinux from nearst mirror"
        wget -c -q --show-progress "$latest_mirror/$iso_file" "$latest_mirror/sha256sums.txt" "$latest_mirror/$iso_file.sig" -P iso/
        print_prog "Verifying downloaded ISO image"
        cd iso
        if [[ $(sha256sum -c sha256sums.txt --ignore-missing | awk '{ print $2 }') -eq "OK" && $(gpg --auto-key-retrieve --verify $iso_file.sig $iso_file 2>&1 | grep "Good signature") ]]; then
            print_ok "SHA256 hash and signature verified"
        else
            print_err "ISO file is corrupted and not verified"
            exit 1
        fi
        cd - >/dev/null
    fi 
}

GenerateSSHKey() {
    if [ ! -d ssh_keys ]; then
        print_prog "Generating temporary SSH Keys to be used later"
        mkdir ssh_keys
        ssh-keygen -t ed25519 -C "Temporary SSH key for ansible only" -f ssh_keys/id_ed25519 -N ""
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

while [[ $# -gt 0 ]];do
    case "$1" in
        -h|--help) HelpMenu; exit 0;;
        -u|--user) if [[ -z "${2:-}" ]];then print_err "Error: --user require an argument." >&2; exit 1; fi; current_user="$2";shift 2;;
        -v|--hypervisor) if [[ -z "${2:-}" ]];then print_err "Error: --user require an argument." >&2; exit 1; fi; hypervisor="$2";shift 2;;
        -s|--disk-size) if [[ -z "${2:-}" ]];then print_err "Error: --user require an argument." >&2; exit 1; fi; disk_size=$2;shift 2;;
        -*) print_err "Error: Unexpected positional argument: $1" >&2; exit 1;;
        *) print_err "Error: Unexpected argument: $1" >&2; exit 1;;
    esac
done

if [[ -z "$current_user" ]] || [[ -z "$hypervisor" ]] || [[ -z "$disk_size" ]]; then
    print_err "Error: Missing required arguments, Please use -h for help." >&2
    exit 1
fi


print_ok "Initiating APX-VM Build"

case $hypervisor in
    kvm) InstallKVMPackages; ConfigureKVM $current_user;;
    vbox) print_err "Not yet"; exit 1;;
    vmware) print_err "Not yet"; exit 1;;
    *) print_err "Error: Hypervisor not supported yet."; exit 1;;
esac

InstallPacker
DownloadArch
GenerateSSHKey

packer plugins install github.com/hashicorp/ansible

size_on_archinstall=$((disk_size - 2))
sed -i "s/\"unit\": \"GiB\", \"value\": .[0-9]*/\"unit\": \"GiB\", \"value\": $size_on_archinstall/g" http/user_configuration.json

disk_size+=000
export PKR_VAR_disk_size=$disk_size

packer init .
PACKER_LOG_PATH=packer.log packer build -on-error=abort apx.pkr.hcl