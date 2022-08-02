pipeline {

  agent any

  stages {

    stage('Checkout Source') {
      steps {
        git url:'https://github.com/SasanLabs/VulnerableApp.git', branch:'master'
      }
    }

   /* stage('Build App with gradle') {
      steps {
        script {
          sh '/opt/gradle/gradle-7.5/bin/gradle bootJar'
          sh 'mv /var/jenkins_home/workspace/vulnapp-k8s-deploy/build/libs/VulnerableApp-1.0.0.jar /VulnerableApp-1.0.0.jar'
        }
      }
    }
*/

    stage('Create app Dockerfile') {
      steps {
        script {
          def vulnapp_dockerfile_content = '''
FROM java:8

WORKDIR /

ADD /VulnerableApp-1.0.0.jar VulnerableApp-1.0.0.jar

EXPOSE 9090

CMD java -jar VulnerableApp-1.0.0.jar

'''
          writeFile file: 'Dockerfile', text: vulnapp_dockerfile_content
          sh 'ls -l Dockerfile'
          sh 'cat Dockerfile'

        }
      }
    }
/*
    stage("Build image") {
      steps {
        script {
          //myapp = docker.build("user/repo:${env.BUILD_ID}")
          myapp = docker.build("nshynkevich/devsecops:module1_VulnerableApp")
        }
      }
    }

    stage("Push image") {
      steps {
        script {
          docker.withRegistry('https://registry.hub.docker.com', 'dockerhub') {
            myapp.push("latest")
            //  myapp.push("${env.BUILD_ID}")
          }
        }
      }
    } 
*/
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
        image: nshynkevich/devsecops:module1_VulnerableApp
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
