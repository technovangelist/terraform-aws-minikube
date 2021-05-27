variable "env_name" {
  description = "String used as a prefix for AWS resources"
  type        = string
  default     = "workshop"
}
variable "region" {
  type    = string
  default = "us-west-2"
}

variable "az" {
  type    = string
  default = "b"
}

variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "t3.medium"
}

variable "instance_disk_size" {
  description = "Instance disk size (in GB)"
  type        = number
  default     = 50
}
