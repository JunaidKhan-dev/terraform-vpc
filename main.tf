terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = "eu-west-1"
  access_key = "XXX"
  secret_key = "XXXXX"
}

# 1. create vpc
resource "aws_vpc" "vpc-web" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "vpc-web"
  }
}

# 2. create Internet Gateway
resource "aws_internet_gateway" "vpc-web-gw" {
  vpc_id = aws_vpc.vpc-web.id

  tags = {
    Name = "vpc-web-gw"
  }
}


# 3. create Custom Route Table
resource "aws_route_table" "vpc-web-route-table" {
  vpc_id = aws_vpc.vpc-web.id
  # allow all traffic 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc-web-gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.vpc-web-gw.id
  }

  tags = {
    Name = "vpc-web-route-table"
  }
}

# 4. create a subnet
resource "aws_subnet" "vpc-web-subnet-1" {
  vpc_id            = aws_vpc.vpc-web.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
  tags = {
    Name = "vpc-web-subnet-1"
  }
}

# 5. Associate subnet with Route Table
resource "aws_route_table_association" "vpc-web-associate-route-table" {
  subnet_id      = aws_subnet.vpc-web-subnet-1.id
  route_table_id = aws_route_table.vpc-web-route-table.id
}

# 6. create Security Group to allow port 22,80,443
resource "aws_security_group" "vpc-web-allow_web-traffic-sg" {
  name        = "vpc-web-allow_web-traffic"
  description = "Allow Web traffic"
  vpc_id      = aws_vpc.vpc-web.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpc-web-allow_web-traffic-sg"
  }
}

# 7. create a network interface with ip in the subnet that was created in step 4
resource "aws_network_interface" "vpc-web-network-interface" {
  subnet_id       = aws_subnet.vpc-web-subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.vpc-web-allow_web-traffic-sg.id]
  tags = {
    Name = "vpc-web-network-interface"
  }
}

# 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "vpc-web-EIP" {
  vpc                       = true
  network_interface         = aws_network_interface.vpc-web-network-interface.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.vpc-web-gw]
  tags = {
    Name = "vpc-web-EIP"
  }
}

# 9. create Ubuntu server and install/enable apache2
resource "aws_instance" "vpc-web-server-apache" {
  ami               = "ami-0dc8d444ee2a42d8a"
  instance_type     = "t2.micro"
  availability_zone = "eu-west-1a"
  key_name          = "vpc-key"
  network_interface {
    # first network interface associate with this instance
    device_index         = 0
    network_interface_id = aws_network_interface.vpc-web-network-interface.id

  }
  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install apache2 -y
    sudo systemctl start apache2
    sudo bash -c 'echo your very first web server > /var/www/html/index.html'
  EOF

  tags = {
    Name = "vpc-web-server-apache"
  }
}

