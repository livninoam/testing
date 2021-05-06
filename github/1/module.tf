
# VARIABLES


variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_name" {}
variable "region" {
  default = "us-east-1"
}
variable "network_address_space" {
  default = "10.1.0.0/16"
}
variable "subnet1_address_space" {
  default = "10.1.0.0/24"
}
variable "subnet2_address_space" {
  default = "10.1.1.0/24"
}
variable "bucket_name_prefix" {}
variable "billing_code_tag" {}
variable "environment_tag" {}


# PROVIDERS


provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}


# LOCALS


locals {
  common_tags = {
    BillingCode = var.billing_code_tag
    Environment = var.environment_tag
  }

  s3_bucket_name = "${var.bucket_name_prefix}-${var.environment_tag}-${random_integer.rand.result}"
}

# DATA


data "aws_availability_zones" "available" {}

data "aws_ami" "aws-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}






# NETWORKING #
resource "aws_vpc" "vpc" {
  cidr_block = var.network_address_space

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-igw" })

}

resource "aws_subnet" "subnet1" {
  cidr_block              = var.subnet1_address_space
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-subnet1" })

}

resource "aws_subnet" "subnet2" {
  cidr_block              = var.subnet2_address_space
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-subnet2" })

}

# ROUTING #
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-rtb" })

}

resource "aws_route_table_association" "rta-subnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rtb.id
}

resource "aws_route_table_association" "rta-subnet2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rtb.id
}

# SECURITY GROUPS #
resource "aws_security_group" "elb-sg" {
  name   = "ubuntu_elb_sg"
  vpc_id = aws_vpc.vpc.id

  #Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-elb" })

}

# ubuntu security group 
resource "aws_security_group" "ubuntu-sg" {
  name   = "ubuntu_sg"
  vpc_id = aws_vpc.vpc.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.network_address_space]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-ubuntu" })

}

# LOAD BALANCER #
resource "aws_elb" "web" {
  name = "ubuntu-elb"

  subnets         = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  security_groups = [aws_security_group.elb-sg.id]
  instances       = [aws_instance.ubuntu1.id,aws_instance.ubuntu2.id,aws_instance.ubuntu3.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-elb" })

}

# INSTANCES #
resource "aws_instance" "ubuntu" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.ubuntu-sg.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ubuntu_profile.name

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_path)

  }



  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install ansible -y"
      "sudo yum install awscli -y"
      "sudo yum install kubectl -y"
      
    ]
  }

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-ubuntu1" })

}

resource "aws_instance" "ubuntu2" {
  ami                    = data.aws_ami.Ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet2.id
  vpc_security_group_ids = [aws_security_group.ubuntu-sg.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ubuntu_profile.name

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_path)

  }

 


}
EOF
    destination = "/home/ec2-user/ubuntu"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install ansible -y"
      "sudo yum install awscli -y"
      "sudo yum install kubectl -y"
      
    ]
  }

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-ubuntu2" })

resource "aws_instance" "ubuntu3" {
  ami                    = data.aws_ami.Ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet2.id
  vpc_security_group_ids = [aws_security_group.ubuntu-sg.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ubuntu_profile.name

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_path)

  }

 


}
EOF
    destination = "/home/ec2-user/ubuntu"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install ansible -y"
      "sudo yum install awscli -y"
      "sudo yum install kubectl -y"
      
    ]
  }

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-ubuntu3" })
}

# S3 Bucket config#
resource "aws_iam_role" "allow_s3" {
  name = "allow_s3"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": "PublicRead"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ubuntu_profile" {
  name = "ubuntu_profile"
  role = aws_iam_role.allow_s3.name
}

resource "aws_iam_role_policy" "allow_s3_all" {
  name = "allow_s3_all"
  role = aws_iam_role.allow_ubuntu_s3.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
                "arn:aws:s3:::${local.s3_bucket_name}",
                "arn:aws:s3:::${local.s3_bucket_name}/*"
            ]
    }
  ]
}


