#!/bin/bash

kubectl delete -f dev/
kubectl delete -f staging/
kubectl delete -f prod/
