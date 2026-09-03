variable "namespace" {
  description = "Kubernetes namespace for the Score API."
  type        = string
  default     = "score-api"
}

variable "basic_auth_password" {
  description = "Password used by the Score API /decision endpoint."
  type        = string
  sensitive   = true
}

variable "image_repository" {
  description = "Container image repository/name."
  type        = string
  default     = "score-api"
}

variable "image_tag" {
  description = "Container image tag."
  type        = string
  default     = "local"
}

variable "kubeconfig_path" {
  description = "Path to the Kubernetes kubeconfig."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubernetes context to use."
  type        = string
  default     = "minikube"
}

variable "ingress_host" {
  description = "Hostname exposed by the Helm Ingress."
  type        = string
  default     = "score-api.local"
}

variable "log_level" {
  description = "Application log level."
  type        = string
  default     = "INFO"
}

variable "service_version" {
  description = "Version returned by /healthz."
  type        = string
  default     = "local"
}
