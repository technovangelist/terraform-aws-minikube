#!/usr/bin/env bash

sudo apt-get update
sudo apt-get install -y \
    vim \
    httpie \
    jq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    conntrack \
    socat \
    containernetworking-plugins \
    software-properties-common docker.io

curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

sudo usermod -aG docker ubuntu


# helm
sudo snap install helm --classic



# minikube 

curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/

export PUBIP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
export PUBDNS=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
export FULLHOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/hostname)

# sudo minikube config set driver none
# sudo minikube start \
#     --apiserver-name=$PUBDNS \
#     --apiserver-port=58443 \
#     --extra-config=apiserver.cloud-provider=aws \
#     --extra-config=controller-manager.cloud-provider=aws \
#     --extra-config=kubelet.cloud-provider=aws \
#     --extra-config=kubeadm.node-name=$FULLHOSTNAME \
#     --extra-config=kubelet.hostname-override=$FULLHOSTNAME
    
minikube start --vm-driver=none

minikube addons enable metallb
minikube addons enable metrics-server


# rename context
kubectl config rename-context minikube aws-minikube

# ingress with hostports
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add stable https://charts.helm.sh/stable
helm repo update
helm install ingress ingress-nginx/ingress-nginx --set controller.hostPort.enabled=true

# delete standard storageclass
# TODO: fix storage - 777 perms are invalid for some apps
kubectl annotate sc standard storageclass.kubernetes.io/is-default-class-

cat << EOF | kubectl apply -f-
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: gp2
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
  fsType: ext4 
EOF

# aws labels

kubectl label node --all failure-domain.beta.kubernetes.io/region=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
kubectl label node --all failure-domain.beta.kubernetes.io/zone=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .availabilityZone)
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl label nodes --all node-role.kubernetes.io/master-

# metallb
TMPCM=$(mktemp)
cat <<EOF > $TMPCM
address-pools:
- name: default
  protocol: layer2
  addresses:
  - ${PUBIP}-${PUBIP}
EOF

kubectl create configmap config --from-file=config=$TMPCM --dry-run=client -o yaml | \
    kubectl apply -f- -n metallb-system
kubectl delete pod -lapp=metallb -n metallb-system
