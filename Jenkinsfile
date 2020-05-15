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
                    sh 'echo "============================================="'
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
                        echo 'Greeeeeeeeeen'
                        templateFile =  env.TEMPLATE_BASE_PATH + '/GreenTaskDefinition.template.json'
                    }
                    else {
                        templateFile = env.TEMPLATE_BASE_PATH +'/BlueTaskDefinition.template.json'
                    }

                    def taskDefinitionTemplate = readJSON(file: templateFile)
                    taskDefinitionTemplate.containerDefinitions[0].image = newImage
                    taskDefinitionTemplate.containerDefinitions[0].portMappings[0].containerPort = env.APP_PORT
                    writeJSON(file: env.TASK_DEFINITION_FILE, json: taskDefinitionTemplate)
                    
                    // def registerTaskDefinitionOutput = sh (
                    // script: "aws ecs register-task-definition --cli-input-json file://$TASK_DEFINITION_FILE",
                    // returnStdout: true
                    // ).trim()
                    // writeJSON(file: env.TEMPLATE_BASE_PATH + '/taskdefout.json', json: registerTaskDefinitionOutput, pretty: 2)
                }
            }
        }
    }
}