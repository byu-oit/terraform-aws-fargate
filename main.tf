terraform {
  required_version = ">= 0.12.16"
  required_providers {
    aws = ">= 2.42"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  container_name = var.container_name != "" ? var.container_name : var.app_name // default to app_name if not defined
  port_mappings = [
    for tg in var.target_groups :
    {
      // container_port and host_port must be the same with fargate's awsvpc networking mode in the task definition. So we use the target group's port for both.
      containerPort = tg.port
      hostPort      = tg.port
      protocol      = "tcp"
    }
  ]
  environment_variables = [
    for key in keys(var.container_env_variables) :
    {
      name  = key
      value = lookup(var.container_env_variables, key)
    }
  ]
  secrets = [
    for key in keys(var.container_secrets) :
    {
      name      = key
      valueFrom = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${replace(lookup(var.container_secrets, key), "/^//", "")}"
    }
  ]

  container_definition = {
    name         = local.container_name
    image        = var.container_image
    essential    = true
    privileged   = false
    portMappings = toset(local.port_mappings)
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.container_log_group.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = local.container_name
      }
    }
    environment = local.environment_variables
    secrets     = local.secrets
    mountPoints = []
    volumesFrom = []
  }

  container_definition_json = jsonencode(local.container_definition)

  is_deployed_by_codedeploy = var.blue_green_deployment_config != null
}

resource "aws_ecs_cluster" "cluster" {
  name = var.app_name

  tags = var.tags
}

resource "aws_ecs_task_definition" "task_def" {
  container_definitions    = "[${local.container_definition_json}]"
  family                   = "${var.app_name}-def"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  tags                     = var.tags
}

resource "aws_ecs_service" "service" {
  count = ! local.is_deployed_by_codedeploy ? 1 : 0

  name            = var.app_name
  task_definition = aws_ecs_task_definition.task_def.arn
  cluster         = aws_ecs_cluster.cluster.id
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = concat([aws_security_group.fargate_service_sg.id], var.security_groups)
    assign_public_ip = true
  }

  dynamic "load_balancer" {
    for_each = var.target_groups
    content {
      target_group_arn = load_balancer.value.arn
      container_name   = local.container_name
      container_port   = load_balancer.value.port
    }
  }

  health_check_grace_period_seconds = var.health_check_grace_period

  tags = var.tags

  depends_on = [var.module_depends_on]
}
resource "aws_ecs_service" "code_deploy_service" {
  count = local.is_deployed_by_codedeploy ? 1 : 0

  name            = var.app_name
  task_definition = aws_ecs_task_definition.task_def.arn
  cluster         = aws_ecs_cluster.cluster.id
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = concat([aws_security_group.fargate_service_sg.id], var.security_groups)
    assign_public_ip = true
  }

  dynamic "load_balancer" {
    for_each = var.target_groups
    content {
      target_group_arn = load_balancer.value.arn
      container_name   = local.container_name
      container_port   = load_balancer.value.port
    }
  }

  health_check_grace_period_seconds = var.health_check_grace_period

  tags = var.tags

  depends_on = [var.module_depends_on]

  lifecycle {
    ignore_changes = [
      task_definition, // ignore because new revisions will get added after code deploy's blue-green deployment
      load_balancer,   // ignore because load balancer can change after code deploy's blue-green deployment
      desired_count    // igrnore because we're assuming you have autoscaling to manage the container count
    ]
  }
}

resource "aws_iam_role" "task_execution_role" {
  name = "${var.app_name}-ecsTaskExecution-role"

  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  permissions_boundary = var.role_permissions_boundary_arn

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "task_execution_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.task_execution_role.name
}

resource "aws_iam_role_policy_attachment" "task_execution_role_user_policies" {
  count      = length(var.task_execution_policies)
  policy_arn = element(var.task_execution_policies, count.index)
  role       = aws_iam_role.task_execution_role.name
}

resource "aws_iam_role" "task_role" {
  name = "${var.app_name}-ecsTask-role"

  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  permissions_boundary = var.role_permissions_boundary_arn

  tags = var.tags
}


resource "aws_iam_role_policy_attachment" "task_role_user_policies" {
  count      = length(var.task_policies)
  policy_arn = element(var.task_policies, count.index)
  role       = aws_iam_role.task_role.name
}

resource "aws_security_group" "fargate_service_sg" {
  name        = "${var.app_name}-fargate-sg"
  description = "controls access to the Fargate service"
  vpc_id      = var.vpc_id

  //  only allow access to the fargate service from the load balancer
  ingress {
    protocol        = "tcp"
    security_groups = [var.load_balancer_sg_id]
    from_port       = 0
    to_port         = 65535
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "container_log_group" {
  name              = "fargate/${var.app_name}"
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}

// CodeDeploy if config was included
resource "aws_codedeploy_app" "app" {
  count = local.is_deployed_by_codedeploy ? 1 : 0

  name             = "${var.app_name}-codedeploy"
  compute_platform = "ECS"
}

resource "aws_iam_role" "codedeploy_role" {
  count = local.is_deployed_by_codedeploy ? 1 : 0

  name                 = "${var.app_name}-codedeploy-role"
  permissions_boundary = var.role_permissions_boundary_arn
  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  count = local.is_deployed_by_codedeploy ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codedeploy_role[0].name
}

resource "aws_codedeploy_deployment_group" "deploymentgroup" {
  count = local.is_deployed_by_codedeploy ? 1 : 0

  app_name               = aws_codedeploy_app.app[0].name
  deployment_group_name  = "${var.app_name}-deployment-group"
  service_role_arn       = var.blue_green_deployment_config.service_role_arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  ecs_service {
    cluster_name = aws_ecs_cluster.cluster.name
    service_name = local.is_deployed_by_codedeploy ? aws_ecs_service.code_deploy_service[0].name : aws_ecs_service.service[0].name
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = var.blue_green_deployment_config.termination_wait_time_after_deployment_success != null ? var.blue_green_deployment_config.termination_wait_time_after_deployment_success : 15
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = var.blue_green_deployment_config.prod_traffic_listener_arns
      }
      test_traffic_route {
        listener_arns = var.blue_green_deployment_config.test_traffic_listener_arns
      }
      target_group {
        name = var.blue_green_deployment_config.blue_target_group_name
      }
      target_group {
        name = var.blue_green_deployment_config.green_target_group_name
      }
    }
  }

  lifecycle { ignore_changes = [blue_green_deployment_config] }
}