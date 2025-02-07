# Akeyless K8s Auth Setup through Terraform

This is a Terraform configuration for setting up a Kubernetes cluster to authenticate with Akeyless using the Akeyless K8s Auth method.

## Prerequisites

- An Akeyless account and a token with Access Permissions to the Akeyless Gateway API
- A kubectl configured to the target Kubernetes cluster with permissions to create namespaces, service accounts, cluster role bindings, and secrets

## Usage

This is designed to be run from a pipeline or computer that has access to the Akeyless Gateway API and the Kubernetes cluster.

### Setup the Environment Variables

```bash
# Retrieve the Akeyless token from the Akeyless Web Console
export TF_VAR_akeyless_token=""

# Set the Gateway Address
export TF_VAR_gateway_address=https://your-gateway-address:8000/api/v2

# Set the Kubernetes Host Endpoint
export TF_VAR_k8s_host_endpoint=$(kubectl config view --flatten --minify --output=go-template='{{(index .clusters 0).cluster.server}}')

# Set the Kubernetes Cluster Name
export TF_VAR_k8s_cluster_name=$(kubectl config current-context)
```

### Terraform Variables

The following variables can be configured either through environment variables (TF_VAR_*) or in a terraform.tfvars file:

| Variable Name | Description | Default Value | Required |
|--------------|-------------|---------------|----------|
| akeyless_token | Akeyless token (sensitive) | - | Yes |
| gateway_address | Akeyless Gateway API Address (https://gateway-address:8000/api/v2) | - | Yes |
| k8s_host_endpoint | The host endpoint for the kubernetes config | - | Yes |
| k8s_cluster_name | The name of the kubernetes cluster | - | Yes |
| k8s_kube_config_path | The path to the kubernetes config | ~/.kube/config | No |
| k8s_auth_account_name | The name of the kubernetes auth service account and role binding | "gateway-token-reviewer" | No |
| akeyless_k8s_auth_namespace | Akeyless k8s auth namespace | "akeyless-auth" | No |

## Initialize the Terraform Configuration

```bash
terraform init
```

## Apply the Terraform Configuration

```bash
terraform apply
```

## Destroy the Terraform Configuration

```bash
terraform destroy
```
