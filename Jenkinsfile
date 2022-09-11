pipeline {
  environment {
    user = "nshynkevich"
    repo = "devsecops"
    imagetag= "module1_VulnerableApp"
    registryCredential = 'dockerhub'
    dockerImage = ''
    my_own_project_key = "sqa_ffa83427193399de6f31784a83590f5e674ff51c"
  }

  agent any

  stages {

    stage('Checkout Source') {
      steps {
        git url:'https://github.com/SasanLabs/VulnerableApp.git', branch:'master'
      }
    }

    stage('SonarQube analysis') {

      steps {
        withSonarQubeEnv(installationName: 'SonarQubeVM1') {
          sh "./gradlew sonarqube \
                  -Dsonar.host.url=${env.SONAR_HOST_URL} \
                  -Dsonar.login=${env.SONAR_AUTH_TOKEN} \
                  -Dsonar.projectKey=${my_own_project_key} \
                  -Dsonar.projectName='vulnapp' \
                  -Dsonar.projectVersion=${BUILD_NUMBER}"
        }
      }
    }

    stage('Build App with gradle') {
      steps {
        script {
          sh '/opt/gradle/gradle-7.5/bin/gradle bootJar'
        }
      }
    }

    stage('Create app Dockerfile') {
      steps {
        script {
          def vulnapp_dockerfile_content = '''
FROM openjdk:8-alpine

ADD build/libs/VulnerableApp-1.0.0.jar /VulnerableApp-1.0.0.jar

WORKDIR /

EXPOSE 9090

CMD java -jar /VulnerableApp-1.0.0.jar

'''
          writeFile file: 'Dockerfile', text: vulnapp_dockerfile_content

        }
      }
    }

 /* stage('Docker Build') {
      agent any
      steps {
        sh 'docker build -t nshynkevich/devsecops:module1_VulnerableApp .'
      }
    }
*/

    stage("Build image") {
      steps {
        script {
          //myapp = docker.build("user/repo:${env.BUILD_ID}")
          dockerImage = docker.build "${user}/${repo}:${env.imagetag}_${env.BUILD_ID}"
        }
      }
    }

    stage("Push image") {
      steps {
        script {
          docker.withRegistry('', 'dockerhub') {
            dockerImage.push("${env.imagetag}_${env.BUILD_ID}")
            dockerImage.push("${env.imagetag}_latest")
            //  myapp.push("${env.BUILD_ID}")
          }
        }
      }
    } 

    stage('Create app .yaml file for k8s') {
      steps {
        script {
          def vulnapp_yaml_content = '''
---
apiVersion: v1
kind: Namespace
metadata:
  name: vulnapp

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vulnapp
  namespace: vulnapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vulnapp
  template:
    metadata:
      name: vulnapp-pod
      labels:
        app: vulnapp
    spec:
      containers:
      - name: vulnapp-container
        image: ''' + "${user}/${repo}:${imagetag}_latest" + '''
        imagePullPolicy: Always
        ports:
        - containerPort: 9090
---
apiVersion: v1
kind: Service
metadata:
  name: vulnapp-svc
  namespace: vulnapp
  labels:
    app: vulnapp
spec:
  selector:
    app: vulnapp
  type: NodePort
  ports:
  - nodePort: 30001
    port: 9090
    targetPort: 9090
'''
          writeFile file: 'vulnapp.yaml', text: vulnapp_yaml_content
          sh 'ls -l vulnapp.yaml'
          sh 'cat vulnapp.yaml'

        }
      }
    }

    stage('Deploy App to k8s') {
      steps {
        script {
          kubernetesDeploy(configs: "vulnapp.yaml", kubeconfigId: "kubeconfig")
        }
      }
    }

  }

}
