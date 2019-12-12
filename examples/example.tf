provider "aws" {
  region = "us-west-2"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  app_name = "example"
  container_port = 8000
}

module "acs" {
  source = "git@github.com:byu-oit/terraform-aws-acs-info.git?ref=v1.0.2"
  env = "dev"
}

module "simple_fargate" {
  source = "git@github.com:byu-oit/terraform-aws-fargate.git?ref=v1.0.0"
//  source = "../" // used for local testing
  app_name = local.app_name
  container_name = "simple-container"
  container_image = "crccheck/hello-world"
  container_env_variables = {
    TEST_ENV = "foobar"
  }
  container_secrets = {
    TEST_SECRET = "super-secret"
  }

  vpc_id = module.acs.vpc.id
  subnet_ids = module.acs.private_subnet_ids
  load_balancer_sg_id = aws_security_group.lb.id
  target_group_arns = [aws_alb_target_group.default.arn]
  task_policies = [aws_iam_policy.ssm_access.arn]
}

// load balancer
resource "aws_security_group" "lb" {
  name = "${local.app_name}-alb-sg"
  description = "controls access to the ALB"
  vpc_id = module.acs.vpc.id

  ingress {
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    from_port = 443
    to_port = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_alb" "alb" {
  name = "${local.app_name}-alb"
  subnets = module.acs.public_subnet_ids
  security_groups = [
    aws_security_group.lb.id]
}
resource "aws_alb_target_group" "default" {
  name = "${local.app_name}-target-group"
  port = local.container_port
  protocol = "HTTP"
  vpc_id = module.acs.vpc.id
  target_type = "ip"
  deregistration_delay = 60

  health_check {
    healthy_threshold = "3"
    interval = "30"
    protocol = "HTTP"
    matcher = "200"
    timeout = "3"
    path = "/"
    unhealthy_threshold = "2"
  }

  depends_on = [
    aws_alb.alb]
}
resource "aws_alb_listener" "default" {
  load_balancer_arn = aws_alb.alb.id
  port = 80
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.default.id
    type = "forward"
  }
}
resource "aws_iam_policy" "ssm_access" {
  name = "${local.app_name}-access-ssm"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters",
        "ssm:GetParameter"
      ],
      "Resource": "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/super-secret"
    }
  ]
}
EOF
}
