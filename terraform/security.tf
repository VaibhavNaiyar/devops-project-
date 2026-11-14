# Least-exposure security groups:
#   internet -> ALB:80 -> app:8080 (only from the ALB)
#   my IP -> Jenkins:8080/22, GitHub webhook ranges -> Jenkins:8080
#   Jenkins -> app:22 (Ansible deploys), my IP -> app:22 (initial configuration)
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

data "http" "github_meta" {
  url             = "https://api.github.com/meta"
  request_headers = { Accept = "application/json" }
}

locals {
  my_cidr          = "${chomp(data.http.my_ip.response_body)}/32"
  github_hook_ipv4 = [for c in jsondecode(data.http.github_meta.response_body).hooks : c if !strcontains(c, ":")]
}

resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "Public HTTP to the load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project}-alb-sg" }
}

resource "aws_security_group" "jenkins" {
  name        = "${var.project}-jenkins-sg"
  description = "Jenkins UI for the admin, webhooks from GitHub"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Jenkins UI from admin IP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }
  ingress {
    description = "GitHub webhooks"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = local.github_hook_ipv4
  }
  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project}-jenkins-sg" }
}

resource "aws_security_group" "app" {
  name        = "${var.project}-app-sg"
  description = "App servers: traffic only from the ALB, SSH only from Jenkins/admin"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App port from the ALB only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    description     = "SSH from Jenkins (Ansible rolling deploys)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins.id]
  }
  ingress {
    description = "SSH from admin IP (initial configuration)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project}-app-sg" }
}
