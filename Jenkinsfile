pipeline {
    agent none
    environment { 
        AWS_PROFILE = credentials('AWS_CREDENTIALS_PROFILE')
    }
    stages {
        stage('Build') {
            agent any
            steps {
                sh 'make build-image'
            }
        }
        stage('EcrPush') {
            agent any
            steps {
                script {
                    readProperties(file: 'Makefile.env').each { key, value -> env[key] = value }
                }
                sh '$(aws ecr get-login --no-include-email --registry-ids $AWS_ACCOUNT_NUMBER)'
                script {
                    def PUSH_RESULT = sh (
                    script: "make push-image",
                    returnStdout: true
                    ).trim()
                    echo "Push result: ${PUSH_RESULT}"
                }
            }
        }
        stage('SetEnvironment'){
            agent any
            steps {
                script {
                    // This step reloads the env with configured values for account number and region in various values.
                    readProperties(file: 'Makefile.env').each { key, value -> tv = value.replace("AWS_ACCOUNT_NUMBER", env.AWS_ACCOUNT_NUMBER)
                                                                              env[key] = tv.replace("REGION", env.REGION)
                                                              }
                }
            }
        }
        stage('RegisterTaskDefinition') {
            agent any
            steps {
                sh 'printenv'
                script {
                    def newImage = sh (
                    script: "make latest_image",
                    returnStdout: true
                    ).trim()
                    def templateFile = 'file'
                    if ( env.NEXT_ENV == 'Green'){
                        templateFile =  env.TEMPLATE_BASE_PATH + '/' + GREEN_TASK_DEF_TEMPLATE
                    }
                    else {
                        templateFile = env.TEMPLATE_BASE_PATH +'/' + BLUE_TASK_DEF_TEMPLATE
                    }

                    def taskDefinitionTemplate = readJSON(file: templateFile)
                    taskDefinitionTemplate.taskRoleArn = env.TASK_ROLE_ARN
                    taskDefinitionTemplate.executionRoleArn = env.EXECUTION_ROLE_ARN
                    taskDefinitionTemplate.containerDefinitions[0].image = newImage
                    taskDefinitionTemplate.containerDefinitions[0].portMappings[0].containerPort = env.APP_PORT.toInteger()
                    taskDefFile = env.TEMPLATE_BASE_PATH + '/' + env.TASK_DEFINITION_FILE
                    writeJSON(file: taskDefFile, json: taskDefinitionTemplate)
                    
                    def registerTaskDefinitionOutput = sh (
                    script: "aws ecs register-task-definition --cli-input-json file://${taskDefFile}",
                    returnStdout: true
                    ).trim()
                    echo "Register Task Def result: ${registerTaskDefinitionOutput}"

                    registerTaskDefOutputFile = env.TEMPLATE_BASE_PATH + '/' + env.REGISTER_TASK_DEF_OUTPUT
                    writeJSON(file: registerTaskDefOutputFile, json: registerTaskDefinitionOutput, pretty: 2)
                }
            }
        }
        stage('CreateTaskSet') {
            agent any
            steps{
                script{
                    def taskFamily = 'family'
                    def taskSetTemplateFile = 'file'
                    def taskSetFile = env.TEMPLATE_BASE_PATH + '/' + env.TASK_SET_FILE
                    def createTaskSetOutputFile = env.TEMPLATE_BASE_PATH + '/' + env.CREATE_TASK_SET_OUTPUT
                    def targetGroupArn = 'tg'

                    if ( env.NEXT_ENV == 'Green' ){
                        taskFamily = env.GREEN_TASK_FAMILY_PREFIX
                        taskSetTemplateFile = env.TEMPLATE_BASE_PATH + '/' + env.GREEN_TASK_SET_TEMPLATE_FILE
                        targetGroupArn = env.GREEN_TARGET_GROUP_ARN
                    }
                    else{
                        taskFamily = env.BLUE_TASK_FAMILY_PREFIX
                        taskSetTemplateFile = env.TEMPLATE_BASE_PATH + '/' + env.BLUE_TASK_SET_TEMPLATE_FILE
                        targetGroupArn = env.BLUE_TARGET_GROUP_ARN
                    }

                    def latestTaskDefArn = sh (
                    script: "aws ecs list-task-definitions --family-prefix ${taskFamily} --status ACTIVE --sort DESC",
                    returnStdout: true
                    ).trim()

                    echo "Task Definition List: ${latestTaskDefArn.taskDefinitionArns[0]}"
                    echo "===================================================="
                    echo "TG GP from ENV: ${targetGroupArn}"
                    echo "TG ARN: ${taskSetTemplateJson.loadBalancers[0].targetGroupArn}"
                    def taskSetTemplateJson = readJSON(file: taskSetTemplateFile)
                    taskSetTemplateJson.taskDefinition = latestTaskDefArn.taskDefinitionArns[0]
                    taskSetTemplateJson.loadBalancers[0].containerPort = env.APP_PORT.toInteger()
                    taskSetTemplateJson.loadBalancers[0].targetGroupArn = targetGroupArn
                    writeJSON(file: taskSetFile, json: taskSetTemplateJson, pretty: 2)

                    // register the task
                    def createTaskSetOutput = sh (
                    script: "aws ecs create-task-set --service $SERVICE_ARN --cluster $CLUSTER_ARN --cli-input-json file://${taskSetFile}",
                    returnStdout: true
                    ).trim()
                    echo "Create Task Set Result Arn: ${createTaskSetOutput.taskSetArn}"

                    writeJSON(file: createTaskSetOutputFile, json: createTaskSetOutput, pretty: 2)
                }
            }
        }
        stage('UpdatePrimaryTaskSet'){
            agent any
            steps{
                script{
                    def createTaskSetOutputFile = env.TEMPLATE_BASE_PATH + '/' + env.CREATE_TASK_SET_OUTPUT
                    def upatePrimaryTaskSetOutputFile = env.TEMPLATE_BASE_PATH + '/' + env.UPDATE_PRIMARY_TASK_SET_OUTPUT
                    def createTaskSetOutput = readJSON(file: createTaskSetOutputFile)

                    def updatePrimaryTaskSetOutput = sh (
                        script: "aws ecs update-service-primary-task-set --service $SERVICE_ARN --cluster $CLUSTER_ARN --primary-task-set ${createTaskSetOutput.taskSetArn}",
                        returnStdout: true
                        ).trim()
                        echo "Upate Primary TaskSet Result: ${updatePrimaryTaskSetOutput}"
                        writeJSON(file: upatePrimaryTaskSetOutputFile, json: updatePrimaryTaskSetOutput, pretty: 2)
                }
            }
        }
    }
}