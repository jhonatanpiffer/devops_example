#!/bin/bash

#Create Bucket to store Terraform State

#Generate SSH keys
#ssh-keygen -f terraform/aws_key

#Install the Kubernetes Cluster
cd terraform/
terraform init
terraform apply -auto-approve

region="$(terraform output -raw region)"
cluster_name="$(terraform output -raw cluster_name)"
repository_url="$(terraform output -raw repository_url)"
cd ..

app_repo_url="https://github.com/jhonatanpiffer/devops_example.git"

#Get Access to configured cluster
aws eks --region $region update-kubeconfig --name $cluster_name

#Install Argocd
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

#Install Argocd Cli
if [ ! -f /usr/local/bin/argocd ]
  curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
  rm argocd-linux-amd64
fi

#Open to web
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

#Get initial Argocd Admin
argocd_password=$(argocd admin initial-password -n argocd | head -n 1)
argocd_hostname=$(kubectl get svc/argocd-server -n argocd -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}')
argocd login --username admin --password $argocd_password $argocd_hostname

#Creating a application
kubectl config set-context --current --namespace=argocd
argocd app create deel-reverse-ip --repo $app_repo_url --path helm --dest-server https://kubernetes.default.svc --dest-namespace default
argocd app sync deel-reverse-ip
argocd app get deel-reverse-ip

#Pushing image
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $repository_url
docker images
docker tag 2f4a78a7512d "${repository_url}:current"
docker images
docker push "${repository_url}:current"

#Install Cert Manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
kubectl apply -f cert-manager/test-resources.yaml
kubectl describe certificate -n cert-manager-test
kubectl delete -f cert-manager/test-resources.yaml
