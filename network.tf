data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
  request_headers = {
    Accept = "application/text"
  }
}

resource "aws_vpc" "minikube-vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  tags = {
    Name  = "minikube"
    Owner = "workshop"
  }
}

resource "aws_subnet" "minikube-subnet" {
  vpc_id                  = aws_vpc.minikube-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "us-west-2b"
  tags = {
    Name  = "minikube"
    Owner = "workshop"
  }
}

resource "aws_internet_gateway" "minikube-igw" {
  vpc_id = aws_vpc.minikube-vpc.id
  tags = {
    Name  = "minikube"
    Owner = "workshop"
  }
}

resource "aws_route_table" "minikube-crt" {
  vpc_id = aws_vpc.minikube-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.minikube-igw.id
  }
  tags = {
    Name  = "minikube"
    Owner = "workshop"
  }
}

resource "aws_route_table_association" "minikube-crta-subnet" {
  subnet_id      = aws_subnet.minikube-subnet.id
  route_table_id = aws_route_table.minikube-crt.id
}

resource "aws_security_group" "minikube-sg" {
  name        = "minikube-sg"
  description = "Security group created for minikube on EC2"
  vpc_id      = aws_vpc.minikube-vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.minikube-subnet.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name  = "minikube"
    Owner = workshop
  }

}
