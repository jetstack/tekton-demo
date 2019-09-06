# Tekton Demo

## Disclaimer

The code in this repository is a demonstration. Please do not use in production. This demonstration will create billable GCP resources.

## Introduction

This demonstration ties together with the [Jetstack blogpost on Tekton](https://blog.jetstack.io/blog/exploring-tekton/). Please read this blogpost to familiarise yourself with Tekton's underlying concepts.

At the end of the demonstration, you will have a [simple website](https://github.com/paulbouwer/hello-kubernetes) being served from Kubernetes. Using Tekton, the container image used to serve the website will have been built from within the same Kubernetes cluster that serves the website. As Tekton `TaskRun`s execute in a Kubernetes Pod, it's possible to influence how these workloads are scheduled. In this demo, the website is served from `n1-standard-1` nodes, while the CI/CD is carried out on pre-emptible `f1-micro` nodes.

## What to expect from this demo

For this we'll use Paul Bouwer's `hello-kubernetes` repo on GitHub, which serves a simple website that shows which Pod is currently serving the website. Fork this repo, and specify the fork in the Makefile (variable GIT_REPO_URL).

The build may initially fail with an error regarding "unexpected end of statement while looking for matching single-quote". This can be rectified by removing the single-quote character from the `org.opencontainers.image.description` field of the `hello-kubernetes` repo's Dockerfile.

After modifying the forked repo, we need to build an image and push it to a container registry, which will be achieved by Kaniko from within the cluster.

To change the background colour you can modify `static/css/main.css` and commit this code to your fork of `hello-kubernetes`. We can now bump the version number in the Makefile (lines 22-24) and run `make tekton_trigger`, which will run a Tekton pipeline, and apply the new image version to the Kubernetes cluster.

## Using this repository

Run `make` for an overview of the repo's functionality.

Please run `make check_requirements` to check which dependencies are missing from your local environment for this demo to work.

## Setup

### Google Cloud Platform

This assumes that you have already run `gcloud init` in your local environment.

Firstly, ensure that the relevant API services have been enabled in your account:-

```shell
gcloud services enable storage-api.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable iam.googleapis.com
```

We'll need to be able to authenticate to push to a Google Container Registry (GCR). For this authentication, [Kaniko](https://github.com/GoogleContainerTools/kaniko) requires a storage admin role. You can use the Makefile to generate a GCP Service Account and download an authorisation key:-

```shell
make kaniko_sa_create kaniko_sa_secret_create
```

This will output a JSON file to the repository's `secrets/` directory, where the Makefile expects to find the credentials.

## Usage

### Infrastructure

Run `make demo_infra` to create a GKE cluster with two node pools: `web-backend` to serve the website, and a pre-emptible `cicd` node pool to run Tekton pipelines.

### Tekton resources

Run `make demo_resources` to install Tekton on the cluster (in the `tekton-pipelines` namespace), along with a demo website (in the `website-dev` namespace).

Run `make tekton_trigger` to run a build.

`make tekton_pretty` will output some relevant information from the build steps. As a Tekton Run is just another Kubernetes object, its outputs that can be logged and read like any other resource using `kubectl get <POD_NAME> -o yaml`. We can also follow the logs of the containers running within the Pod using `kubectl -n cicd logs -f <POD_NAME> <CONTAINER>`.

### Website

Within a few minutes, GKE will provision an IP address for your LoadBalancer Service endpoint, which you can discover by running:

```shell
kubectl --namespace website-dev get svc
```

Once the image has been built (using `make tekton_trigger`) and deployed (using `make website_deploy`), the website will be served at this external IP address.

### Cleanup

Don't forget to delete the cluster using `make demo_delete` once you're finished, which will delete the Kaniko ServiceAccount and the demonstration's GKE cluster. Also delete any container images that have been pushed to your Container Registry.

## Further experimentation

Modify lines 18-24 of the Makefile to try building containers based on other Git repos that have `Dockerfile`s in their root.
