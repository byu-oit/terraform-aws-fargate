# Fargate Service Terraform Module

This terraform module deploys an AWS ECS Fargate Service

## Usage
```hcl
module "fargate-service" {
  source = "git@github.com:byu-oit/terraform-aws-fargate.git?ref=v1.0.0"
  app_name = "simple-fargate-example"
  container_name = "simple-container"
  container_image = "crccheck/hello-world"
  container_env_variables = {
    TEST_ENV = "foobar"
  }
  container_secrets = {
    TEST_SECRET = "super-secret"
  }
  container_port_mappings = [
    {
      host_port = 8000
      container_port = 8000
    }
  ]

  vpc_id = module.acs.vpc.id
  subnet_ids = module.acs.private_subnet_ids
  load_balancer_sg_id = aws_security_group.lb.id
  target_group_arn = aws_alb_target_group.default.arn
}
// ...
```

## Inputs

| Name | Description | Default |
| --- | --- | --- |
| app_name | Application name to be used for naming resources | |
| container_image | Container image. See [AWS docs](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html#ECS-Type-ContainerDefinition-image) | |
| container_name | Docker container name | <app_name> |
| container_port_mappings | List of container's port mappings | ```[{host_port = 80 container_port = 80}]``` |
| container_env_variables | Map of environment variables to pass to the container definition | {} |
| container_secrets | Map of secrets from the parameter store to be assigned to env variables. Use `task_policies` to make sure the Task's IAM role has access to the SSM parameters | {} |
| vpc_id | ID of the VPC to deploy fargate service | |
| subnet_ids | List of subnet IDs for the fargate service to be deployed into | |
| target_group_arn | Target group arn to point to the fargate containers | |
| load_balancer_sg_id | Load balancer's security group ID | |
| task_policies | List of IAM Policy ARNs to attach to the task execution IAM Policy| [] |
| task_cpu | CPU for the task definition | 256 |
| task_memory | Memory for the task definition | 512 |
| log_retention_in_days | CloudWatch log group retention in days | 7 |
| health_check_grace_period | Health check grace period in seconds | 0 |

## Outputs
| Name | Description |
| --- | --- |
| ecs_service | Fargate ECS Service [object](https://www.terraform.io/docs/providers/aws/r/ecs_service.html#attributes-reference) |
| ecs_cluster | ECS Cluster [object](https://www.terraform.io/docs/providers/aws/r/ecs_cluster.html#attributes-reference) |
| task_definition | Fargate Task Definition [object](https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html#attributes-reference) |
| service_sg | Security Group [object](https://www.terraform.io/docs/providers/aws/r/security_group.html#attributes-reference) assigned to the Fargate service |
| task_execution_role | IAM task execution Role [object](https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html#attributes-reference) assigned to the Task Definition |
| cloudwatch_log_group | Cloudwatch Log Group [object](https://www.terraform.io/docs/providers/aws/r/cloudwatch_log_group.html#attributes-reference) for the Fargate logs |   

## Resources it creates
* ECS Cluster
* ECS Service
* ECS Task Definition
* IAM Role - task execution role for ECS Task Def
* EC2 Security Group - for ECS Service 
* CloudWatch Log Group - for ECS Service 

## TODO
* Add Auto Scaling
* Add tags
* Maybe add ability to create Fargate without CODE_DEPLOY as deployment controller
* Maybe allow passing in existing ECS Cluster
