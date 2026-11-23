#!/bin/bash

set -euo pipefail

kubectl apply -f dev/namespace.yaml
kubectl apply -f prod/namespace.yaml
kubectl apply -f staging/namespace.yaml

kubectl apply -f dev/
kubectl apply -f staging/
kubectl apply -f prod/

kubectl rollout status deployment/api -n staging --timeout 100s
kubectl rollout status deployment/api -n dev --timeout 100s
kubectl rollout status deployment/api -n prod --timeout 100s