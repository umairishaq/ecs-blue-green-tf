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
                // script {
                    // readProperties(file: 'Makefile.env').each { key, value -> tv = value.replace("AWS_ACCOUNT_NUMBER", env.AWS_ACCOUNT_NUMBER)
                    //                                                           env[key] = tv.replace("REGION", env.REGION)
                                                            //   }
                    // sh 'echo "..............................."'
                // }
                sh '$(aws ecr get-login --no-include-email --registry-ids $AWS_ACCOUNT_NUMBER)'
                sh 'echo "..............................."'
                script {
                    def PUSH_RESULT = sh (
                    script: "make push-image",
                    returnStdout: true
                    ).trim()
                    echo "Push result: ${PUSH_RESULT}"
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
                    taskDefinitionTemplate.containerDefinitions[0].image = newImage
                    taskDefinitionTemplate.containerDefinitions[0].portMappings[0].containerPort = env.APP_PORT
                    taskDefFile = env.TEMPLATE_BASE_PATH + env.TASK_DEFINITION_FILE
                    writeJSON(file: taskDefFile, json: taskDefinitionTemplate)
                    
                    def registerTaskDefinitionOutput = sh (
                    script: "aws ecs register-task-definition --cli-input-json file://$TEMPLATE_BASE_PATH/$TASK_DEFINITION_FILE",
                    returnStdout: true
                    ).trim()
                    registerTaskDefOutput = env.TEMPLATE_BASE_PATH + '/' + env.REGISTER_TASK_DEF_OUTPUT
                    writeJSON(file: registerTaskDefinitionOutput, json: registerTaskDefinitionOutput, pretty: 2)
                }
            }
        }
    }
}