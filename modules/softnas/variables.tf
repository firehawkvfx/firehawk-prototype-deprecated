variable "key_name" {}
variable "private_key" {}

variable "vpn_private_ip" {}

variable "vpc_id" {}

variable "private_subnets" {
  default = []
}

variable "all_private_subnets_cidr_range" {}

variable "private_subnets_cidr_blocks" {
  default = []
}

variable "public_subnets_cidr_blocks" {
  default = []
}



variable "public_domain" {}

variable "volumes" {
  default = []
}

variable "mounts" {
  default = []
}

variable "sleep" {
  default = false
}

variable "s3_disk_size" {}

variable "bastion_private_ip" {}

variable "bastion_ip" {}

variable "skip_update" {
  default = false
}

# variable "softnas_export_path" {
#   default = "/naspool2/nasvol2"
# }

variable "vpn_cidr" {}
variable "remote_subnet_cidr" {}

variable "remote_ip_cidr" {}

# variable "softnas_user_password" {}

variable "softnas_role_name" {
  default = "SoftNAS_HA_IAM"
}

variable "cloudformation_stack_name" {}
variable "cloudformation_role_stack_name" {}

variable "softnas1_private_ip1" {}

variable "softnas1_private_ip2" {}

variable "softnas2_private_ip1" {}

variable "softnas2_private_ip2" {}

# variable "softnas1_export_path" {}

# variable "softnas2_export_path" {}

variable "softnas1_volumes" {
  default = []
}

variable "softnas2_volumes" {
  default = []
}

variable "softnas1_mounts" {
  default = []
}

variable "softnas2_mounts" {
  default = []
}
