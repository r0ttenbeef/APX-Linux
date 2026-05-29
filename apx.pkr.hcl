packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.9"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "disk_size" {
  type    = number 
  default = 10000
}

source "qemu" "apx" {

  iso_url      = "iso/archlinux-x86_64.iso"
  iso_checksum = "none"
  vm_name = "APX-VM"
  output_directory = "output"
  format = "qcow2"
  accelerator = "kvm"
  
  disk_size = var.disk_size
  memory = 4096
  cpus   = 4

  headless = true
  net_device     = "virtio-net"
  disk_interface = "virtio"
  boot_wait = "3s"
  http_directory = "./http"
  
  communicator = "ssh"
  ssh_username = "packer"
  ssh_password = "packer"
  ssh_timeout = "120m"

  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"

  qemuargs = [
    ["-cpu", "host"],
    ["-smp", "4"],
    ["-machine", "type=q35,accel=kvm"],
    ["-boot", "strict=on,order=cdn"],
  ]

  boot_command = [
    "<enter>",
    "<wait35>",
    "curl -O http://{{ .HTTPIP }}:{{ .HTTPPort }}/user_configuration.json -O http://{{ .HTTPIP }}:{{ .HTTPPort }}/user_credentials.json<enter>",
    "pacman -Sy --noconfirm archinstall;archinstall --offline --config user_configuration.json --creds user_credentials.json --silent && echo 'PasswordAuthentication yes' >> /mnt/etc/ssh/sshd_config && echo 'packer ALL=(ALL) NOPASSWD: ALL' > /mnt/etc/sudoers.d/00_packer && sleep 5 && reboot<enter>",
  ]
}

build {

  sources = ["source.qemu.apx"]

  provisioner "file" {
    source = "ssh_keys/id_ed25519.pub"
    destination = "/tmp/id_ed25519.pub"
  }

  provisioner "shell" {
    inline = [
      "if [ ! -d ~/.ssh ];then mkdir ~/.ssh;fi",
      "cat /tmp/id_ed25519.pub >> ~/.ssh/authorized_keys",
      "chmod 700 ~/.ssh",
      "chmod 600 ~/.ssh/authorized_keys"
    ]
  }

  provisioner "shell" {
    script = "scripts/bootstrap.sh"
  }

  provisioner "ansible" {
    playbook_file = "start.yml"
    user = "packer"
    use_proxy = false

    ansible_env_vars = [
      "ANSIBLE_PRIVATE_KEY_FILE=ssh_keys/id_ed25519"
    ]

    extra_arguments = [
      "--extra-vars", "ansible_host=${build.Host} ansible_port=${build.Port} ansible_password=packer ansible_become_password=packer"
    ]
  }
}
