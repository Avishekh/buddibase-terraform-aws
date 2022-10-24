resource "null_resource" "setup" {
  provisioner "local-exec" {
    command = "sed -i '' '/${var.IPADDRESS}/d'  ~/.ssh/known_hosts"
  }
}

/* resource "null_resource" "public_key" {
  provisioner "local-exec" {
    command = "ssh-keygen -f budibase -N '' <<< y"
  }
} */

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.34"
    }
  }
}
resource "aws_key_pair" "ssh-key" {
  key_name   = var.KEYNAME
  public_key = file("${var.KEYNAME}.pub")
}
provider "aws" {
  region = var.REGION

}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
  request_headers = {
    Accept = "application/text"
  }
}

resource "aws_vpc" "budibase-vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  tags = {
    Name = "budibase"
  }
}

resource "aws_subnet" "budibase-subnet" {
  vpc_id                  = aws_vpc.budibase-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = var.AZ
  tags = {
    Name = "budibase"
  }
}

resource "aws_internet_gateway" "budibase-igw" {
  vpc_id = aws_vpc.budibase-vpc.id
  tags = {
    Name = "budibase"
  }
}

resource "aws_route_table" "budibase-crt" {
  vpc_id = aws_vpc.budibase-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.budibase-igw.id
  }
  tags = {
    Name = "budibase"
  }
}

resource "aws_route_table_association" "budibase-crta-subnet" {
  subnet_id      = aws_subnet.budibase-subnet.id
  route_table_id = aws_route_table.budibase-crt.id
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.budibase.id
  allocation_id = var.ELASTICIPALLOC
}

resource "aws_security_group" "budibase-sg" {
  name        = "budibase-sg"
  description = "Security group created for budibase on EC2"
  vpc_id      = aws_vpc.budibase-vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 10000
    to_port     = 10000
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "budibase"
  }

}

resource "aws_instance" "budibase" {
  ami                    = var.AMI
  availability_zone      = var.AZ
  subnet_id              = aws_subnet.budibase-subnet.id
  vpc_security_group_ids = [aws_security_group.budibase-sg.id]
  instance_type          = var.INSTANCE_TYPE
  user_data              = file("install_budibase.sh")
  key_name               = aws_key_pair.ssh-key.key_name
  tags = {
    Name = "budibase-app"
  }
  provisioner "file" {
    content     = templatefile(".env.tpl", { jwtsecret = var.JWTSECRET,environment=var.ENV})
    destination = "/home/ec2-user/.env"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("budibase")
      host        = self.public_dns
    }
  }
  provisioner "file" {
    source      = "docker-compose.yaml"
    destination = "/home/ec2-user/docker-compose.yaml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("budibase")
      host        = self.public_dns
    }
  }

}

output "ssh" {
  description = "SSH to the IP Address"
  value       = "ssh -i ./budibase ec2-user@${var.IPADDRESS} -o StrictHostKeyChecking=no"
}