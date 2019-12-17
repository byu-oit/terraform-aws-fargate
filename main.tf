module "acs" {
  source = "git@github.com:byu-oit/terraform-aws-acs-info.git?ref=v1.0.2"
  env = "dev"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  container_name = var.container_name != "" ? var.container_name: var.app_name // default to app_name if not defined
  port_mappings = [
    for tg in var.target_groups:
    {
      // container_port and host_port must be the same with fargate's awsvpc networking mode in the task definition. So we use the target group's port for both.
      containerPort = tg.port
      hostPort = tg.port
      protocol = "tcp"
    }
  ]
  environment_variables = [
    for key in keys(var.container_env_variables):
    {
      name = key
      value = lookup(var.container_env_variables, key)
    }
  ]
  secrets = [
  for key in keys(var.container_secrets):
    {
      name = key
      valueFrom = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${lookup(var.container_secrets, key)}"
    }
  ]

  container_definition = {
    name = local.container_name
    image = var.container_image
    essential = true
    privileged = false
    portMappings = local.port_mappings
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group = aws_cloudwatch_log_group.container_log_group.name
        awslogs-region = data.aws_region.current.name
        awslogs-stream-prefix = local.container_name
      }
    }
    environment = local.environment_variables
    secrets = local.secrets
    mountPoints = []
    volumesFrom = []
  }

  container_definition_json = jsonencode(local.container_definition)
}

resource "aws_ecs_cluster" "cluster" {
  name = var.app_name

  tags = var.tags
}

resource "aws_ecs_task_definition" "task_def" {
  container_definitions = "[${local.container_definition_json}]"
  family = "${var.app_name}-def"
  cpu = var.task_cpu
  memory = var.task_memory
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn = aws_iam_role.task_execution_role.arn

  tags = var.tags
}

resource "aws_ecs_service" "service" {
  name = var.app_name
  task_definition = aws_ecs_task_definition.task_def.arn
  cluster = aws_ecs_cluster.cluster.id
  desired_count = var.desired_count
  launch_type = "FARGATE"
  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets = var.subnet_ids
    security_groups = [aws_security_group.fargate_service_sg.id]
    assign_public_ip = true
  }

  dynamic "load_balancer" {
    for_each = var.target_groups
    content {
      target_group_arn = load_balancer.value.arn
      container_name = local.container_name
      container_port = load_balancer.value.port
    }
  }

  health_check_grace_period_seconds = var.health_check_grace_period

  lifecycle {
    ignore_changes = [
      task_definition, // ignore because new revisions will get added after code deploy's blue-green deployment
      load_balancer, // ignore because load balancer can change after code deploy's blue-green deployment
      tags
    ]
  }

  tags = var.tags

  depends_on = [var.module_depends_on]
}

resource "aws_iam_role" "task_execution_role" {
  name = "${var.app_name}-ecsTaskExecution-role"

  assume_role_policy = <<EOF
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
  permissions_boundary = module.acs.role_permissions_boundary.arn

  tags = var.tags
}

resource "aws_iam_policy_attachment" "task_execution_policy_attach" {
  name = "${var.app_name}-ecsTaskExecution-role-attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  roles = [aws_iam_role.task_execution_role.name]
}

resource "aws_iam_policy_attachment" "user_policies" {
  count = length(var.task_policies)

  name = "${var.app_name}-ecsTaskExecution-${count.index}"
  policy_arn = element(var.task_policies, count.index)
  roles = [aws_iam_role.task_execution_role.name]
}

resource "aws_security_group" "fargate_service_sg" {
  name = "${var.app_name}-fargate-sg"
  description = "controls access to the Fargate service"
  vpc_id = var.vpc_id

//  only allow access to the fargate service from the load balancer
  ingress {
    protocol = "tcp"
    security_groups = [var.load_balancer_sg_id]
    from_port = 0
    to_port = 65535
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "container_log_group" {
  name = "fargate/${var.app_name}"
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}
