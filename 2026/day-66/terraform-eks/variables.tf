# In variables.tf, define:

# region (string)
# cluster_name (string, default: "terraweek-eks")
# cluster_version (string, default: "1.31")
# node_instance_type (string, default: "t3.medium")
# node_desired_count (number, default: 2)
# vpc_cidr (string, default: "10.0.0.0/16")



variable "region" {
  type = string
}

variable "cluster_name" {
  type    = string
  default = "terraweek-eks"
}

variable "cluster_version" {
  type    = string
  default = "1.31"
}

variable "node_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "node_desired_count" {
  default = 2
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
