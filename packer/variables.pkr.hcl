
variable "pc_username" {
  type      = string
  sensitive = true
}

variable "pc_password" {
  type      = string
  sensitive = true
}

variable "pc_ip" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "subnet_name" {
  type = string
}

variable "source_image_name" {
  type    = string
  default = ""
}

variable "source_image_uri" {
  type    = string
  default = ""
}

variable "source_image_path" {
  type    = string
  default = ""
}

variable "image_name" {
  type = string
}

variable "vm_name" {
  type    = string
  default = "ndb-packer-vm"
}

variable "vm_cpu" {
  type    = number
  default = 2
}

variable "vm_memory_mb" {
  type    = number
  default = 4096
}

variable "vm_disk_size_gb" {
  type    = number
  default = 40
}

variable "ndb_version" {
  type = string
}

variable "db_type" {
  type = string
}

variable "db_version" {
  type = string
}

variable "os_type" {
  type = string
}

variable "os_version" {
  type = string
}

variable "patroni_version" {
  type = string
}

variable "etcd_version" {
  type = string
}

variable "ssh_public_key" {
  type    = string
  default = ""
}

variable "nutanix_insecure" {
  type    = bool
  default = true
}

variable "ansible_site_playbook" {
  type    = string
  default = ""
}

variable "ansible_config_path" {
  type    = string
  default = ""
}

variable "ansible_roles_path_env" {
  type    = string
  default = ""
}

variable "ansible_extra_vars_file" {
  type    = string
  default = "ansible/vars.json"
}
