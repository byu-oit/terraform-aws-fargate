provider "aws" {
  region = "us-west-2"
}

data "aws_caller_identity" "current" {}

resource "aws_ecs_cluster" "cluster" {
  name = var.app_name
}

resource "aws_ecs_task_definition" "task_def" {
  container_definitions = var.container_definitions
  family = "${var.app_name}-def"
  cpu = var.task_cpu
  memory = var.task_memory
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn = aws_iam_role.task_execution_role.arn
}

resource "aws_ecs_service" "service" {
  name = var.app_name
  task_definition = aws_ecs_task_definition.task_def.arn
  cluster = aws_ecs_cluster.cluster.id
  desired_count = 1
  launch_type = "FARGATE"
  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets = var.subnet_ids
    security_groups = [aws_security_group.fargate_service_sg.id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = var.target_group_arn
    container_name = var.app_name
    container_port = var.container_port
  }

  lifecycle {
    ignore_changes = [
      task_definition, // ignore because new revisions will get added after code deploy's blue-green deployment
      load_balancer, // ignore because load balancer can change after code deploy's blue-green deployment
      tags
    ]
  }
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
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/iamRolePermissionBoundary"
}

resource "aws_iam_policy_attachment" "task_execution_policy_attach" {
  name = "${var.app_name}-ecsTaskExecution-role-attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
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
}
