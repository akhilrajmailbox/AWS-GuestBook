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


## Install kubectl

Kubernetes uses a command line utility called kubectl for communicating with the cluster API server.

*You must use a kubectl version that is within one minor version difference of your Amazon EKS cluster control plane . For example, a 1.11 kubectl client should work with Kubernetes 1.10, 1.11, and 1.12 clusters...*

[reference](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html)


## Create EKS Cluster from AWS Console

create a kubeconfig file for your cluster
```
aws eks --region region update-kubeconfig --name cluster_name
```
[reference](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html)


## WorkerNode Configuration for AWS EKS
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

use the [guestbook.sh](https://raw.githubusercontent.com/akhilrajmailbox/AWS-GuestBook/master/scripts/guestbook.sh) script under scripts folder to configure the complete setup.....!

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




## Result

In AWS, we will not get the IPAddress for the loadbalacer, they will give us a domain url.
from that domain url, we can take the IP Address

example :
```
nslookup a7dsdac78aa3911e9b5ca12ef48a2027-1678414529.us-east-1.elb.amazonaws.com
```
Assume that the output for above command is "34.198.50.73"
Add the following entries in "/etc/hosts" file in order to resolve the domain name from your lolca system.

```
34.198.50.73    staging-guestbook.mstakx.io
34.198.50.73    guestbook.mstakx.io
```

1. What was the node size chosen for the Kubernetes nodes? And why?

I choose 2 nodes (t3.medium -- 2 VCPU * 4 GB) in different zone.
The main reason why I choose 2 worker Node for HA Configuration, ie) even one zone goes down completely, our application will serve without any issue because of the second zone.

For 1 environment resource usage :
frontend * 3   ==  100m * 3 = 300m
redis-master   ==  100m * 1 = 100m
redis-slave    ==  100m * 2 = 200m

overall CPU Usage : 600m + 200m (Kubernetes usage) = 800m

like this we have one more environment. (staging and production).
so overall CPU usage is :: 800m * 2 = 1600m

we have to configure autoscaler for both environment and I configured the autoscaler with min 3 pods and maximum 10 pods.
Under consideration of this auto scaling Configuration, 2 VCPU is sufficient and fair enough for this application.


2. What method was chosen to install the demo application and ingress controller on the cluster, justify the method used

I choose default installation method (yaml file configuration and deployment with kubectl command). with help of Helm chart we can install and configure the applications and there are many preconfigured charts are available.
But for customization and automation, as per my understanding direct installation method is better than helm installation.


3. What would be your chosen solution to monitor the application on the cluster and why?

for the Kubernetes cluster monitor, I will choose Prometheus
because Prometheus is highly updated for Kubernetes monitoring and we can get end to end resource usage details about our cluster in different level such as pods, deployment, daemon-sets, replica-sets etc...
Apart from this if any custom monitoring required and if that is a black-box monitoring, then i will configure Nagios as well.


4. What additional components / plugins would you install on the cluster to manage it better?

Prometheus and Granada for monitoring.
EFK (Elasticsearch, Fluentd and Kibana) for logging.
rancher for better ui experience and marketplace application deployment.
helm for installation of predefined applications as charts.



