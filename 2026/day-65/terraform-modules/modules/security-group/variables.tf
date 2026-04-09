# vpc_id (string)
# sg_name (string)
# ingress_ports (list of numbers, default: [22, 80])
# tags (map of strings, default: {})


variable "vpc_id" {
  description = "add vpc id"
  type        = string
}

variable "sg_name" {
  description = "added security group name"
  type        = string
}

variable "ingress_ports" {
  description = "added ingress ports"
  type        = list(string)
  default     = [22, 80]
}

variable "tags" {
  description = "Tags for SG"
  type        = map(string)
  default     = {}
}


