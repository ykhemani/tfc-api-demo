variable aws_region {
  type        = string
  description = "AWS region in which to provision."
  default     = "us-west-2"
}

variable instance_type {
  type        = string
  description = "type of EC2 instance to provision."
  default     = "t2.micro"
}

variable name {
  type        = string
  description = "Value for Name tag for aws_instance."
  default     = "tfe-aws-demo"
}

variable owner {
  type        = string
  description = "Value for Owner tag for resources provisioned."
  default     = "ykhemani"
}

variable ttl {
  type        = string
  description = "Value for TTL tag for resources provisioned."
  default     = "1"
}

