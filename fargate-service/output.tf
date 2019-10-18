output "fargate_service_name" {
  value = aws_ecs_service.service.name
}
output "fargate_cluster_name" {
  value = aws_ecs_cluster.cluster.name
}
output "fargate_task_def_arn" {
  value = aws_ecs_task_definition.task_def.arn
}
