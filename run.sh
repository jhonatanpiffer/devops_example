#!/bin/bash


#Create Bucket to store Terraform State

#Generate SSH keys
ssh-keygen -f terraform/aws_key

#Install the Kubernetes Cluster
cd terraform/
terraform init
terraform apply -auto-approve
cd ..

#Get Access to configured cluster
aws eks --region $(terraform output -raw region) update-kubeconfig \
    --name $(terraform output -raw cluster_name)

#Install Argocd
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

#Install Argocd Cli
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

#Open to web
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
argocd admin initial-password -n argocd


