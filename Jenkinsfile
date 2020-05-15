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
                sh 'echo "..............................."'
                script {
                    sh 'export REGION=$(aws configure get region)'
                    readProperties(file: 'Makefile.env').each { key, value -> tv = value.replace("AWS_ACCOUNT_NUMBER", env.AWS_ACCOUNT_NUMBER)
                                                                              env[key] = tv.replace("REGION", env.REGION)
                                                              }
                    sh 'echo "..............................."'
                }
                sh 'echo "============================================="'
                sh 'printenv'
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
    }
}