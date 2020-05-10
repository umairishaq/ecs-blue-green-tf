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

aws ecs create-task-set --service $SERVICE_ARN --cluster $CLUSTER_ARN --cli-input-json file://$TASK_SET
