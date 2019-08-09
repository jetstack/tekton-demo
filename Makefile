SHELL := /bin/bash
.DEFAULT_GOAL := help

GCP_ACCOUNT := $$(gcloud config get-value core/account)
GCP_PROJECT := $$(gcloud config get-value project)
GCP_LOCATION := europe-west1
GCP_ZONE := ${GCP_LOCATION}-d
MACHINE_TYPE := 		n1-standard-1
SMALL_MACHINE_TYPE := 	f1-micro
K8S_VERSION := 1.13.6

PROJECT_NAME := tektondemo
CLUSTER_NAME := ${PROJECT_NAME}

###############################################################
##################### Modify these values #####################
###############################################################
PROJECT_DIR := $$(pwd)
GIT_REPO_URL := https://github.com/alljames/hello-kubernetes.git
BUILD_NAME := hellok8s
###############################################################
MAJOR := 0
MINOR := 0
PATCH := 1
IMAGE_TAG := ${MAJOR}-${MINOR}-${PATCH}
###############################################################

TEKTON_VERSION := 0.5.2

KO_DOCKER_REPO := eu.gcr.io/${GCP_PROJECT}

EXISTING_CLUSTERS := $$(gcloud container clusters list --format json | jq '.[] | .name')

##@ Help
.PHONY: help
help: ## Show this screen (default behaviour of `make`)
	@echo "Demonstration of Tekton CI/CD"
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: check_requirements
check_requirements: ## Check that required programs are installed in $PATH
	@hash gcloud 2> /dev/null		|| echo "Requirement missing: gcloud: https://cloud.google.com/sdk/install"
	@hash kubectl 2> /dev/null		|| echo "Requirement missing: kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
	@hash kubecfg 2> /dev/null		|| echo "Requirement missing: kubecfg: https://github.com/bitnami/kubecfg#install"
	@hash jsonnet 2> /dev/null		|| echo "Requirement missing: jsonnet: https://github.com/google/jsonnet (or better yet: use your OS's package manager)"
	@hash jq 2> /dev/null			|| echo "Requirement missing: jq: https://stedolan.github.io/jq/"

###############################################################
###############################################################
###############################################################


.PHONY: demo_infra demo_resource demo_delete
##@ Demonstration
demo_infra: check_requirements gcp_info gke_create gke_get_creds  ## Setup infrastructure for demo (imperatively)

demo_resource: check_requirements tekton_initialise tekton_resource_apply website_deploy ## Deploy resources for demo (imperatively)

.PHONY: gcp_info gcr_list_images gke_info gke_create gke_get_creds gke_delete
##@ Google Cloud Platform
gcp_info:
	@echo "GCP Account: ${GCP_ACCOUNT}"
	@echo "GCP Project: ${GCP_PROJECT}"
	gcloud container clusters list
	@gcloud auth configure-docker

gcr_list_images: ## List Google Cloud Registry (GCR) images
	@echo "${KO_DOCKER_REPO}/${BUILD_NAME}"
	@gcloud container images list-tags ${KO_DOCKER_REPO}/${BUILD_NAME}

gke_info:
	@gcloud container clusters list
	@gcloud container node-pools list --zone ${GCP_ZONE} --cluster ${CLUSTER_NAME}

gke_create: ## Create GKE cluster
	@if [[ ${EXISTING_CLUSTERS} == *"${CLUSTER_NAME}"* ]]; then \
	 echo "Cluster ${CLUSTER_NAME} already exists"; \
	else \
	 echo "Creating ${CLUSTER_NAME} in ${GCP_ZONE}"; \
	  gcloud container clusters create \
	  ${CLUSTER_NAME} \
	    --zone ${GCP_ZONE} \
	  	--cluster-version ${K8S_VERSION} \
	  	  --machine-type ${MACHINE_TYPE} \
	  		--num-nodes=1 --preemptible --no-enable-autoupgrade \
	  		--issue-client-certificate --enable-basic-auth \
	  		--metadata disable-legacy-endpoints=true \
				--disk-type=pd-ssd --disk-size=10GB \
  				--no-enable-cloud-logging --no-enable-cloud-monitoring \
	  		--no-enable-ip-alias --no-enable-autoupgrade; \
	  gcloud container node-pools create web-backend \
	    --cluster ${CLUSTER_NAME} \
	  	  --zone ${GCP_ZONE} \
	    		--machine-type ${MACHINE_TYPE} \
	    		--num-nodes=2 --enable-autorepair \
				--disk-type=pd-ssd --disk-size=10GB \
	    		--metadata disable-legacy-endpoints=true; \
	  gcloud container node-pools create cicd \
	    --cluster ${CLUSTER_NAME} \
	    	--zone ${GCP_ZONE} \
	    	--machine-type ${SMALL_MACHINE_TYPE} \
	    	--num-nodes=2 --enable-autorepair --preemptible \
			--disk-type=pd-ssd --disk-size=10GB \
	    	--metadata disable-legacy-endpoints=true; \
	  gcloud container node-pools delete default-pool \
	    --cluster=${CLUSTER_NAME} --zone ${GCP_ZONE} --quiet; \
	fi

gke_get_creds: ## Get GKE cluster credentials
	gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${GCP_ZONE}

gke_delete: gcp_info ## Delete GKE cluster
	gcloud container clusters delete ${CLUSTER_NAME} --zone ${GCP_ZONE} --async

.PHONY: tekton_initialise tekton_set_rbac tekton_resource_validate tekton_runs_validate tekton_resource_apply tekton_trigger tekton_resource_show tekton_runs_show tekton_pretty tekton_delete_all tekton_delete_runs tekton_delete_resource
##@ Tekton
tekton_initialise: kaniko_apply_secret ## Install Tekton CRDs and Controllers to cluster
	@kubectl apply --filename https://github.com/tektoncd/pipeline/releases/download/v${TEKTON_VERSION}/release.yaml

tekton_set_rbac:
	kubectl create clusterrolebinding \
	cluster-admin-binding \
	--clusterrole=cluster-admin \
	--user=${GCP_ACCOUNT}

tekton_resource_validate:
	@kubecfg show ${PROJECT_DIR}/jsonnet/tekton/tekton-resources.jsonnet \
	-V BUILD_NAME=${BUILD_NAME} -V IMAGE_TAG="${IMAGE_TAG}" -V GIT_REPO_URL="${GIT_REPO_URL}" -V GCR_REGISTRY="${KO_DOCKER_REPO}" \
	| kubectl apply --recursive=true --filename - --validate=true --dry-run=true

tekton_runs_validate:
	@kubecfg show ${PROJECT_DIR}/jsonnet/tekton/tekton-runs.jsonnet \
	-V BUILD_NAME=${BUILD_NAME} -V IMAGE_TAG="${IMAGE_TAG}" -V GIT_REPO_URL="${GIT_REPO_URL}" -V GCR_REGISTRY="${KO_DOCKER_REPO}" \
	| kubectl apply --recursive=true --filename - --validate=true --dry-run=true

tekton_resource_apply: tekton_resource_validate
	@kubecfg show ${PROJECT_DIR}/jsonnet/tekton/tekton-resources.jsonnet \
	-V BUILD_NAME=${BUILD_NAME} -V IMAGE_TAG="${IMAGE_TAG}" -V GIT_REPO_URL="${GIT_REPO_URL}" -V GCR_REGISTRY="${KO_DOCKER_REPO}" \
	| kubectl apply --recursive=true --filename -

tekton_trigger: tekton_runs_validate tekton_resource_apply ## Create resources and trigger a run
	@kubecfg show ${PROJECT_DIR}/jsonnet/tekton/tekton-runs.jsonnet \
	-V BUILD_NAME=${BUILD_NAME} -V IMAGE_TAG="${IMAGE_TAG}" -V GIT_REPO_URL="${GIT_REPO_URL}" -V GCR_REGISTRY="${KO_DOCKER_REPO}" \
	| kubectl apply --recursive=true --filename -

tekton_resource_show: ## List Tekton resources
	kubectl get tasks --all-namespaces
	kubectl get pipelines --all-namespaces
	kubectl get pipelineresources --all-namespaces

tekton_runs_show: ## List Tekton runs
	kubectl get taskruns --all-namespaces
	kubectl get pipelineruns --all-namespaces

tekton_pretty: ## Output basic information regarding TaskRun (in JSON format)
	@kubectl -n cicd get taskrun tr-t-pullcodeandpushtogcr-${BUILD_NAME}-${IMAGE_TAG} -o json \
	| jq \
	.kind,\
	.metadata.labels,\
	.metadata.name

	@kubectl -n cicd get taskrun tr-t-pullcodeandpushtogcr-${BUILD_NAME}-${IMAGE_TAG} -o json \
	| jq '.status.steps[0:]'

tekton_delete_all: tekton_delete_runs tekton_delete_resource ## Delete all Tekton runners, resources and tekton-pipelines namespace
	kubectl delete namespace tekton-pipelines

tekton_delete_runs: ## Delete all Tekton runners from cluster
	kubectl delete pipelineruns --all
	kubectl delete taskruns --all

tekton_delete_resource: ## Delete all Tekton resources from cluster
	kubectl delete tasks --all
	kubectl delete pipelines --all
	kubectl delete pipelineresources --all

.PHONY: website_validate website_deploy
##@ Website
website_validate:
	@kubecfg show ${PROJECT_DIR}/jsonnet/website/website.jsonnet \
	-V BUILD_NAME=${BUILD_NAME} -V IMAGE_TAG="${IMAGE_TAG}" -V GCR_REGISTRY="${KO_DOCKER_REPO}" \
	| kubectl apply --recursive=true --filename - --validate=true --dry-run=true 

website_deploy: website_validate ## Deploy website
	@kubecfg show ${PROJECT_DIR}/jsonnet/website/website.jsonnet \
	-V BUILD_NAME=${BUILD_NAME} -V IMAGE_TAG="${IMAGE_TAG}" -V GCR_REGISTRY="${KO_DOCKER_REPO}" \
	| kubectl apply --recursive=true --filename -

.PHONY: kaniko_sa_create kaniko_sa_secret_create kaniko_sa_delete kaniko_apply_secret
##@ Kaniko
kaniko_sa_create: ## Create a Service Account for Kaniko with storage admin role
	gcloud iam service-accounts create kaniko --display-name kaniko
	gcloud projects add-iam-policy-binding ${GCP_PROJECT} \
	 --member serviceAccount:kaniko@${GCP_PROJECT}.iam.gserviceaccount.com \
	 --role roles/storage.admin 

kaniko_sa_secret_create: ## Create kaniko-secret.json (will be applied as Kubernetes Secret)
	gcloud iam service-accounts keys create ${PROJECT_DIR}/secrets/kaniko-secret.json \
		--iam-account kaniko@${GCP_PROJECT}.iam.gserviceaccount.com
	@echo "Kaniko secret saved to ${PROJECT_DIR}/secrets/kaniko-secret.json"
	@echo "Please note that it may take up to 60 seconds before a new key can be used for authentication"

kaniko_sa_delete: ## Remove the Kaniko Service Account and its role binding
	gcloud projects remove-iam-policy-binding ${GCP_PROJECT} \
	 --member serviceAccount:kaniko@${GCP_PROJECT}.iam.gserviceaccount.com \
	 --role roles/storage.admin
	gcloud -q iam service-accounts delete kaniko@${GCP_PROJECT}.iam.gserviceaccount.com
	rm ${PROJECT_DIR}/secrets/kaniko-secret.json

kaniko_apply_secret: ## Apply kaniko-secret.json
	@kubectl create namespace cicd --dry-run=true --output=yaml \
	| kubectl apply -f -
	@kubectl -n cicd create secret generic kaniko-secret \
	 --from-file=${PROJECT_DIR}/secrets/kaniko-secret.json --dry-run=true --output=yaml \
	| kubectl apply -f -
