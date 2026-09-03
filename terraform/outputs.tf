output "namespace" {
  value = kubernetes_namespace_v1.score_api.metadata[0].name
}

output "release_name" {
  value = helm_release.score_api.name
}

output "ingress_host" {
  value = var.ingress_host
}
