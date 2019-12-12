// Required
variable "app_name" {
  type = string
  description = "Application name to be used for naming resources."
}
variable "container_image" {
  type = string
  description = "Container image. See https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html#ECS-Type-ContainerDefinition-image"
}
variable "vpc_id" {
  type = string
  description = "ID of the VPC."
}
variable "subnet_ids" {
  type = list(string)
  description = "List of subnet IDs for the fargate service to be deployed into."
}
variable "load_balancer_sg_id" {
  type = string
  description = "Load balancer's security group ID."
}
variable "target_group_arns" {
  type = list(string)
  description = "List of target group ARNs. Your target groups need to have the correct ports that your container has exposed."
}

// Optional
variable "desired_count" {
  type = number
  description = "Desired count of task definitions. Defaults to 1."
  default = 1
}
variable "container_name" {
  type = string
  description = "Container name. Defaults to app_name."
  default = ""
}
variable "container_env_variables" {
  type = map(string)
  description = "Map of environment variables to pass to the container definition. Defaults to an empty map."
  default = {}
}
variable "container_secrets" {
  type = map(string)
  description = "Map of secrets from the parameter store to be assigned to an env variable. Defaults to an empty map."
  default = {}
}
variable "task_policies" {
  type = list(string)
  description = "List of IAM Policy ARNs to attach to the task execution policy."
  default = []
}
variable "task_cpu" {
  type = number
  description = "CPU for the task definition. Defaults to 256."
  default = 256
}
variable "task_memory" {
  type = number
  description = "Memory for the task definition. Defaults to 512."
  default = 512
}
variable "log_retention_in_days" {
  type = number
  description = "CloudWatch log group retention in days. Defaults to 7."
  default = 7
}
variable "health_check_grace_period" {
  type = number
  description = "Health check grace period in seconds. Defaults to 0."
  default = 0
}