provider "aws" {
  version = "~> 2.42"
  region  = "us-west-2"
}

module "acs" {
  source = "git@github.com:byu-oit/terraform-aws-acs-info.git?ref=v1.0.4"
  env    = "dev"
}

module "simple_fargate" {
  source = "github.com/byu-oit/terraform-aws-fargate?ref=v1.2.3"
  //  source          = "../../" // used for local testing
  app_name        = "example2"
  container_name  = "simple-container"
  container_image = "crccheck/hello-world"
  container_env_variables = {
    TEST_ENV = "foobar"
  }
  container_secrets = {
    TEST_SECRET = aws_ssm_parameter.super_secret.name
  }
  desired_count = 2

  vpc_id              = module.acs.vpc.id
  subnet_ids          = module.acs.private_subnet_ids
  load_balancer_sg_id = module.alb.alb_security_group.id
  target_groups       = [module.alb.target_groups["blue"]]
  task_policies       = [aws_iam_policy.ssm_access.arn]

  blue_green_deployment_config = {
    termination_wait_time_after_deployment_success = null // defaults to 15
    prod_traffic_listener_arns                     = [module.alb.listeners[80].arn]
    test_traffic_listener_arns                     = []
    blue_target_group_name                         = module.alb.target_groups["blue"].name
    green_target_group_name                        = module.alb.target_groups["green"].name
    service_role_arn                               = module.acs.power_builder_role.arn
  }

  tags = {
    app = "example"
    foo = "bar"
  }

  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
  module_depends_on             = [module.alb.alb]
}

module "alb" {
  source     = "git@github.com:byu-oit/terraform-aws-alb.git?ref=v1.2.0"
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