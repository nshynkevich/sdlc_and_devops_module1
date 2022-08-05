#!/bin/bash


JENKINS_NS_YAML="jenkins-namespace.yaml"
JENKINS_DEPLOY_YAML="jenkins-deployment.yaml"
JENKINS_SVC_YAML="jenkins-service.yaml"
JENKINS_PV_YAML="jenkins-persistentvolume.yaml"
JENKINS_SA_YAML="jenkins-serviceaccount.yaml"
# JENKINS_HELM_VALUES_YAML="jenkins-helm-values.yaml"


install_kubernetes_cd_plugin() {
  cd /tmp 
  wget https://updates.jenkins.io/download/plugins/kubernetes-cd/1.0.0/kubernetes-cd.hpi
  wget http://192.168.66.100:8080/jnlpJars/jenkins-cli.jarhttp://192.168.66.100:8080/jnlpJars/jenkins-cli.jar
  java -jar jenkins-cli.jar -s http://192.168.66.100:8080/ install-plugin kubernetes-cd.hpi
}

install_gradle_bin() {
  cd /tmp
  wget https://services.gradle.org/distributions/gradle-7.5-bin.zip
  mkdir /opt/gradle
  unzip -d /opt/gradle gradle-7.5-bin.zip
  ls /opt/gradle/gradle-7.5
}

chkexit() {
  code="$1"
  msg="$2"

  if [ $code -eq 0 ]; then
    echo " $msg .. OK "
  else
    echo " $msg .. FAIL "
    exit 1

  fi
}

setup1() {


echo "Installing Jenkins .. "

echo "START" >> /tmp/status.txt
sudo chmod 777 /tmp/status.txt
# config jenkins installer on ubuntu
sudo add-apt-repository ppa:webupd8team/java -y
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -

# config java8 installer on ubuntu
sudo sh -c 'echo "deb https://pkg.jenkins.io/debian binary/" >> /etc/apt/sources.list'
echo debconf shared/accepted-oracle-license-v1-1 select true | \
sudo debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | \
sudo debconf-set-selections

echo "CONFIG DONE" >> /tmp/status.txt 
sudo apt-get update  >> /tmp/status.txt

# apt-get install java and jenkins
sudo apt-get -y install oracle-java8-installer  >> /tmp/status.txt
sudo apt-get -y install jenkins  >> /tmp/status.txt

echo "APT-GET INSTALL DONE" >> /tmp/status.txt

# wait for jenkins start up
response=""
key=""
while [ `echo $response | grep 'Authenticated' | wc -l` = 0 ]; do
  sudo find / -name initialAdminPassword -type f >/dev/null
  key=`sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
  echo $key >> /tmp/status.txt
  response=`sudo java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080 who-am-i --username admin --password $key`
  sudo echo $response
  sudo echo "Jenkins not started, wait for 2s"
  sleep 2
done >> /tmp/status.txt
echo "Jenkins started" >> /tmp/status.txt
echo "Install Plugins" >> /tmp/status.txt

# install plugins with jenkins-cli
for package in ant blueocean blueocean-autofavorite build-timeout email-ext ghprb gradle jacoco workflow-aggregator pipeline-github-lib sbt ssh-slaves subversion timestamper ws-cleanup; do sudo sh -c "sudo java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080 install-plugin $package --username admin --password $key >> /tmp/status.txt"; done;  

echo "PLUGINS INSTALL DONE" >> /tmp/status.txt

# restart jenkins
/etc/init.d/jenkins restart  >> /tmp/status.txt

echo "ALL DONE" >> /tmp/status.txt


}

setup() {
  JENKINS_USER_NAME="admin"
  JENKINS_USER_PASSWORD="admin"

  echo "Installing Jenkins .. "

  mkdir $HOME/jenkins_installation
  cd $HOME/jenkins_installation

  apt update 
  apt install gnupg iproute2 wget git -y
  wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | apt-key add -
  sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

  apt update
  apt install openjdk-8-jdk -y
  chkexit $? "openjdk-8-jdk install"

  apt install jenkins -y
  chkexit $? "jenkins install"
  java -version
  #cat /var/lib/jenkins/secrets/initialAdminPassword 

  wget -q https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.11.1/jenkins-plugin-manager-2.11.1.jar -O /opt/jenkins-plugin-manager.jar
  wget -q http://127.0.0.1:8080/jnlpJars/jenkins-cli.jar -O /opt/jenkins-cli.jar

  export JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

  service jenkins restart

  cat > $HOME/jenkins_installation/plugins.txt <<EOF
docker-plugin:1.0.0
docker-workflow:1.0
docker-build-step:2.8
kubernetes-cd:2.3.1
EOF

  [ ! -d /usr/share/jenkins/ref ] && mkdir -p /usr/share/jenkins/ref
  cp $HOME/jenkins_installation/plugins.txt /usr/share/jenkins/ref/plugins.txt

  init_key=`cat /var/lib/jenkins/secrets/initialAdminPassword`
    echo $init_key
    response=`java -jar /opt/jenkins-cli.jar -s http://localhost:8080 -auth admin:$init_key who-am-i`
    echo $response

  echo "Install Jenkins user credentials: $JENKINS_USER_NAME:$JENKINS_USER_PASSWORD"
  echo 'jenkins.model.Jenkins.instance.securityRealm.createAccount("'$JENKINS_USER_NAME'", "'$JENKINS_USER_PASSWORD'")' | java -jar /opt/jenkins-cli.jar -s http://localhost:8080/ -auth admin:$init_key groovy =

  echo "Installing Jenkins Plugins .. "
  #java -jar /opt/jenkins-cli.jar -s http://localhost:8080/ -auth admin:$JENKINS_USER_PASSWORD install-plugin <plugin.hpi> -deploy
  java -jar /opt/jenkins-plugin-manager.jar --plugin-file /usr/share/jenkins/ref/plugins.txt

  echo "List of installed plugins: "
  #java -jar /opt/jenkins-cli.jar -s http://localhost:8080 -auth admin:$JENKINS_USER_PASSWORD list-plugins
  java -jar /opt/jenkins-plugin-manager.jar -l

  usermod -aG docker jenkins


}

remove() {
  echo "Removing Jenkins .. "
}

k8s_setup() {
  # Create a ns to segregate Jenkins objects within the k8s cluster
  echo -e "Create '${JENKINS_NS_YAML}' .. "
  cat >"${JENKINS_NS_YAML}" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: jenkins
EOF
  kubectl apply -f $JENKINS_NS_YAML
  chkexit $? "Apply '${JENKINS_NS_YAML}'"
  
  mkdir -p /data/jenkins-volume/
  chown -R 1000:1000 /data/jenkins-volume
  
  # Create a pv to store Jenkins data (preserve data across restarts).
  echo -e "Create '${JENKINS_PV_YAML}' .. "
  cat >"${JENKINS_PV_YAML}" <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jenkins-pv
  labels:
    type: local
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 10Gi
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: "/data/jenkins-volume"

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-pvc
  namespace: jenkins
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
EOF
  kubectl apply -f $JENKINS_PV_YAML
  chkexit $? "Apply '${JENKINS_PV_YAML}'"

  # Create jenkins config yaml.
  cat >"${JENKINS_DEPLOY_YAML}" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      securityContext:
        runAsUser: 0
        fsGroup: 0
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts
        env:
        - name: JENKINS_URL
          value: "http://192.168.66.100:8080/"
        - name: GRADLE_HOME
          value: /opt/gradle/gradle-7.5
        ports:
          - name: http-port
            containerPort: 8080
          - name: jnlp-port
            containerPort: 50000
        lifecycle:
          postStart:
            exec:
              command: ["/bin/sh", "-c", "echo 'nameserver 9.9.9.9' > /etc/resolv.conf ; echo 'search jenkins.svc.cluster.local svc.cluster.local cluster.local' >> /etc/resolv.conf ; echo 'nameserver 10.96.0.10' >> /etc/resolv.conf ; echo 'options ndots:5' >> /etc/resolv.conf; cd /tmp; curl -LO https://services.gradle.org/distributions/gradle-7.5-bin.zip; mkdir /opt/gradle; unzip -d /opt/gradle gradle-7.5-bin.zip"]
        securityContext:
          privileged: true
        volumeMounts:
          - name: jenkins-vol
            mountPath: /var/jenkins_home
          - name: docker-socket
            mountPath: /var/run
      volumes:
        - name: docker-socket
          emptyDir: {}
        - name: jenkins-vol
          persistentVolumeClaim:
            claimName: jenkins-pvc
EOF
  kubectl apply -f $JENKINS_DEPLOY_YAML
  chkexit $? "Apply '${JENKINS_DEPLOY_YAML}'"
  # command: ["/bin/sh"]
  # args: ["-c", "curl -s -k https://downloads.gradle-dn.com/distributions/gradle-7.5-bin.zip -o /tmp/gradle-7.5-bin.zip; mkdir -p /var/jenkins_home/gradle; unzip -d /var/jenkins_home/gradle /tmp/gradle-7.5-bin.zip; ls /var/jenkins_home/gradle"]

  cat >"${JENKINS_SVC_YAML}" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: jenkins
spec:
  type: NodePort
  ports:
    - port: 8080
      targetPort: 8080
      nodePort: 30000
  selector:
    app: jenkins

---

apiVersion: v1
kind: Service
metadata:
  name: jenkins-jnlp
  namespace: jenkins
spec:
  type: ClusterIP
  ports:
    - port: 50000
      targetPort: 50000
  selector:
    app: jenkins
EOF
  kubectl apply -f $JENKINS_SVC_YAML
  chkexit $? "Apply '${JENKINS_SVC_YAML}'"

  # jenkins_pod_name=$(kubectl get pods --namespace jenkins -l "app=jenkins" -o jsonpath="{.items[0].metadata.name}")
  # echo -e "Port-forward from ${jenkins_pod_name}:8080"
  # kubectl --namespace jenkins port-forward $jenkins_pod_name 8080:8080
  
  # jenkins_pod_name=$(kubectl get pods --namespace jenkins -l "app=jenkins" -o jsonpath="{.items[0].metadata.name}"); kubectl exec -it $jenkins_pod_name -n jenkins -- /bin/bash
  
  
  echo -e "Waiting for k8s starts Jenkins .. \nForward service/jenkins 8080:8080 .. "
  echo -e "Do:\nsudo kubectl port-forward --address 0.0.0.0 service/jenkins 8080:8080 -n jenkins"
  # sleep 2m; kubectl port-forward --address 0.0.0.0 service/jenkins 8080:8080 -n jenkins
  # admin:bd7f46e968ef419c9b7b0bae1be670a1 e.g from /var/jenkins_home/secrets/initialAdminPassword
  
  # sed -i 's/<useSecurity>true<\/useSecurity>/<useSecurity>false<\/useSecurity>/g' /var/jenkins_home/config.xml
  # sed -i 's/<useSecurity>true<\/useSecurity>/<useSecurity>false<\/useSecurity>/g' /var/jenkins_home/users/admin_8991272012169408268/config.xml
}

k8s_remove() {
  kubectl delete -f "${JENKINS_DEPLOY_YAML}"
  kubectl delete -f "${JENKINS_SVC_YAML}"
  kubectl delete -f "${JENKINS_PV_YAML}"
  kubectl delete -f "${JENKINS_NS_YAML}"
}

setup
