provider "aws" {
  region = "us-west-2"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "simple_fargate" {
        source = "git@github.com:byu-oit/terraform-aws-fargate.git?ref=v1.0.0"
//  source          = "../../" // used for local testing
  app_name        = "example2"
  container_name  = "simple-container"
  container_image = "crccheck/hello-world"
  container_env_variables = {
    TEST_ENV = "foobar"
    NEW_ENV  = "wasup"
  }
  container_secrets = {
    TEST_SECRET = aws_ssm_parameter.super_secret.name
  }
  desired_count = 2

  vpc_id              = module.acs.vpc.id
  subnet_ids          = module.acs.private_subnet_ids
  load_balancer_sg_id = module.alb.alb_security_group.id
  target_groups = [
    {
      arn  = module.alb.target_groups["blue"].arn
      port = module.alb.target_groups["blue"].port
    }
  ]
  task_policies = [aws_iam_policy.ssm_access.arn]

  blue_green_deployment_config = {
    termination_wait_time_after_deployment_success = null // defaults to 15
    prod_traffic_listener_arns                     = [module.alb.listeners[80].arn]
    test_traffic_listener_arns                     = []
    blue_target_group_name                         = module.alb.target_groups["blue"].name
    green_target_group_name                        = module.alb.target_groups["green"].name
  }

  tags = {
    app = "example"
    foo = "bar"
  }

  module_depends_on = [module.alb.alb]
}

module "acs" {
  source = "git@github.com:byu-oit/terraform-aws-acs-info.git?ref=v1.0.4"
  env    = "dev"
}

module "alb" {
  source     = "git@github.com:byu-oit/terraform-aws-alb.git?ref=v1.1.0"
  name       = "example-alb"
  vpc_id     = module.acs.vpc.id
  subnet_ids = module.acs.public_subnet_ids
  default_target_group_config = {
    type                 = "ip" // or instance or lambda
    deregistration_delay = null
    slow_start           = null
    health_check = {
      path                = "/"
      interval            = null
      timeout             = null
      healthy_threshold   = null
      unhealthy_threshold = null
    }
    stickiness_cookie_duration = null
  }
  target_groups = [
    {
      listener_ports = [80]
      name_suffix    = "blue"
      port           = 8000
      config         = null // use default
    },
    {
      listener_ports = []
      name_suffix    = "green"
      port           = 8000
      config         = null // use default
    }
  ]
}

resource "aws_ssm_parameter" "super_secret" {
  name  = "/test_secret"
  type  = "String"
  value = "super-secret"
}

resource "aws_iam_policy" "ssm_access" {
  name   = "super-secret-access"
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
      "Resource": "${aws_ssm_parameter.super_secret.arn}"
    }
  ]
}
EOF
}
output "appspec_json" {
  value = module.simple_fargate.codedeploy_appspec_json
}