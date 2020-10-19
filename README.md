*********************************************************  
# Common steps for both "domain in image" and "model in image"  
*********************************************************  

export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.8.0_171.jdk/Contents/Home  
export WEBLOGIC_POC_HOME=/Users/rbajaj/Documents/weblogic-poc  
## Clone weblogic operator repo from github and set it as env var  
export WEBLOGIC_OP_HOME=/Users/rbajaj/Documents/weblogic-kubernetes-operator  
cd $WEBLOGIC_POC_HOME  

## Extract existing running domain
./weblogic-deploy/bin/discoverDomain.sh -oracle_home /Users/rbajaj/weblogic/wls12214 \
-domain_home /Users/rbajaj/weblogic/wls12214/user_projects/domains/sample-domain1 \
-archive_file $WEBLOGIC_POC_HOME/extracted-domain/BlogDomain-WDT.zip \
-model_file $WEBLOGIC_POC_HOME/extracted-domain/BlogDomain-WDT.yaml \
-variable_file $WEBLOGIC_POC_HOME/extracted-domain/BlogDomain-WDT.properties  

## Copy files for use in model in image setup  
cp $WEBLOGIC_POC_HOME/extracted-domain/BlogDomain-WDT.zip $WEBLOGIC_POC_HOME/model-in-image-blog/model-images/model-in-image__blog-v1/  
cp $WEBLOGIC_POC_HOME/extracted-domain/BlogDomain-WDT.yaml $WEBLOGIC_POC_HOME/model-in-image-blog/model-images/model-in-image__blog-v1/  
cp $WEBLOGIC_POC_HOME/extracted-domain/BlogDomain-WDT.properties $WEBLOGIC_POC_HOME/model-in-image-blog/model-images/model-in-image__blog-v1/  

kubectl create secret generic regcred \
    --from-file=.dockerconfigjson=<path/to/.docker/config.json> \
    --type=kubernetes.io/dockerconfigjson -o yaml > docker-secret.yaml  

## Copy docker secret yaml and change namespace accordingly  
cp docker-secret.yaml $WEBLOGIC_POC_HOME/model-in-image-blog/  
cp docker-secret.yaml $WEBLOGIC_POC_HOME/domain-home-in-image-blog/  

## create namespaces for operator and ingress controller  
kubectl create namespace traefik  
kubectl create namespace sample-weblogic-operator-ns  

## For use in domain in image  
kubectl create namespace sample-domain2-ns  
kubectl apply -f docker-secret.yaml -n sample-domain2-ns  
## For use in model in image  
kubectl create namespace sample-domain3-ns  
kubectl apply -f docker-secret.yaml -n sample-domain3-ns  

## Download weblogic image from oracle container registry, tag it and push it to private repo  
docker tag 4a5e6a90ca98 dockerish82/weblogicrepo:12.2.1.4  
docker push dockerish82/weblogicrepo:12.2.1.4  

## Grant cluster admin role to helm  
kubectl apply -f helm-cluster-admin.yaml  

helm repo add stable https://kubernetes-charts.storage.googleapis.com/  

helm install traefik-operator stable/traefik \
    --namespace traefik \
    --values traefic-values.yaml \
    --set "kubernetes.namespaces={traefik}" \
    --wait  

## Create service account to be used by operator  
kubectl create serviceaccount -n sample-weblogic-operator-ns sample-weblogic-operator-sa  

## Install weblogic operator using helm  
helm install sample-weblogic-operator $WEBLOGIC_OP_HOME/kubernetes/charts/weblogic-operator \
  --namespace sample-weblogic-operator-ns \
  --set image=oracle/weblogic-kubernetes-operator:3.0.2 \
  --set serviceAccount=sample-weblogic-operator-sa \
  --set "domainNamespaces={}" \
  --wait  

## [Optional] secret creation for exposing operator rest endpoint, clone weblogic kubernetes operator github repo  
$WEBLOGIC_OP_HOME/kubernetes/samples/scripts/rest/generate-external-rest-identity.sh -a "DNS:kuberntes.docker.internal,DNS:localhost,IP:127.0.0.1" -n sample-weblogic-operator-ns -s weblogic-operator-external-rest-identity  

## Enable elk, add operator certs and add namespaces to monitor for detecting weblogic domain objects  
helm upgrade sample-weblogic-operator  $WEBLOGIC_OP_HOME/kubernetes/charts/weblogic-operator \
    --values $WEBLOGIC_POC_HOME/op-values.yaml \
    --namespace sample-weblogic-operator-ns \
    --reuse-values \
    --set "domainNamespaces={sample-domain2-ns,sample-domain3-ns}" \
    --wait  

## Upgrade traefik to look for weblogic domain objects  
helm upgrade traefik-operator stable/traefik \
    --namespace traefik \
    --reuse-values \
    --set "kubernetes.namespaces={traefik,sample-domain2-ns,sample-domain3-ns}" \
    --wait  

## Create weblogic admin server creds for use in domain in image setup  
$WEBLOGIC_OP_HOME/kubernetes/samples/scripts/create-weblogic-domain-credentials/create-weblogic-credentials.sh \
  -u weblogic -p Admin@123 -n sample-domain2-ns -d sample-domain2 -s sample-domain2-weblogic-credentials  

## Create weblogic admin server creds for use in model in image setup
$WEBLOGIC_OP_HOME/kubernetes/samples/scripts/create-weblogic-domain-credentials/create-weblogic-credentials.sh \
  -u weblogic -p Admin@123 -n sample-domain3-ns -d sample-domain3 -s sample-domain3-weblogic-credentials  

## Create mysql pod in whichever namespace you want, below steps are for use in model in image
## make sure appropriate storage class exists and change mysql-pv.yaml accordingly, below set up is for host path  
cd $WEBLOGIC_POC_HOME  
kubectl apply -f mysql-pv.yaml  
helm install blog-db -f mysql-values.yml stable/mysql --namespace=sample-domain3-ns  
kubectl apply -f ubuntu-debug.yaml  
kubectl exec -it ubuntu-debug -n sample-domain3-ns -- /bin/bash  
apt update && apt install -y mysql-client  
mysql -h blog-db-mysql -u bloguser -D blogdb --password=blogpassword  

## Execute blogdb-ddl.sql to create required tables in database  
Copy contents of sql file and execute via ubuntu test pod.  

*********************************************************  
# Model in image
*********************************************************  

cd $WEBLOGIC_POC_HOME/model-in-image-blog 

## [Optional] Handy command to delete old wdt_latest
./imagetool/bin/imagetool.sh cache deleteEntry --key wdt_latest

## Add weblogic-deploy.zip to imagetool cache to layer it above weblogic base image
./imagetool/bin/imagetool.sh cache addInstaller \
  --type wdt \
  --version latest \
  --path $WEBLOGIC_POC_HOME/model-in-image-blog/model-images/weblogic-deploy.zip

## Confirm cache has necessary entries
./imagetool/bin/imagetool.sh cache listItems

## create admin server creds if it does not exist already
kubectl -n sample-domain3-ns create secret generic \
  sample-domain3-weblogic-credentials \
   --from-literal=username=weblogic --from-literal=password=Admin@123

kubectl -n sample-domain3-ns label secret \
  sample-domain3-weblogic-credentials \
  weblogic.domainUID=sample-domain3

## create runtime secret
kubectl -n sample-domain3-ns create secret generic \
  sample-domain3-runtime-encryption-secret \
   --from-literal=password=Runtime@123

kubectl -n sample-domain3-ns label  secret \
  sample-domain3-runtime-encryption-secret \
  weblogic.domainUID=sample-domain3

## create node manager secret
kubectl -n sample-domain3-ns create secret generic nm-credentials \
  --from-literal=password=Admin@123
kubectl -n sample-domain3-ns label  secret \
  nm-credentials weblogic.domainUID=sample-domain3

## create secret to hold blog database password
kubectl -n sample-domain3-ns create secret generic blogdb-credentials \
  --from-literal=password=blogpassword
kubectl -n sample-domain3-ns label  secret \
  blogdb-credentials weblogic.domainUID=sample-domain3

## Create a new docker image with base + weblogic deploy zip and wdt model and app archive and change yaml file to pull passwords from secrets  
cd $WEBLOGIC_POC_HOME/model-in-image-blog
./imagetool/bin/imagetool.sh update \
  --tag model-in-image:blog-v1 \
  --fromImage dockerish82/weblogicrepo:12.2.1.4 \
  --wdtModel      ./model-images/model-in-image__blog-v1/BlogDomain-WDT.yaml \
  --wdtVariables  ./model-images/model-in-image__blog-v1/BlogDomain-WDT.properties \
  --wdtArchive    ./model-images/model-in-image__blog-v1/BlogDomain-WDT.zip \
  --wdtModelOnly \
  --wdtDomainType WLS \
  --chown oracle:root

## Tag newly build image and push it to private repo
docker tag {built-image-id} dockerish82/model-in-image:blog-v1
docker push dockerish82/model-in-image:blog-v1

## Create a config map to hold data source configuration that will be utilized at time of domain creation
kubectl -n sample-domain3-ns create configmap sample-domain3-wdt-config-map \
  --from-file=$WEBLOGIC_POC_HOME/model-in-image-blog/model-configmaps/datasource/blog-datasource.yaml

kubectl -n sample-domain3-ns label configmap sample-domain3-wdt-config-map \
  weblogic.domainUID=sample-domain3

export DOMAIN_UID=sample-domain3

## Copy wdt model files that were pushed to docker image and modify them to extract domain resource yaml from it  
cp $WEBLOGIC_POC_HOME/extracted-domain/BlogDomain-WDT.zip $WEBLOGIC_POC_HOME/model-in-image-blog/domain-resources/
cp $WEBLOGIC_POC_HOME/extracted-domain/BlogDomain-WDT.yaml $WEBLOGIC_POC_HOME/model-in-image-blog/domain-resources/
cp $WEBLOGIC_POC_HOME/extracted-domain/BlogDomain-WDT.properties $WEBLOGIC_POC_HOME/model-in-image-blog/domain-resources/

## Edit BlogDomain-WDT.yaml and add below section, and take out jdbc section as that will be merged via config map  
```
kubernetes:
    apiVersion: weblogic.oracle/v8
    kind: Domain
    metadata:
        name: '@@ENV:DOMAIN_UID@@'
        namespace: '@@ENV:DOMAIN_UID@@-ns'
    spec:
        image: 'dockerish82/model-in-image:blog-v1'
        imagePullPolicy: 'IfNotPresent'
        webLogicCredentialsSecret:
            name: '@@ENV:DOMAIN_UID@@-weblogic-credentials'
        serverPod:
            env:
                USER_MEM_ARGS:
                    value: '-XX:+UseContainerSupport -Djava.security.egd=file:/dev/./urandom -Xms256m -Xmx512m'
                JAVA_OPTIONS:
                    value: "-Dweblogic.StdoutDebugEnabled=false"
                CUSTOM_DOMAIN_NAME
                    value: 'sample-domain3'
```

## Use extract utility to create a skeleton domain resource yaml  
./weblogic-deploy/bin/extractDomainResource.sh -oracle_home /Users/rbajaj/Oracle/Middleware/Oracle_Home \
  -domain_home /u01/domains/sample-domain3 \
  -model_file $WEBLOGIC_POC_HOME/model-in-image-blog/domain-resources/BlogDomain-WDT.yaml \
  -variable_file $WEBLOGIC_POC_HOME/model-in-image-blog/domain-resources/BlogDomain-WDT.properties \
  -archive_file $WEBLOGIC_POC_HOME/model-in-image-blog/domain-resources/BlogDomain-WDT.zip \
  -domain_resource_file ./domain-resources/WLS/blog-domain.yaml  

## And this under spec and pod section respectively
```   domainHomeSourceType: FromModel
    includeServerOutInPodLog: true
    serverStartPolicy: "IF_NEEDED"
    # NodePort to expose for the admin server
    adminNodePort: 30701
    # Boolean to indicate if the adminNodePort will be exposed
    exposeAdminNodePort: true
    adminServer:
        # "RUNNING" means the listed server will be started up to "RUNNING" mode
        # "ADMIN" means the listed server will be start up to "ADMIN" mode
        serverStartState: "RUNNING"
        adminService:
            channels:
            # The Admin Server's NodePort
            -   channelName: default
                nodePort: 30701
    replicas: 1
    # Change the restartVersion to force the introspector job to rerun
    # and apply any new model configuration, to also force a subsequent
    # roll of your domain's WebLogic Server pods.
    restartVersion: '1'
    configuration:
        # Settings for domainHomeSourceType 'FromModel'
        model:
            # Valid model domain types are 'WLS', 'JRF', and 'RestrictedJRF', default is 'WLS'
            domainType: "WLS"
            # Optional configmap for additional models and variable files
            configMap: sample-domain3-wdt-config-map
            # All 'FromModel' domains require a runtimeEncryptionSecret with a 'password' field
            runtimeEncryptionSecret: sample-domain3-runtime-encryption-secret
        # Secrets that are referenced by model yaml macros
        # (the model yaml in the optional configMap or in the image)
        secrets:
        -   nm-credentials
        -   blogdb-credentials
        # Increase the introspector job active timeout value for DeadlineExceeded error
        introspectorJobActiveDeadlineSeconds: 600

        
        resources:
            requests:
                cpu: "250m"
                memory: "768Mi"
```

## Create weblogic domain  
kubectl apply -f $WEBLOGIC_POC_HOME/model-in-image-blog/domain-resources/WLS/blog-domain.yaml  

## Create ingresses for admin and managed server  
kubectl apply -f adminserver-ingress.yaml  
kubectl apply -f blogdomain-ingress.yaml  

## Create a test pod to validate mysql service connection  
kubectl exec -it ubuntu-debug -n sample-domain3-ns -- /bin/bash   
apt update && apt install -y  

## Few sanity checks
## [Optional] $WEBLOGIC_POC_HOME/operatorrest.sh localhost /operator/latest/domains  
## Run the WLS Administration Console:  

In your browser, enter `https://localhost:30701/console`. And validate app is deployed and jdbc source is available.  

## Via ingress  
curl `http://localhost/blog-root/api/user/show/1`  
OR  
browse via browser - `http://localhost/blog-root`  

***************************************************************
# Domain in Home using wlst
***************************************************************

## Example of Image with WLS Domain  
================================
This archive needs to be built (one time only) before building the Docker image.  

cd $WEBLOGIC_POC_HOME/domain-home-in-image-blog  
./build-archive.sh  

export DOMAIN_UID=sample-domain2

## Build image using existing app archive, properties file and base weblogic image  
./build.sh  

## Push newly build image to private repo  
docker push dockerish82/domain-home-in-image-blog:12.2.1.4  

## Note:  
This setup assumes mysql is running locally, if not please follow mysql pod creation step from common instructions.  
And change dsUrl in $WEBLOGIC_POC_HOME/domain-home-in-image-blog/container-scripts/datasource.properties accordingly.  

## Update and validate create-domain-inputs.yaml and make sure things look good  
./create-domain.sh -i create-domain-inputs.yaml -o ./outputs -u weblogic -p Admin@123 -e  

## Create ingresses for traefik  
kubectl apply -f adminserver-ingress.yaml -n sample-domain2-ns  
kubectl apply -f blogdomain-ingress.yaml -n sample-domain2-ns  

## Run the WLS Administration Console:  

In your browser, enter `https://localhost:30701/console`. And validate app is deployed and jdbc source is available.  

## Via ingress  
curl `http://localhost/blog-root/api/user/show/1`  
OR  
browse via browser - `http://localhost/blog-root`  


# Troubleshooting tips  
## check operator logs for severe errors  
kubectl logs {weblogic-operator-pod} -c weblogic-operator -n sample-weblogic-operator-ns  \
  | egrep -e "level...(SEVERE|WARNING)"  

## Watch for pod creation after domain k8 resource creation  
kubetl get pods -n sample-domain-ns3 --watch  

## check that persistent volume was claimed by mysql pod after helm install of mysql
kubectl get pv mysql-pv -o wide  