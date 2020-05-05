# Flip Commands:

#Variables:

## ALB listener ARN:
Prod_Listener="arn:aws:elasticloadbalancing:us-east-1:111122223333:listener/app/exter-LoadB-18SYMFEJCT0V4/830a28831234fb0a/fc1fad0edb409503"
Test_Listener="arn:aws:elasticloadbalancing:us-east-1:111122223333:listener/app/exter-LoadB-18SYMFEJCT0V4/830a28831234fb0a/22ee570f0cb9e91d"

## ALB targetgroup ARN:
Green_TargetGroup="arn:aws:elasticloadbalancing:us-east-1:111122223333:targetgroup/exter-Green-1ADL07GUB01SA/e36ad71e096c7234"
Blue_Targetgroup="arn:aws:elasticloadbalancing:us-east-1:111122223333:targetgroup/exter-BlueS-1UB69WFT25317/a3e2e23672a63ec2"


## Switch green target group to prod listener:
aws elbv2 modify-listener --listener-arn $Prod_Listener --default-actions Type=forward,TargetGroupArn=$Green_TargetGroup


## Switch blue target group to secondary listener:
aws elbv2 modify-listener --listener-arn $Test_Listener --default-actions Type=forward,TargetGroupArn=$Blue_Targetgroup

## Updating Primary Task set in ECS
aws ecs update-service-primary-task-set --cluster blue-green --service bg-svc-example --primary-task-set <task-set-id-green>

## Deleting blue task set
aws ecs delete-task-set --service bg-svc-example --cluster blue-green --task-set <task-set-id-blue>
