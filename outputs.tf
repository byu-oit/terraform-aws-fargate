output "ecs_service" {
  value = ! local.is_deployed_by_codedeploy ? aws_ecs_service.service[0] : aws_ecs_service.code_deploy_service[0]
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
output "codedeploy_app" {
  value = local.is_deployed_by_codedeploy ? aws_codedeploy_app.app[0] : null
}
output "codedeploy_role" {
  value = local.is_deployed_by_codedeploy ? aws_iam_role.codedeploy_role[0] : null
}
output "codedeploy_deployment_group" {
  value = local.is_deployed_by_codedeploy ? aws_codedeploy_deployment_group.deploymentgroup[0] : null
}
output "codedeploy_appspec_json" {
  value = local.is_deployed_by_codedeploy ? jsonencode({
    version = 1
    Resources = [{
      TargetService = {
        Type = "AWS::ECS::SERVICE"
        Properties = {
          TaskDefinition = aws_ecs_task_definition.task_def.arn
          LoadBalancerInfo = {
            ContainerName = local.container_name
            ContainerPort = var.target_groups[0].port
          }
        }
      }
    }]
  }) : null
}
