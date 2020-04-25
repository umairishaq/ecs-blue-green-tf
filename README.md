# ecs-blue-green-tf

IaC assets for ECS service with blue/green deployment.

### Folder Structure:

The root main.tf would use modules defined under the module folder to compose a working stack. Please, define individual components (Service, TaskSets, ALB, etc.) in a folder within module. E.g. the ECS service module would live in module/ecs-service folder.