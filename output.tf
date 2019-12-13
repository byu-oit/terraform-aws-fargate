output "ecs_service" {
  value = aws_ecs_service.service
}
output "ecs_cluster" {
  value = aws_ecs_cluster.cluster
}
output "task_definition" {
  value = aws_ecs_task_definition.task_def
}
output "service_sg" {
  value = aws_security_group.fargate_service_sg
}
output "task_execution_role" {
  value = aws_iam_role.task_execution_role
}
output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.container_log_group
}