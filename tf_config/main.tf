terraform {
  required_version = ">= 0.12.23"
}

provider aws {
  region = var.aws_region
}

################################################################################
# let's find the latest ubunutu 18.04 image from canonical
data aws_ami ubuntu {
  most_recent = true

  filter {
    name            = "name"
    values          = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name            = "virtualization-type"
    values          = ["hvm"]
  }

  # Canonical
  owners            = ["099720109477"]
}

resource aws_instance ubuntu {
  ami               = data.aws_ami.ubuntu.id
  instance_type     = var.instance_type
  availability_zone = "${var.aws_region}a"

  tags = {
    Name            = var.name
    TTL             = var.ttl
    Owner           = var.owner
  }
}

