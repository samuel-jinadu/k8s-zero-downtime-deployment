#!/bin/bash

kubectl apply -f dev/deployment.yaml
kubectl apply -f dev/service.yaml

kubectl rollout status deployment/api --timeout 100s

# Forward the service port to your local machine
kubectl port-forward svc/api-svc 8080:8080