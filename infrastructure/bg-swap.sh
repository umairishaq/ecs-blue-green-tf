#!/bin/sh

set -e

export AWS_PROFILE=mylabTerraformCli
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
CONFIG_FILE=$SCRIPT_DIR/DeploymentConfig.json
TMP_TASK_FILE=$SCRIPT_DIR/td_tmp.json
TMP_TASK_SET_FILE=$SCRIPT_DIR/tset_tmp.json
NEXT_ENV=$(cat infrastructure/DeploymentConfig.json | jq '.nextEnvironment')

if [[ $NEXT_ENV = '"Green"' ]]; then
    echo "GREEEEEEEEEEEEEN"
    TASK_TEMPLATE_FILE=$SCRIPT_DIR/GreenTaskDefinition.template.json
    TASK_DEFINITION=$SCRIPT_DIR/GreenTaskDefinition.json
    TASK_SET_TEMPLATE_FILE=$SCRIPT_DIR/GreenTaskSet.template.json
    TASK_SET=$SCRIPT_DIR/GreenTaskSet.json
    TASK_FAMILY_PREFIX=GreenTaskDefinition
else
    echo "BLUUUUUUUUUUUUUE"
    TASK_TEMPLATE_FILE=$SCRIPT_DIR/BlueTaskDefinition.template.json
    TASK_DEFINITION=$SCRIPT_DIR/BlueTaskDefinition.json
    TASK_SET_TEMPLATE_FILE=$SCRIPT_DIR/BlueTaskSet.template.json
    TASK_SET=$SCRIPT_DIR/BlueTaskSet.json
    TASK_FAMILY_PREFIX=BlueTaskDefinition
fi

cat $TASK_TEMPLATE_FILE | jq --slurpfile config $CONFIG_FILE '.containerDefinitions[0].image=$config[0].appImage' > $TMP_TASK_FILE
cat $TMP_TASK_FILE | jq --slurpfile config $CONFIG_FILE '.containerDefinitions[0].portMappings[0].containerPort=$config[0].containerPort' > $TASK_DEFINITION

# aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 807080734664.dkr.ecr.us-east-1.amazonaws.com

# docker build -t awesome-api-repository ../src
# GIT_HASH=2a8b65f
# docker tag awesome-api-repository:latest 807080734664.dkr.ecr.us-east-1.amazonaws.com/awesome-api-repository:$GIT_HASH
# docker push 807080734664.dkr.ecr.us-east-1.amazonaws.com/awesome-api-repository:$GIT_HASH


aws ecs register-task-definition --cli-input-json file://$TASK_DEFINITION

NEW_TASKSET_ARN=$(aws ecs list-task-definitions --family-prefix $TASK_FAMILY_PREFIX --status ACTIVE --sort DESC | jq -r '.taskDefinitionArns[0]')
echo "----------"
echo $NEW_TASKSET_ARN
echo "----------"
jq --arg taskarn $NEW_TASKSET_ARN '.taskDefinition=$taskarn' <$TASK_SET_TEMPLATE_FILE > $TMP_TASK_SET_FILE

jq --slurpfile config $CONFIG_FILE '.loadBalancers[0].containerPort=$config[0].containerPort' <$TMP_TASK_SET_FILE > $TASK_SET

SERVICE_ARN=$(cat $CONFIG_FILE | jq -r '.serviceArn')
CLUSTER_ARN=$(cat $CONFIG_FILE | jq -r '.clusterArn')

TASK_SET_CREATE_RESPONSE=$(aws ecs create-task-set --service $SERVICE_ARN --cluster $CLUSTER_ARN --cli-input-json file://$TASK_SET)
GREEN_TASK_SET_ARN=echo $TASK_SET_CREATE_RESPONSE | jq -r '.taskSetArn'

aws ecs update-service-primary-task-set --service $SERVICE_ARN --cluster $CLUSTER_ARN --primary-task-set $GREEN_TASK_SET_ARN

# Wait for validation
sleep 30

# ************* aws ecs delete-task-set --task-set ecs-svc/7771398481905376234 --service AwesomeApiService --cluster BlueGreenCluster ********
# IMP: need to delete the old task set because 5 is the limit.

# Doesn't quite work. need to delete oldest one.
# aws ecs update-task-set --cluster arn:aws:ecs:us-east-1:807080734664:cluster/BlueGreenCluster --service arn:aws:ecs:us-east-1:807080734664:service/AwesomeApiService --task-set arn:aws:ecs:us-east-1:807080734664:task-set/BlueGreenCluster/AwesomeApiService/ecs-svc/7016605822699692712 --scale value=0,unit=PERCENT
# aws ecs describe-services --services AwesomeApiService --cluster BlueGreenCluster
# Delete the task set.
# aws ecs delete-task-set --cluster cluster --service service --task-set someid

# Update blue listener to point to green TG.
# Update green listener to point to blue TG.
aws elbv2 modify-rule \
            --actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:us-east-1:807080734664:targetgroup/MyTes-Green-1JL00XOVE9SQX/6680613ad3b1cf37 \
            --conditions Field=path-pattern,Values='/images/*'
            --rule-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:listener-rule/app/my-load-balancer/50dc6c495c0c9188/f2f7dc8efc522ab2/9683b2d02a6cabee



aws elbv2 modify-listener --listener-arn arn:aws:elasticloadbalancing:us-east-1:807080734664:listener/app/MyTes-LoadB-GUJPHAD258YD/299cae4d5acda2fb/ce7a66246153ef61 --cli-input-json file://infrastructure/ListenerDefaultAction.template.json