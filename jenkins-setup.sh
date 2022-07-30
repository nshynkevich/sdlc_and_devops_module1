#!/bin/bash


JENKINS_NS_YAML="jenkins-namespace.yaml"
JENKINS_DEPLOY_YAML="jenkins-deployment.yaml"
JENKINS_SVC_YAML="jenkins-service.yaml"
JENKINS_PV_YAML="jenkins-persistentvolume.yaml"
JENKINS_SA_YAML="jenkins-serviceaccount.yaml"
# JENKINS_HELM_VALUES_YAML="jenkins-helm-values.yaml"

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

setup() {
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
        ports:
          - name: http-port
            containerPort: 8080
          - name: jnlp-port
            containerPort: 50000
        lifecycle:
          postStart:
            exec:
              command: ["/bin/sh", "-c", "echo 'nameserver 9.9.9.9' > /etc/resolv.conf ; echo 'search jenkins.svc.cluster.local svc.cluster.local cluster.local' >> /etc/resolv.conf ; echo 'nameserver 10.96.0.10' >> /etc/resolv.conf ; echo 'options ndots:5' >> /etc/resolv.conf"]
        securityContext:
          privileged: true
        volumeMounts:
          - name: jenkins-vol
            mountPath: /var/jenkins_home
      volumes:
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

remove() {
  kubectl delete -f "${JENKINS_DEPLOY_YAML}"
  kubectl delete -f "${JENKINS_SVC_YAML}"
  kubectl delete -f "${JENKINS_PV_YAML}"
  kubectl delete -f "${JENKINS_NS_YAML}"
}

setup
# remove


# echo "nameserver 9.9.9.9" > /etc/resolv.conf ; echo "search jenkins.svc.cluster.local svc.cluster.local cluster.local" >> /etc/resolv.conf ; echo "nameserver 10.96.0.10" >> /etc/resolv.conf ; echo "options ndots:5" >> /etc/resolv.conf
