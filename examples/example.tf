provider "aws" {
  region = "us-west-2"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "simple_fargate" {
    source = "git@github.com:byu-oit/terraform-aws-fargate.git?ref=v0.1.1"
//  source = "../" // used for local testing
  app_name = "example"
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
  load_balancer_sg_id = module.alb.alb_security_group.id
  target_groups = [
  for tg in module.alb.target_groups:
  {
    arn = tg.arn
    port = tg.port
  }
  ]
  task_policies = [aws_iam_policy.ssm_access.arn]

  tags = {
    app = "example"
    foo = "bar"
  }

  module_depends_on = [module.alb.alb]
}


module "acs" {
  source = "git@github.com:byu-oit/terraform-aws-acs-info.git?ref=v1.0.2"
  env = "dev"
}

module "alb" {
  source = "git@github.com:byu-oit/terraform-aws-alb.git?ref=fixes"
  name = "example-alb"
  port_mappings = [
    {
      public_port = 80
      target_port = 8000
    }
  ]
  health_checks = [
    {
      port = 8000
      path = "/"
      interval = null
      timeout = null
      healthy_threshold = null
      unhealthy_threshold = null
    }
  ]
  vpc_id = module.acs.vpc.id
  subnet_ids = module.acs.public_subnet_ids
}

resource "aws_iam_policy" "ssm_access" {
  name = "example-access-ssm"
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
