resource "kubernetes_deployment" "argocd_redis_ha_haproxy" {
  metadata {
    name = "argocd-redis-ha-haproxy"
    labels = {
      "app.kubernetes.io/component": "redis"
      "app.kubernetes.io/name": "argocd-redis-ha-haproxy"
      "app.kubernetes.io/part-of": "argocd"
    }
  }
  spec {
    replicas = 3
    revision_history_limit = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name": "argocd-redis-ha-haproxy"
      }
    }
    strategy {
      type = "RollingUpdate"
    }
    template {
      metadata {
        name = "argocd-redis-ha-haproxy"
        labels = {
          "app.kubernetes.io/name": "argocd-redis-ha-haproxy"
        }
        annotations = {
          "checksum/config": "790be9eae7c7e468c497c0256949ab96cb3f14b935c6702424647c3c60fba91c"
        }
      }
      spec {
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                topology_key = "failure-domain.beta.kubernetes.io/zone"
                label_selector {
                  match_labels = {
                    "app.kubernetes.io/name": "argocd-redis-ha-haproxy"
                  }
                }
              }
            }
            required_during_scheduling_ignored_during_execution {
              topology_key = "kubernetes.io/hostname"
              label_selector {
                match_labels = {
                  "app.kubernetes.io/name": "argocd-redis-ha-haproxy"
                }
              }
            }
          }
        }
        container {
          name = "haproxy"
          image = "${var.image_repository}/haproxy:${var.haproxy_version}"
          image_pull_policy = var.image_pull_policy
          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8888
            }
            initial_delay_seconds = 5
            period_seconds = 3
          }
          port {
            name = "redis"
            container_port = 6379
          }
          # TODO: Resource requirements will need to be declared
          resources {}
          volume_mount {
            name = "shared-socket"
            mount_path = "/usr/local/etc/haproxy"
          }
        }
        init_container {
          name = "config-init"
          image = "${var.image_repository}/haproxy:${var.haproxy_version}"
          image_pull_policy = var.image_pull_policy
          command = ["sh"]
          args = ["/readonly/haproxy_init.sh"]
          # TODO: Resource requirements will need to be declared
          resources {}
          volume_mount {
            name = "config-volume"
            mount_path = "/readonly"
            read_only = true
          }
          volume_mount {
            name = "data"
            mount_path = "/data"
          }
        }
        security_context {
          run_as_non_root = var.run_as_non_root
          fs_group = var.fs_group
          run_as_user = var.run_as_user
        }
        service_account_name = "argocd-redis-ha-haproxy"
        volume {
          name = "config-volume"
          config_map {
            name = "argocd-redis-ha-configmap"
          }
        }
        volume {
          name = "shared-socket"
          empty_dir {}
        }
        volume {
          name = "data"
          empty_dir {}
        }
      }
    }
  }
}