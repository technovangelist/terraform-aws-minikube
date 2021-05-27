terraform {
  required_version = "~> 0.15"

  required_providers {
    sshcommand = {
      source  = "invidian/sshcommand"
      version = "0.2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.34"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}


locals {
  bootstrap_file_name = "${path.module}/bootstrap.sh"
  context_name        = "aws-minikube-${var.env_name}"
  kubernetes_config = {
    host                   = yamldecode(sshcommand_command.get_kubeconfig.result).clusters[0].cluster.server
    cluster_ca_certificate = base64decode(yamldecode(sshcommand_command.get_kubeconfig.result).clusters[0].cluster.certificate-authority-data)
    client_certificate     = base64decode(yamldecode(sshcommand_command.get_kubeconfig.result).users[0].user.client-certificate-data)
    client_key             = base64decode(yamldecode(sshcommand_command.get_kubeconfig.result).users[0].user.client-key-data)
  }
  wait_for_cluster = <<EOT
      timeout=500
      i=0
      while :;do
        [ $timeout -gt 0 ] || exit 1
        sudo kubectl get pod && exit 0
        i=$((i+1))
        sleep 10
        timeout=$((timeout-10))
      done
      exit 1
EOT
}

data "aws_ami" "ubuntu_20_04" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = "${var.env_name}-k8s-minikube"
  public_key = tls_private_key.this.public_key_openssh
}

data "aws_availability_zones" "available" {
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 3.0"

  name        = "${var.env_name}-k8s-minikube"
  description = "K8s Kind Cluster"
  vpc_id      = aws_vpc.minikube-vpc.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp", "all-icmp", "all-tcp"]
  egress_rules        = ["all-all"]
}

module "node" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.0"

  name             = "${var.env_name}-k8s-minikube"
  user_data_base64 = base64encode(file(local.bootstrap_file_name))
  ami              = data.aws_ami.ubuntu_20_04.id
  instance_type    = var.instance_type
  key_name         = aws_key_pair.this.key_name
  subnet_id        = aws_subnet.minikube-subnet.id

  vpc_security_group_ids = [module.security_group.this_security_group_id]

  root_block_device = [{
    volume_size = var.instance_disk_size
    volume_type = "gp2"
  }]

  tags = {
    "kubernetes.io/cluster/${var.env_name}-k8s-minikube" = "shared"
    "KubernetesCluster"                                  = "${var.env_name}-k8s-minikube"
  }

}

resource "null_resource" "wait_for_cluster" {
  provisioner "remote-exec" {
    inline = [local.wait_for_cluster]

  }
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.this.private_key_pem
    host        = module.node.public_dns[0]
  }
}

resource "sshcommand_command" "get_kubeconfig" {
  host        = module.node.public_dns[0]
  user        = "ubuntu"
  command     = "sudo kubectl config view --minify --flatten | sed -e 's|server: https://.*:|server: https://${module.node.public_dns[0]}:|' "
  private_key = tls_private_key.this.private_key_pem

  depends_on = [null_resource.wait_for_cluster]
}

