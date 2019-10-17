output "fargate_service_name" {
  value = aws_ecs_service.service.name
}
output "fargate_cluster_name" {
  value = aws_ecs_cluster.cluster.name
}
