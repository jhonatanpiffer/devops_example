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

#Get Access to configured cluster
aws eks --region $region update-kubeconfig --name $cluster_name

#Install Argocd
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

#Install Argocd Cli
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

#Open to web
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

#Get initial Argocd Admin
argocd_password=$(argocd admin initial-password -n argocd | head -n 1)
argocd_hostname=$(kubectl get svc/argocd-server -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}')
argocd login --name admin --password $argocd_password $argocd_hostname

#Creating a application
kubectl config set-context --current --namespace=argocd
argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default
argocd app get guestbook

#Pushing image
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $repository_url
docker images
docker tag 2f4a78a7512d "${repository_url}:current"
docker images
docker push "${repository_url}:current"

