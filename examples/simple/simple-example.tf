provider "aws" {
  region = "us-west-2"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "simple_fargate" {
      source = "git@github.com:byu-oit/terraform-aws-fargate.git?ref=v1.0.0"
//  source          = "../../" // used for local testing
  app_name        = "example"
  container_image = "crccheck/hello-world"

  vpc_id              = module.acs.vpc.id
  subnet_ids          = module.acs.private_subnet_ids
  load_balancer_sg_id = module.alb.alb_security_group.id
  target_groups = [
    for tg in module.alb.target_groups :
    {
      arn  = tg.arn
      port = tg.port
    }
  ]

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
      listener_ports = [
        80,
        443
      ]
      name_suffix = "main"
      port        = 8000
      config      = null // use default
    }
  ]
}
