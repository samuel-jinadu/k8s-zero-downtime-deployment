#!/bin/bash

kubectl delete -f dev/deployment.yaml
kubectl delete -f dev/service.yaml
kubectl delete -f dev/configmap.yaml
