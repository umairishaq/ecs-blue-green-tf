pipeline {
    agent none
    stages {
        stage('Build') {
            agent none
            environment {
                IMAGE_NAME = 'an_awesome_app'
                IMAGE_TAG = $GIT_COMMIT
            }
            steps {
                sh 'echo $GIT_COMMIT'
                sh 'echo "============================================="'
                sh 'docker build -t $IMAGE_NAME:$IMAGE_TAG ./src/'
            }
        }
        stage('ECR-Push') {
            agent none
            steps {
                sh 'aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_NUMBER.dkr.ecr.$AWS_REGION.amazonaws.com/$IMAGE_NAME'
                sh 'docker tag $IMAGE_NAME:$IMAGE_TAG $AWS_ACCOUNT_NUMBER.dkr.ecr.$AWS_REGION.amazonaws.com/$IMAGE_NAME:$IMAGE_TAG'
                sh 'docker push $AWS_ACCOUNT_NUMBER.dkr.ecr.$AWS_REGION.amazonaws.com/$IMAGE_NAME:$IMAGE_TAG'
            }
        }
    }
}