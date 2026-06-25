terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}

provider "proxmox" {
  pm_api_url          = "https://192.168.1.201:8006/api2/json"
  pm_api_token_id     = "terraform@pve!tf-token"
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}


resource "proxmox_lxc" "web" {
  hostname    = "vault-ct"
  vmid        = 1002
  target_node = "proxmox"

  ostemplate = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

  password     = var.ct_password
  unprivileged = true

  cores  = 1
  memory = 256

  rootfs {
    storage = "NVME"
    size    = "10G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr1"
    ip     = "192.168.2.2/24"
    gw     = "192.168.2.1"
  }

  features {
    nesting = true
  }

  ssh_public_keys = var.ssh_key

  onboot = true
  start  = true

}
