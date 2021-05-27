variable "env_name" {
  description = "String used as a prefix for AWS resources"
  type        = string
  default     = "workshop"
}

variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "t3a.medium"
}

variable "instance_disk_size" {
  description = "Instance disk size (in GB)"
  type        = number
  default     = 50
}
