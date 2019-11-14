output "ecs_service_id" {
  value = aws_ecs_service.service.id
}
output "ecs_service_name" {
  value = aws_ecs_service.service.name
}
output "ecs_cluster_id" {
  value = aws_ecs_cluster.cluster.id
}
output "ecs_cluster_name" {
  value = aws_ecs_cluster.cluster.name
}
output "task_definition_arn" {
  value = aws_ecs_task_definition.task_def.arn
}
output "service_sg_id" {
  value = aws_security_group.fargate_service_sg.id
}
output "service_sg_name" {
  value = aws_security_group.fargate_service_sg.name
}