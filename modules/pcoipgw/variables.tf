variable "name" {}

variable "vpc_id" {}

#example "10.0.0.0/16"
variable "vpc_cidr" {}

# remote_ip_cidr is the ip address of the remote host / user intending to connect over vpn. eg '197.125.62.53/32'
#example "125.254.24.255/32"
variable "remote_ip_cidr" {}

variable "vpn_cidr" {}

# examples ["subnet-0a7554f56af4d6d0a", "subnet-0257c7f8b1d68b6e4"]
variable "public_subnet_ids" {
  default = []
}

variable "key_name" {}

#contents of the my_key.pem file to connect to the instance.
variable "private_key" {}

#this ami id is for southeast-ap-2 sydney only.  todo - changes will need to be made to pull a list of ami's
# variable "ami" {
#   default = "ami-0b292fed58bac1726"
# }

#options for gateway type are centos7 and pcoip
variable "gateway_type" {
  default = "pcoip"
}

#CentOS Linux 7 x86_64 HVM EBS ENA 1805_01-b7ee8a69-ee97-4a49-9e68-afaee216db2e-ami-77ec9308.4 (ami-d8c21dba)
variable "ami_map" {
  type = "map"

  default = {
    pcoip   = "ami-0b292fed58bac1726"
    centos7 = "ami-d8c21dba"
  }
}

variable "instance_type_map" {
  type = "map"

  default = {
    pcoip   = "g3.4xlarge"
    centos7 = "t2.micro"
  }
}

variable "instance_type" {
  default = "g3.4xlarge"
}

variable "user" {
  default = "centos"
}

variable "sleep" {
  default = false
}

variable "skip_update" {
  default = false
}

variable "pcoip_sleep_after_creation" {
  default = false
}
