variable "app_name" {
  type = string
  description = "Application name to be used for naming and tagging resources"
}

variable "container_definitions" {
  type = string
  description = "JSON of the container definitions"
}

variable "task_cpu" {
  type = number
  description = "CPU for the task definition"
  default = 256
}

variable "task_memory" {
  type = number
  description = "Memory for the task definition"
  default = 512
}

variable "container_port" {
  type = number
  description = "Container port"
}

variable "vpc_id" {
  type = string
  description = "ID of the VPC"
}

variable "subnet_ids" {
  type = list(string)
  description = "IDs of the subnets for the fargate service to be deployed into"
}

variable "target_group_arn" {
  type = string
  description = "Target group arn"
}

variable "load_balancer_sg_id" {
  type = string
  description = "Load balancer's security group ID"
}
