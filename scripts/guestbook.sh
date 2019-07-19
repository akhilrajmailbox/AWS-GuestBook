#!/bin/bash
export K8S_NAMESPACE=$3
export CPU_PERCENT=$4
export WAIT_TIME=$4

function pre-check() {
   SCRIPT_DIR=`dirname $0`
   echo "Moving to directory $SCRIPT_DIR"
   cd $SCRIPT_DIR
}


function guestbook-help() {
cat << EOF
_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_
DEVOPS_NOTICE ::

./guestbook.sh -o [options]

Optins :

    metrics-server       =   Deploy metrics-server in kubernetes Cluster
    ingress-controller   =   Install and configure Nginx Ingress controller
    stage-deploy         =   Deployment of GuestBook in staging Environment
    prod-deploy          =   Deployment of GuestBook in production Environment
    autoscaler           =   autoscale configuration for guestbook deployment
    load-test            =   load test for guestbook deployment to check autoscale configuration
    cleanup              =   delete all resources in the kubernetes which are created by this scripts for the guestbook
_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_
EOF
}

function metrics-server() {
        echo "configuring metrics-server in kubernetes"
	kubectl apply -f ../metrics-server/
}


function ingress-controller() {
    kubectl apply -f ../ingress-controller/ingress-nginx.yaml
    kubectl apply -f ../ingress-controller/ingress-service.yaml

    external_ip=""
    while [ -z $external_ip ]; do
        sleep 10
        echo "Waiting for ingress up and running...!"
        external_ip=$(kubectl get services -n ingress-nginx ingress-nginx --template='{{range .status.loadBalancer.ingress}}{{.hostname}}{{printf "\n"}}{{end}}')
    done

    echo "AWS gives you a domain name for the loadBalancer, convert it to ip address and add it in /etc/hosts"
    echo ""
    echo "run the following command to get the IPAddress : nslookup $external_ip"
}



function deploy-guestbook() {
    if [[ ! -z ${K8S_NAMESPACE} ]] ; then

        # create namespaces
        kubectl create ns ${K8S_NAMESPACE}

        # configure redis master
        kubectl -n ${K8S_NAMESPACE} apply -f ../Guestbook/Deployment/redis-master-deployment.yaml
        kubectl -n ${K8S_NAMESPACE} apply -f ../Guestbook/Service/redis-master-service.yaml

        # configure redis slave
        kubectl -n ${K8S_NAMESPACE} apply -f ../Guestbook/Deployment/redis-slave-deployment.yaml
        kubectl -n ${K8S_NAMESPACE} apply -f ../Guestbook/Service/redis-slave-service.yaml

        # configure guestbook
        kubectl -n ${K8S_NAMESPACE} apply -f ../Guestbook/Deployment/guestbook-frontend-deployment.yaml
        kubectl -n ${K8S_NAMESPACE} apply -f ../Guestbook/Service/guestbook-frontend-service.yaml

        # configure ingress
        kubectl -n ${K8S_NAMESPACE} apply -f ../Guestbook/Ingress/${K8S_NAMESPACE}-ingress.yaml

    else
        echo "K8S_NAMESPACE need to provide...!, task aborting...!"
        exit 1
    fi
}


function autoscaler() {
    if [[ ! -z ${K8S_NAMESPACE} ]] && [[ ! -z ${CPU_PERCENT} ]] ; then
        if [[ ${CPU_PERCENT} =~ ^-?[0-9]+$ ]] ; then
            if [[ ${CPU_PERCENT} -gt 0 ]] && [[ ${CPU_PERCENT} -lt 100 ]] ; then
                kubectl -n ${K8S_NAMESPACE} autoscale deployment frontend --cpu-percent=${CPU_PERCENT} --min=3 --max=10
                #kubectl -n ${K8S_NAMESPACE} get hpa
            else
                echo "CPU_PERCENT must be between 0 and 100"
                exit 1
            fi
        else
            echo "$CPU_PERCENT is not an integer...."
            echo "CPU_PERCENT must be between 0 and 100"
            echo "Task aborting...!"
            exit 1
        fi
    else
cat << EOF

K8S_NAMESPACE and CPU_PERCENT need to provide...!, task aborting...!


./script autoscaler K8S_NAMESPACE CPU_PERCENT
example :: ./script autoscaler production 80
EOF
        exit 1
    fi
}


function load-test() {
    if [[ ! -z ${K8S_NAMESPACE} ]] && [[ ! -z ${WAIT_TIME} ]] ; then
        if [[ ${WAIT_TIME} -ge 90 ]] && [[ ${WAIT_TIME} -le 120 ]] ; then
            echo "run the following command to check the number of pods for the deployment"
            echo ""
            echo "kubectl -n ${K8S_NAMESPACE} get deployment frontend"
            echo ""
            SELECT_POD=$(kubectl get pods -n ${K8S_NAMESPACE} --sort-by=metadata.name | grep frontend | head -n1 | cut -d" " -f1)
            NUM_PODS=$(kubectl get pods -n ${K8S_NAMESPACE} --sort-by=status.startTime | grep frontend | cut -d" " -f1 | wc -l)
            kubectl -n ${K8S_NAMESPACE} cp load.sh ${SELECT_POD}:/tmp/
            kubectl -n ${K8S_NAMESPACE} exec ${SELECT_POD} -- /bin/sh -c "/tmp/load.sh >/dev/null 2>&1 &"
            echo "Sleeping for ${WAIT_TIME} sec....!"
            sleep ${WAIT_TIME}
            CURRENT_NUM_PODS=$(kubectl get pods -n ${K8S_NAMESPACE} --sort-by=status.startTime | grep frontend | cut -d" " -f1 | wc -l)
            if [[ ${NUM_PODS} -lt ${CURRENT_NUM_PODS} ]] ; then
                echo "hooray...!"
                echo "The frontend scaled up to ${CURRENT_NUM_PODS} from ${NUM_PODS}"
                echo ""
                kubectl get pods -n ${K8S_NAMESPACE} --sort-by=status.startTime | grep frontend
                echo "scaling down to minimum size...!"
                kubectl -n ${K8S_NAMESPACE} delete pod ${SELECT_POD}
                echo "wait for some time and check the status of the pods, it must scaled down to ${NUM_PODS}"
            else
                echo "The wait time : ${WAIT_TIME} is not sufficient, try to run again with higher value"
                kubectl -n ${K8S_NAMESPACE} delete pod ${SELECT_POD}
                exit 1
            fi
        else
            echo "WAIT_TIME must be between 90 and 120"
            exit 1
        fi

    else
cat << EOF

K8S_NAMESPACE and WAIT_TIME need to provide...!, task aborting...!

./script load-test K8S_NAMESPACE WAIT_TIME
example :: ./script load-test production 90
WAIT_TIME must be between 90 and 120
EOF
        exit 1
    fi
}


function cleanup() {
   kubectl delete -f ../ingress-controller/ingress-service.yaml
   kubectl delete -f ../ingress-controller/ingress-nginx.yaml
   kubectl delete -f ../metrics-server/

   NameSpaces=(
	"staging"
	"production"
  )
  for NameSpace in ${NameSpaces[@]} ; do
  	kubectl delete --all deployment,service,replicaset,ing,hpa -n ${NameSpace}
	kubectl delete ns ${NameSpace}
  done
}




while getopts ":o:" opt
   do
     case $opt in
        o ) option=$OPTARG;;
     esac
done

pre-check

if [[ $option = ingress-controller ]]; then
    ingress-controller
elif [[ $option = stage-deploy ]]; then
    export K8S_NAMESPACE=staging
    deploy-guestbook
elif [[ $option = prod-deploy ]]; then
    export K8S_NAMESPACE=production
    deploy-guestbook
elif [[ $option = autoscaler ]]; then
    autoscaler ${K8S_NAMESPACE} ${CPU_PERCENT}
elif [[ $option = load-test ]]; then
    load-test ${K8S_NAMESPACE}
elif [[ $option = metrics-server ]]; then
    metrics-server
elif [[ $option = cleanup ]]; then
    cleanup
else
    guestbook-help
fi
