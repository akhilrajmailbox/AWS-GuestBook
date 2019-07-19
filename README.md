# GuestBook Installation and Configuration on AWS K8s

## Requirement

1. Kubernetes version : 1.8+   # [metrics-server](https://github.com/kubernetes-incubator/metrics-server) configured here support kubernetes version 1.8 or higher.

2. Local system requirement
   * aws cli
   * kubectl
   * wget
   * cut
   * grep


## Configure AWS CLI in local system
```
aws configure
```

[reference](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)


## Install kubectl in aws cli

Kubernetes uses a command line utility called kubectl for communicating with the cluster API server.

*You must use a kubectl version that is within one minor version difference of your Amazon EKS cluster control plane . For example, a 1.11 kubectl client should work with Kubernetes 1.10, 1.11, and 1.12 clusters...*

[reference](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html)


## Create EKS Cluster from AWS Console

create a kubeconfig file for your cluster
```
aws eks --region region update-kubeconfig --name cluster_name
```
[reference](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html)


## WOrkerNode Configuration for AWS EKS
Add the workernodes by using Cloudformation [templates](https://amazon-eks.s3-us-west-2.amazonaws.com/cloudformation/2019-02-11/amazon-eks-nodegroup.yaml).

Launch an Auto Scaling group of worker nodes that register with your Amazon EKS cluster. After the nodes join the cluster, you can deploy Kubernetes applications to them.

[reference](https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html)

### To enable worker nodes to join your cluster
configure aws-auth-cm.yaml in the cluster

-Important-
*Do not modify any other lines in this file.*


```
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: <ARN of instance role (not instance profile)>
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
```

Apply the configuration. This command may take a few minutes to finish.

```
kubectl apply -f aws-auth-cm.yaml
```

## Deployment Script

use the guestbook.sh script under scripts folder to configure the complete setup.....!

```
./guestbook.sh -o [options]
```

 + guestbook.sh options
```
      * metrics-server       =   Deploy metrics-server in kubernetes Cluster
      * ingress-controller   =   Install and configure Nginx Ingress controller
      * stage-deploy         =   Deployment of GuestBook in staging Environment
      * prod-deploy          =   Deployment of GuestBook in production Environment
      * autoscaler           =   autoscale configuration for guestbook deployment
      * load-test            =   load test for guestbook deployment to check autoscale configuration
      * cleanup              =   delete all resources in the kubernetes which are created by this scripts for the guestbook
```
