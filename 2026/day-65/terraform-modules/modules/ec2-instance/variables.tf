variable "ami_id" {
  description = "Ami id for ec2"
  type        = string
}

variable "instance_type" {
  description = "instance type for ec2"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "subnet for ec2"
  type        = string
}

variable "security_group_ids" {
  description = "List of security groups"
  type        = list(string)
}

variable "instance_name" {
  description = "add instance name"
  type        = string
}

variable "tags" {
  description = "additinal tags"
  type        = map(string)
  default     = {}
}
