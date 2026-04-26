packer {
  required_plugins {
    nutanix = {
      version = "~> 1.0.0"
      source  = "github.com/nutanix-cloud-native/nutanix"
    }
    ansible = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

source "nutanix" "ndb" {
  nutanix_username = var.pc_username
  nutanix_password = var.pc_password
  nutanix_endpoint = var.pc_ip
  nutanix_insecure = var.nutanix_insecure
  cluster_name     = var.cluster_name
  os_type          = "Linux"

  vm_name   = var.vm_name
  cpu       = var.vm_cpu
  memory_mb = var.vm_memory_mb
  boot_type = "uefi"
  boot_wait = "5m"

  vm_disks {
    image_type        = "DISK_IMAGE"
    source_image_name = var.source_image_name != "" ? var.source_image_name : null
    source_image_uri  = var.source_image_uri != "" ? var.source_image_uri : null
    source_image_path = var.source_image_path != "" ? var.source_image_path : null
    disk_size_gb      = var.vm_disk_size_gb
  }

  vm_nics {
    subnet_name = var.subnet_name
  }

  image_name           = var.image_name
  image_description    = "NDB ${var.ndb_version} ${var.db_type} ${var.db_version} on ${var.os_type} ${var.os_version}"
  ssh_username         = "packer"
  ssh_private_key_file = "packer/id_rsa"
  user_data            = base64encode(templatefile("http/user-data", { ssh_public_key = var.ssh_public_key }))
}

build {
  sources = ["source.nutanix.ndb"]

  provisioner "ansible" {
    playbook_file = var.ansible_site_playbook
    ansible_env_vars = compact([
      var.ansible_config_path,
      # build.sh passes ANSIBLE_ROLES_PATH through ansible_roles_path_env when a customization profile is selected.
      var.ansible_roles_path_env,
      "ANSIBLE_HOST_KEY_CHECKING=False"
    ])
    extra_arguments = [
      "-e",
      "@${var.ansible_extra_vars_file}"
    ]
  }
}
