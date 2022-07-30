#!/bin/bash

[ `id -u` -ne 0 ] && exit 1
kubeadm init --apiserver-advertise-address 192.168.66.100 --pod-network-cidr=10.200.0.0/16

# gives help strings
# sudo kubeadm join 192.168.66.100:6443 --token uc7uxt.pynieo6yhvexlhtv	--discovery-token-ca-cert-hash sha256:9af6ca8bb2ba4d7407de00b86ea128ad3dddeaee1ef060dc9bae401e89038b4a
mkdir -p $HOME/.kube && cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && chown $(id -u):$(id -g) $HOME/.kube/config

# Now list nodes gives only one which is master by
# `kubectl get nodes`, its 'STATUS' is NotReady.
# Simply because we did not apply any network plugin.
# flannel will be used
wget -q -O- https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml| sed s'~^[ \t]*"Network":.*~      "Network": "10.200.0.0/16",~' > kube-flannel.yaml
kubectl apply -f kube-flannel.yaml

kubectl get cs
# if scheduler and/or controller unhealthy
# In /etc/kubernetes/manifests/kube-scheduler.yaml :
# Clear the line (spec->containers->command) containing this phrase:  -- port=0
# In /etc/kubernetes/manifests/kube-controller-manager.yaml :
# Clear the line (spec->containers->command) containing this phrase: --- port=0
# And
# systemctl restart kubelet.service

# # Install Helm
# curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
# sudo apt-get install apt-transport-https --yes
# echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
# sudo apt-get update
# sudo apt-get install helm
