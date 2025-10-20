# Monitoring Stack Module (kube-prometheus-stack)

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.chart_version
  
  timeout    = 900  # Increased to 15 minutes
  wait       = true
  wait_for_jobs = true

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention                    = var.prometheus_retention
          retentionSize               = var.prometheus_retention_size
          resources                   = var.prometheus_resources
          storageSpec = var.enable_prometheus_persistence ? {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
              }
            }
          } : null
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
        }
      }
      grafana = {
        enabled = true
        adminPassword = var.grafana_admin_password
        resources     = var.grafana_resources
        persistence = {
          enabled = var.enable_grafana_persistence
          size    = var.grafana_storage_size
        }
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [{
              name            = "default"
              orgId           = 1
              folder          = ""
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            }]
          }
        }
      }
      alertmanager = {
        enabled = true
        alertmanagerSpec = {
          retention  = var.alertmanager_retention
          resources  = var.alertmanager_resources
        }
      }
      kubeStateMetrics = {
        enabled = true
      }
      nodeExporter = {
        enabled = true
      }
      prometheusOperator = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }
    })
  ]

  depends_on = [var.eks_cluster_ready]
}
