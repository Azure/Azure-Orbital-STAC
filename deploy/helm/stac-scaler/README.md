
# Azure Orbital STAC Processor

This chart deploys a [Kubernetes Job](https://kubernetes.io/docs/concepts/workloads/controllers/job/) that runs the STAC Processor on files stored in Azure Blob Storage.

The steps covered in this document is automated as part of main deployment covered in the [README.md](../../README.md). If you would like to customize and/or contribute to this Chart, follow the steps in this document to deploy the Kubernetes components to your Azure Kubernetes Cluster.

## Pre-requisites

The tools below are required for installation of the `stac-scaler` Chart.

* [kubectl](https://kubernetes.io/docs/reference/kubectl/)
* [helm](https://helm.sh/)
* [Az CLI](https://learn.microsoft.com/en-us/cli/azure/)


## Installation

Before executing the script, user needs to login to azure as shown below and set the correct subscription in which they want to provision the resources.

```
az login

az account set -s <subscription_id>
```
One of pre-requisites for installing this Chart is [KEDA](https://keda.sh/docs/2.8/concepts/). KEDA is a Kubernetes based Event Driven Autoscaler. With KEDA, you can drive the scaling of any container in Kubernetes based on the number of events needing to be processed.

```
kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.8.0/keda-2.8.0.yaml
```

In order to install the `STAC Processor` chart, it is recommended you first create a values-custom.yaml file in the current directory. Then the chart can be deployed with:

```
helm install [-n <my_namespace>] <release_name> . -f values-custom.yaml
```
## Values

This section of the document will go over all the possible values you can override in `values-custom.yaml` file in the current directory.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| replicaCount | int | `1` | Number of replicas of the pods. |
| parallelism | int | `1` | Number of pods to that can run in parallelism as any time. |
| jobCleanupTimeSeconds | int | `1` | Time to clean up job afer they are completed. |
| activeDeadlineSeconds | int | `1` | Time to clean up the job after a specific time out is reached. |
| deploymentNamespace | string | `pgstac` | Namespace in Kubernetes cluster to create jobs. |
| processor | object | `{}` | Defines the properties of each processor that will process your input file(s) which can be either metadata in the form of JSON file or raster data in COG format. |

### Processor

A `processor` entry must have values as described below. Each `processor` entry defines a image to be pull from the ACR and run in the Kubernetes Cluster as Jobs through scaling.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| template | string | `nil` | Name of the k8s deployment template to be scaled |
| labels | array | `[]` | An array of labels to be appended to the jobs and their pods. |
| topicNamespace | string | `nil` | Namespace created in the Service Bus that contains the Queues, Topics and Subscriptions. |
| topicName | string | `nil` | Name of the topic to listen for scaling the jobs. |
| subscriptionName | string | `nil` | Name of the subscription to subscribe to listen for messages for scaling the jobs. |
| image.repository | string | `nil` | Name of the Azure Container Registry. This needs to be the full login server name with suffix such as `azurecr.io`. |
| image.name | string | `nil` | Name of the image in the Container Registry to use for the jobs created during scaling. |
| image.tag | string | `latest` | Name of the image tag in the Container Registry to use for hte jobs created during scaling. |
| image.pullPolicy | string | `Always` | Policy to use for pulling images from Container Registry before creating pods. |
| env | array | `[]` | Key - Value pairs of environment variables to be passed to the container that runs to process the files. |
| podAnnotations | object | `{}` | Define set of arbitrary non-identifying metadata to pods. |
| resources.limits.cpu | string | `100m` | CPU specifications for the pod. |
| resources.limits.memory | string | `512Mi` | Memory specifications for the pod. |
