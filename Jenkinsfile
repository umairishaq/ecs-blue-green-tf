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
                        templateFile = 'infrastructure/GreenTaskDefinition.template.json'
                    }
                    else {
                        templateFile = 'infrastructure/BlueTaskDefinition.template.json'
                    }

                    def taskDefinitionTemplate = readJSON(file: templateFile)
                    taskDefinitionTemplate.containerDefinitions[0].image = newImage
                    writeJSON(file: 'infrastructure/output.json', json: taskDefinitionTemplate)
                }
            }
        }
    }
}