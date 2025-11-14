packer {
  required_plugins {
    nutanix = {
      version = ">= 1.1.2"
      source  = "github.com/nutanix-cloud-native/nutanix"
    }
  }
}

required_plugins_checksums {
  "github.com/nutanix-cloud-native/nutanix" = [
    "sha256:27a8ddae4531f432e09b88528003b50bf03a4c805393a888e8562b9a19da694f"
  ]
}
