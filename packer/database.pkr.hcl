packer {
  required_plugins {
    nutanix = {
      version = "~> 1.0.0"
      source  = "github.com/nutanix-cloud-native/nutanix"
    }
    ansible = {
      version = ">= 1.0.0"
      source = "github.com/hashicorp/ansible"
    }
  }
}

source "nutanix" "ndb" {
  nutanix_username    = var.pc_username
  nutanix_password    = var.pc_password
  nutanix_endpoint    = var.pc_ip
  nutanix_insecure    = var.nutanix_insecure
  cluster_name        = var.cluster_name
  os_type             = "Linux"

  vm_name             = "ndb-packer-vm"
  cpu                 = 2
  memory_mb           = 4096
  boot_type           = "uefi"
  boot_wait           = "5m"

  vm_disks {
    image_type        = "DISK_IMAGE"
    source_image_uri  = var.source_image_uri
    disk_size_gb      = 40
  }

  vm_nics {
    subnet_name = var.subnet_name
  }

  image_name          = var.image_name
  image_description   = "NDB ${var.ndb_version} ${var.db_type} ${var.db_version} on ${var.os_type} ${var.os_version}"
  ssh_username        = "packer"
  ssh_private_key_file = "packer/id_rsa"
  user_data           = base64encode(templatefile("http/user-data", { ssh_public_key = var.ssh_public_key }))
}

build {
  sources = ["source.nutanix.ndb"]

  provisioner "ansible" {
    playbook_file = var.ansible_site_playbook
    ansible_env_vars = [ var.ansible_config_path ]
    extra_arguments = [
      "-e",
      "@ansible/vars.json"
    ]
  }
}