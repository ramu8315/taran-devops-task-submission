resource "kubernetes_namespace_v1" "score_api" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret_v1" "score_api_auth" {
  metadata {
    name      = "score-api-auth"
    namespace = kubernetes_namespace_v1.score_api.metadata[0].name
  }

  type = "Opaque"

  string_data = {
    password = var.basic_auth_password
  }
}

resource "helm_release" "score_api" {
  name             = "score-api"
  namespace        = kubernetes_namespace_v1.score_api.metadata[0].name
  create_namespace = false
  chart            = "${path.module}/../helm/score-api"
  wait             = true
  timeout          = 180

  values = [
    yamlencode({
      image = {
        repository = var.image_repository
        tag        = var.image_tag
      }
      auth = {
        existingSecret = kubernetes_secret_v1.score_api_auth.metadata[0].name
      }
      ingress = {
        host = var.ingress_host
      }
      env = {
        logLevel       = var.log_level
        serviceVersion = var.service_version
      }
    })
  ]

  depends_on = [
    kubernetes_secret_v1.score_api_auth
  ]
}
