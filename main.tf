terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    akeyless = {
      version = ">= 1.0.0"
      source  = "akeyless-community/akeyless"
    }
  }
}

provider "akeyless" {
  api_gateway_address = var.gateway_address

  token_login {
    token = var.akeyless_token
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

variable "k8s_host_endpoint" {
  type        = string
  description = "The host endpoint for the kubernetes config"
}

variable "k8s_cluster_name" {
  type        = string
  description = "The name of the kuberentes cluster"
}

variable "akeyless_token" {
  type        = string
  description = "Akeyless token"
  sensitive   = true
}

variable "akeyless_k8s_auth_namespace" {
  type        = string
  description = "Akeyless k8s auth namespace"
  default     = "akeyless-auth"
}

variable "gateway_address" {
  type        = string
  description = "Akeyless Gateway API (https://gateway-address:8000/api/v2) Address"
}

resource "kubernetes_namespace" "akeyless_namespace" {
  metadata {
    name = var.akeyless_k8s_auth_namespace
  }
}

resource "kubernetes_service_account" "gateway_service_account" {
  metadata {
    name      = "gateway-token-reviewer"
    namespace = kubernetes_namespace.akeyless_namespace.metadata[0].name
  }
  depends_on = [kubernetes_namespace.akeyless_namespace]
}

resource "kubernetes_secret" "gateway_service_account_token" {
  metadata {
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.gateway_service_account.metadata.0.name
    }
    namespace     = kubernetes_namespace.akeyless_namespace.metadata[0].name
    generate_name = "gateway-token-reviewer-"
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true

  depends_on = [
    kubernetes_namespace.akeyless_namespace,
    kubernetes_service_account.gateway_service_account
  ]
}

resource "kubernetes_cluster_role_binding" "token_reviewer_binding" {
  metadata {
    name = "gateway-token-reviewer-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.gateway_service_account.metadata.0.name
    namespace = kubernetes_namespace.akeyless_namespace.metadata[0].name
  }
  depends_on = [
    kubernetes_namespace.akeyless_namespace,
    kubernetes_service_account.gateway_service_account
  ]
}

# Output for cluster information
data "kubernetes_resource" "cluster_info" {
  api_version = "v1"
  kind        = "ConfigMap"

  metadata {
    name      = "kube-root-ca.crt"
    namespace = "kube-system"
  }
}

output "cluster_ca_certificate" {
  value = data.kubernetes_resource.cluster_info.object.data["ca.crt"]
}

output "bearer_token" {
  value     = data.kubernetes_secret.token.data.token
  sensitive = true
}

data "kubernetes_secret" "token" {
  metadata {
    name      = kubernetes_secret.gateway_service_account_token.metadata.0.name
    namespace = var.akeyless_k8s_auth_namespace
  }
  depends_on = [kubernetes_secret.gateway_service_account_token]
}

# Akeyless Auth Method
resource "akeyless_auth_method_k8s" "cluster_auth" {
  name = var.k8s_cluster_name

  depends_on = [
    kubernetes_secret.gateway_service_account_token,
    kubernetes_cluster_role_binding.token_reviewer_binding
  ]
}

# Akeyless Auth Method Configuration
resource "akeyless_k8s_auth_config" "cluster_config" {
  name                      = var.k8s_cluster_name
  cluster_api_type          = "native_k8s"
  access_id                 = akeyless_auth_method_k8s.cluster_auth.access_id
  token_reviewer_jwt        = data.kubernetes_secret.token.data["token"]
  disable_issuer_validation = true
  k8s_auth_type             = "token"
  k8s_ca_cert               = data.kubernetes_resource.cluster_info.object.data["ca.crt"]
  k8s_host                  = var.k8s_host_endpoint
  signing_key               = akeyless_auth_method_k8s.cluster_auth.private_key

  depends_on = [akeyless_auth_method_k8s.cluster_auth]
}

# Output of the Akeyless Auth Method Access ID and the Akeyless K8s Auth Config Name
output "kubernetes_auth_method_id" {
  description = "The Akeyless Auth Method Access ID"
  value       = akeyless_auth_method_k8s.cluster_auth.access_id
}

output "kubernetes_k8s_auth_config_name" {
  description = "The Akeyless K8s Auth Config Name"
  value       = akeyless_k8s_auth_config.cluster_config.name
}
