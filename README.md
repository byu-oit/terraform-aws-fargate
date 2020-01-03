![Latest GitHub Release](https://img.shields.io/github/v/release/byu-oit/terraform-aws-fargate?sort=semver)

# Terraform AWS Fargate

This terraform module deploys an AWS ECS Fargate Service

## Usage
```hcl
module "fargate-service" {
  source = "git@github.com:byu-oit/terraform-aws-fargate.git?ref=v1.1.0"
  app_name        = "example"
    container_image = "crccheck/hello-world"
  
    vpc_id              = module.acs.vpc.id
    subnet_ids          = module.acs.private_subnet_ids
    load_balancer_sg_id = module.alb.alb_security_group.id
    target_groups = [
      for tg in module.alb.target_groups :
      {
        arn  = tg.arn
        port = tg.port
      }
    ]
  
    role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
    module_depends_on = [module.alb.alb]
}
// ...
```

## Requirements
* Terraform version 0.12.16 or greater

## Inputs

| Name | Description | Default |
| --- | --- | --- |
| app_name | Application name to be used for naming resources | |
| container_image | Container image. See [AWS docs](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html#ECS-Type-ContainerDefinition-image) | |
| desired_count | Desired count of task definitions | 1 |
| container_name | Docker container name | <app_name> |
| container_env_variables | Map of environment variables to pass to the container definition | {} |
| container_secrets | Map of secrets from the parameter store to be assigned to env variables. Use `task_policies` to make sure the Task's IAM role has access to the SSM parameters | {} |
| vpc_id | ID of the VPC to deploy fargate service | |
| subnet_ids | List of subnet IDs for the fargate service to be deployed into | |
| target_groups | List of target groups to tie the service's containers to | |
| load_balancer_sg_id | Load balancer's security group ID | |
| task_policies | List of IAM Policy ARNs to attach to the task execution IAM Policy| [] |
| task_cpu | CPU for the task definition | 256 |
| task_memory | Memory for the task definition | 512 |
| log_retention_in_days | CloudWatch log group retention in days | 7 |
| health_check_grace_period | Health check grace period in seconds | 0 |
| blue_green_deployment_config | If you want this Fargate service to be deployed by CodeDeploy's Blue Green deployment, specify this object. See [below](#blue_green_deployment_config) | null |
| tags | A map of AWS Tags to attach to each resource created | {} |
| role_permissions_boundary_arn | IAM Role Permission Boundary ARN to be added to IAM roles created | |
| module_depends_on | Any resources that the fargate ecs service should wait on before initializing | null |

**Note** the `target_groups` is a list of the target group objects (pass the objects from the aws target_group provider)
that can access your fargate containers. These target groups must have the same port that your containers are listening 
on. For instance if your docker container is listening on port 8080 and 8443, you should have 2 target groups (and 
listeners), one mapped to port 8080 and the other to port 8443. This module will then map the Fargate service to listen 
on those ports to those target groups.

#### blue_green_deployment_config
If this object is specified then this fargate service will only be deployable by CodeDeploy; meaning you can't update 
the task definition, container, desired count and expect terraform apply to make it so. If you make an update the task
definition, then you'll need to start a new deployment from CodeDeploy (either initiated manually or by CodePipeline) in
order for the changes to take effect.

* `termination_wait_time_after_deployment_success` - (Optional) The number of minutes to wait after a successful 
    blue/green deployment before terminating instances from the original environment. Defaults to 15.
* `prod_traffic_listener_arns` - (Required) List of ARNs of the production load balancer listeners. (i.e. list of public 
    production ports)
* `test_traffic_listener_arns` = (Required) List of ARNs of the test traffic load balancer listeners. (i.e. ports where 
    green deployment will point to for testing deployment before moving production traffic to new instances)
* `blue_target_group_name` - (Required) Name of the "blue" target group.
* `green_target_group_name` = (Required) Name of the "green" target group.

## Outputs
| Name | Description |
| --- | --- |
| ecs_service | Fargate ECS Service [object](https://www.terraform.io/docs/providers/aws/r/ecs_service.html#attributes-reference) |
| ecs_cluster | ECS Cluster [object](https://www.terraform.io/docs/providers/aws/r/ecs_cluster.html#attributes-reference) |
| task_definition | Fargate Task Definition [object](https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html#attributes-reference) |
| service_sg | Security Group [object](https://www.terraform.io/docs/providers/aws/r/security_group.html#attributes-reference) assigned to the Fargate service |
| task_execution_role | IAM task execution Role [object](https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html#attributes-reference) assigned to the Task Definition |
| cloudwatch_log_group | Cloudwatch Log Group [object](https://www.terraform.io/docs/providers/aws/r/cloudwatch_log_group.html#attributes-reference) for the Fargate logs |   
| codedeploy_app | If `blue_green_deployment_config` is defined, the CodeDeploy App [object](https://www.terraform.io/docs/providers/aws/r/codedeploy_app.html) |   
| codedeploy_role | If `blue_green_deployment_config` is defined, the IAM Role [object](https://www.terraform.io/docs/providers/aws/r/iam_role.html#attributes-reference) associated with the CodeDeploy |   
| codedeploy_deployment_group | If `blue_green_deployment_config` is defined, the CodeDeploy Deployment Group [object](https://www.terraform.io/docs/providers/aws/r/codedeploy_deployment_group.html) |
| codedeploy_appspec_json | JSON string of a simple appspec.json file to be used in the CodeDeploy deployment |

## Resources it creates
* ECS Cluster
* ECS Service
* ECS Task Definition
* IAM Role - task execution role for ECS Task Def
* EC2 Security Group - for ECS Service 
* CloudWatch Log Group - for ECS Service 
* (CodeDeploy App) if `blue_green_deployment_config` is defined
* (IAM Role for CodeDeploy) if `blue_green_deployment_config` is defined
* (CodeDeploy Deployment Group) if `blue_green_deployment_config` is defined

## TODO
* Maybe allow passing in an existing ECS Cluster
