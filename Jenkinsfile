import groovy.json.JsonOutput
import groovy.json.JsonSlurperClassic

pipeline {
    agent none
    parameters {
        string(name: 'awsProfile', defaultValue: 'cicd', description: 'The AWS profile name to resolve credentials.')
        string(name: 'awsAccountNumber', defaultValue: '', description: 'The AWS account number to use.')
    }
    environment { 
        AWS_PROFILE = "${params.awsProfile}"
        AWS_ACCOUNT_NUMBER = "${params.awsAccountNumber}"
    }
    stages {
        stage('Build') {
            agent any
            steps {
                echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
                sh 'whoami'
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

                    def registerTaskDefOutputFile = env.TEMPLATE_BASE_PATH + '/' + env.REGISTER_TASK_DEF_OUTPUT
                    echo "********************************"
                    sh 'pwd'
                    writeJSON(file: registerTaskDefOutputFile, json: registerTaskDefinitionOutput, pretty: 2)
                    echo "********************************${registerTaskDefOutputFile}"
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
                    def registerTaskDefOutputFile = env.TEMPLATE_BASE_PATH + '/' + env.REGISTER_TASK_DEF_OUTPUT

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

                    def registerTaskDefinitionOutput = readJSON(file: registerTaskDefOutputFile)
                    def taskSetTemplateJson = readJSON(file: taskSetTemplateFile)
                    taskSetTemplateJson.taskDefinition = registerTaskDefinitionOutput.taskDefinition.taskDefinitionArn
                    taskSetTemplateJson.loadBalancers[0].containerPort = env.APP_PORT.toInteger()
                    taskSetTemplateJson.loadBalancers[0].targetGroupArn = targetGroupArn
                    writeJSON(file: taskSetFile, json: taskSetTemplateJson, pretty: 2)

                    // register the task
                    def createTaskSetOutput = sh (
                    script: "aws ecs create-task-set --service $SERVICE_ARN --cluster $CLUSTER_ARN --cli-input-json file://${taskSetFile}",
                    returnStdout: true
                    ).trim()
                    echo "Create Task Set Result: ${createTaskSetOutput}"

                    writeJSON(file: createTaskSetOutputFile, json: createTaskSetOutput, pretty: 2)
                }
            }
        }
        stage('SwapTestListener'){
            agent any
            steps{
                script{
                    def blueTG = null
                    def greenTG = null
                    if ( env.NEXT_ENV == 'Green' ){
                        blueTG = ["Weight": 0, "TargetGroupArn": env.BLUE_TARGET_GROUP_ARN]
                        greenTG = ["Weight": 100, "TargetGroupArn": env.GREEN_TARGET_GROUP_ARN]
                    }
                    else{
                        blueTG = ["Weight": 100, "TargetGroupArn": env.BLUE_TARGET_GROUP_ARN]
                        greenTG = ["Weight": 0, "TargetGroupArn": env.GREEN_TARGET_GROUP_ARN]
                    }
                    def tgs = [blueTG, greenTG]


                    def listenerDefaultActionsTemplate = """
                        {
                            "ListenerArn": "$env.GREEN_TARGET_GROUP_ARN",
                            "DefaultActions": [
                                {
                                    "Type": "forward",
                                    "ForwardConfig": {
                                        "TargetGroups": ${JsonOutput.prettyPrint(JsonOutput.toJson(tgs))}
                                    }
                                }
                            ]
                        }
                    """
                    def testDefaultActionsFile = env.TEMPLATE_BASE_PATH + '/' + env.TEST_LISTENER_DEFAULT_ACTION_OUTPUT
                    
                    def listerDefaultActionJson = new JsonSlurperClassic().parseText(listenerDefaultActionsTemplate)

                    echo "==============================================="
                     echo "The formed rules: ${listerDefaultActionJson.toString()}"

                    writeJSON(file: testDefaultActionsFile, json: listerDefaultActionJson, pretty: 2)

                    // Call the api to perform the swap
                    def modifyTestListenerResult = sh (
                    script: "aws elbv2 modify-listener --listener-arn $GREEN_LISTENER_ARN --cli-input-json file://${testDefaultActionsFile}",
                    returnStdout: true
                    ).trim()
                    echo "The modify result: ${modifyTestListenerResult}"
                }
            }
        }
        stage ('ConfirmationStage') {
            agent any
            input {
                message "Ready to SWAP production?"
                ok "Yes, go ahead."
            }
            steps{
                echo "Moving on to perform SWAP ..................."
            }            
        }
        stage('SwapProd'){
            agent any
            steps{
                script{
                    def blueTG = null
                    def greenTG = null
                    if ( env.NEXT_ENV == 'Green' ){
                        blueTG = ["Weight": 0, "TargetGroupArn": env.BLUE_TARGET_GROUP_ARN]
                        greenTG = ["Weight": 100, "TargetGroupArn": env.GREEN_TARGET_GROUP_ARN]
                    }
                    else{
                        blueTG = ["Weight": 100, "TargetGroupArn": env.BLUE_TARGET_GROUP_ARN]
                        greenTG = ["Weight": 0, "TargetGroupArn": env.GREEN_TARGET_GROUP_ARN]
                    }
                    def tgs = [blueTG, greenTG]


                    def listenerDefaultActionsTemplate = """
                        {
                            "ListenerArn": "$env.BLUE_LISTENER_ARN",
                            "DefaultActions": [
                                {
                                    "Type": "forward",
                                    "ForwardConfig": {
                                        "TargetGroups": ${JsonOutput.prettyPrint(JsonOutput.toJson(tgs))}
                                    }
                                }
                            ]
                        }
                    """
                    // def listenerTemplateFile = env.TEMPLATE_BASE_PATH + '/' + env.LISTENER_ACTION_TEMPLATE_FILE
                    def defaultActionsFile = env.TEMPLATE_BASE_PATH + '/' + env.LISTENER_DEFAULT_ACTION_OUTPUT
                    
                    def listerDefaultActionJson = new JsonSlurperClassic().parseText(listenerDefaultActionsTemplate)

                    echo "==============================================="
                     echo "The formed rules: ${listerDefaultActionJson.toString()}"

                    writeJSON(file: defaultActionsFile, json: listerDefaultActionJson, pretty: 2)

                    // Call the api to perform the swap
                    def modifyProdListenerResult = sh (
                    script: "aws elbv2 modify-listener --listener-arn $BLUE_LISTENER_ARN --cli-input-json file://${defaultActionsFile}",
                    returnStdout: true
                    ).trim()
                    echo "The modify result: ${modifyProdListenerResult}"
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
                        script: "aws ecs update-service-primary-task-set --service $SERVICE_ARN --cluster $CLUSTER_ARN --primary-task-set ${createTaskSetOutput.taskSet.taskSetArn}",
                        returnStdout: true
                        ).trim()
                        echo "Upate Primary TaskSet Result: ${updatePrimaryTaskSetOutput}"
                        writeJSON(file: upatePrimaryTaskSetOutputFile, json: updatePrimaryTaskSetOutput, pretty: 2)
                }
            }
        }
        
        stage('DeleteDeployment'){
            agent any
            steps{
                script{
                    // Read the current task family
                    def taskDefFile = env.TEMPLATE_BASE_PATH + '/' + env.TASK_DEFINITION_FILE
                    def taskDefinition = readJSON(file: taskDefFile)
                    def currentTaskFamily = 'task-definition/' + taskDefinition.family

                    // Read all the TaskSets(deployments) for the cluster.
                    def describeClusterResult = sh (
                    script: "aws ecs describe-services --services $SERVICE_ARN --cluster $CLUSTER_ARN",
                    returnStdout: true
                    ).trim()
                    def clusterDetails = readJSON(text: describeClusterResult)

                    // Find the oldest TaskSet(deployment).
                    def oldestTime = new Date()
                    def taskDefArnToDeactivate = ''
                    def taskSetIdToDelete = ''

                    if (clusterDetails.services[0].taskSets.size() >= 5){
                        clusterDetails.services[0].taskSets.eachWithIndex { a, i -> createdAt = new Date((long)(a.createdAt*1000))
                        if (createdAt < oldestTime){
                            oldestTime = createdAt
                            taskDefArnToDeactivate = a.taskDefinition
                            taskSetIdToDelete = a.id

                            if (a.taskDefinition.contains(currentTaskFamily)){
                                // Uncomment to delete oldest TaskSet of the same family
                                // taskDefArnToDeactivate = a.taskDefinition
                                // taskSetIdToDelete = a.id
                            }
                        }
                    }
                    echo "This is oldest TastSet creation time: ${oldestTime}"
                    echo "This is TaskDefinition ARN to delete: ${taskDefArnToDeactivate}"
                    echo "This is StackSet id to delete: ${taskSetIdToDelete}"

                    // Delete the TaskSet(deployment)
                    def deleteTaskSetOutputFile = env.TEMPLATE_BASE_PATH + '/' + env.DELETE_TASK_SET_OUTPUT
                    def deleteTaskSetResult = sh (
                    script: "aws ecs delete-task-set --cluster $CLUSTER_ARN --service $SERVICE_ARN --task-set ${taskSetIdToDelete}",
                    returnStdout: true
                    ).trim()

                    writeJSON(file: deleteTaskSetOutputFile, json: deleteTaskSetResult, pretty: 2)
                    echo "Delete TaskSet: ${deleteTaskSetResult}"

                    // Deregister old TaskDefinition
                    def deregisterTaskDefOutputFile = env.TEMPLATE_BASE_PATH + '/' + env.DEREGISTER_TASK_DEF_OUTPUT
                    def deregisterTaskDefResult = sh (
                    script: "aws ecs deregister-task-definition --task-definition ${taskDefArnToDeactivate}",
                    returnStdout: true
                    ).trim()

                    writeJSON(file: deregisterTaskDefOutputFile, json: deregisterTaskDefResult, pretty: 2)
                    echo "Deregister TaskDefinition: ${deregisterTaskDefResult}"
                    }
                }
            }
        }
    }
}