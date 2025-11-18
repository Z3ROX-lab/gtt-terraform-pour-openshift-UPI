# ============================================================================
# Outputs - Informations sur l'infrastructure déployée
# ============================================================================

# --- Informations Générales du Cluster ---

output "cluster_info" {
  description = "Informations générales sur le cluster OpenShift"
  value = {
    cluster_name = var.cluster_name
    base_domain  = var.base_domain
    cluster_fqdn = local.cluster_fqdn
    platform     = var.platform
    total_nodes  = 1 + var.masters_count + var.workers_count
  }
}

# --- Noeud Bootstrap ---

output "bootstrap_node" {
  description = "Informations complètes sur le noeud bootstrap"
  value = {
    hostname   = local.bootstrap_metadata.hostname
    fqdn       = local.bootstrap_metadata.fqdn
    role       = local.bootstrap_metadata.role
    ip_address = local.bootstrap_ip
    resources = {
      cpu       = var.bootstrap_cpu
      memory_mb = var.bootstrap_memory
      disk_gb   = var.bootstrap_disk_size
    }
    ignition_file = var.bootstrap_ignition
  }
}

output "bootstrap_ip" {
  description = "Adresse IP du noeud bootstrap"
  value       = local.bootstrap_ip
}

output "bootstrap_hostname" {
  description = "Nom d'hôte du noeud bootstrap"
  value       = local.bootstrap_metadata.hostname
}

# --- Noeuds Master ---

output "master_nodes" {
  description = "Informations complètes sur tous les noeuds master"
  value = [
    for i in range(var.masters_count) : {
      hostname   = local.master_metadata[i].hostname
      fqdn       = local.master_metadata[i].fqdn
      role       = local.master_metadata[i].role
      ip_address = local.master_ips[i]
      index      = i
      resources = {
        cpu       = var.master_cpu
        memory_mb = var.master_memory
        disk_gb   = var.master_disk_size
      }
      ignition_file = var.master_ignition
    }
  ]
}

output "master_ips" {
  description = "Liste des adresses IP des noeuds master"
  value       = local.master_ips
}

output "master_hostnames" {
  description = "Liste des noms d'hôte des noeuds master"
  value       = [for m in local.master_metadata : m.hostname]
}

output "master_fqdns" {
  description = "Liste des FQDN des noeuds master"
  value       = [for m in local.master_metadata : m.fqdn]
}

# --- Noeuds Worker ---

output "worker_nodes" {
  description = "Informations complètes sur tous les noeuds worker"
  value = [
    for i in range(var.workers_count) : {
      hostname   = local.worker_metadata[i].hostname
      fqdn       = local.worker_metadata[i].fqdn
      role       = local.worker_metadata[i].role
      ip_address = local.worker_ips[i]
      index      = i
      resources = {
        cpu       = var.worker_cpu
        memory_mb = var.worker_memory
        disk_gb   = var.worker_disk_size
      }
      ignition_file = var.worker_ignition
    }
  ]
}

output "worker_ips" {
  description = "Liste des adresses IP des noeuds worker"
  value       = local.worker_ips
}

output "worker_hostnames" {
  description = "Liste des noms d'hôte des noeuds worker"
  value       = [for w in local.worker_metadata : w.hostname]
}

output "worker_fqdns" {
  description = "Liste des FQDN des noeuds worker"
  value       = [for w in local.worker_metadata : w.fqdn]
}

# --- Résumé de l'Infrastructure ---

output "infrastructure_summary" {
  description = "Résumé complet de l'infrastructure déployée"
  value = {
    bootstrap = {
      count = 1
      total_cpu = var.bootstrap_cpu
      total_memory_gb = var.bootstrap_memory / 1024
      hostnames = [local.bootstrap_metadata.hostname]
      ips = [local.bootstrap_ip]
    }
    masters = {
      count = var.masters_count
      total_cpu = var.masters_count * var.master_cpu
      total_memory_gb = (var.masters_count * var.master_memory) / 1024
      hostnames = [for m in local.master_metadata : m.hostname]
      ips = local.master_ips
    }
    workers = {
      count = var.workers_count
      total_cpu = var.workers_count * var.worker_cpu
      total_memory_gb = (var.workers_count * var.worker_memory) / 1024
      hostnames = [for w in local.worker_metadata : w.hostname]
      ips = local.worker_ips
    }
    totals = {
      nodes = 1 + var.masters_count + var.workers_count
      cpu = var.bootstrap_cpu + (var.masters_count * var.master_cpu) + (var.workers_count * var.worker_cpu)
      memory_gb = (var.bootstrap_memory + (var.masters_count * var.master_memory) + (var.workers_count * var.worker_memory)) / 1024
    }
  }
}

# --- Outputs pour DNS et Load Balancer ---

output "dns_records" {
  description = "Enregistrements DNS à créer (format pour documentation)"
  value = {
    api = {
      record = "api.${local.cluster_fqdn}"
      type   = "A"
      target = "Load Balancer IP (vers masters)"
      note   = "Utilisé pour accéder à l'API Kubernetes"
    }
    api_int = {
      record = "api-int.${local.cluster_fqdn}"
      type   = "A"
      target = "Load Balancer IP (vers masters)"
      note   = "Utilisé pour les communications internes"
    }
    apps_wildcard = {
      record = "*.apps.${local.cluster_fqdn}"
      type   = "A"
      target = "Load Balancer IP (vers workers)"
      note   = "Wildcard pour les routes applicatives"
    }
    etcd_records = [
      for i in range(var.masters_count) : {
        record = "etcd-${i}.${local.cluster_fqdn}"
        type   = "A"
        target = local.master_ips[i]
        note   = "etcd member ${i}"
      }
    ]
    etcd_srv = {
      record   = "_etcd-server-ssl._tcp.${local.cluster_fqdn}"
      type     = "SRV"
      priority = 0
      weight   = 10
      port     = 2380
      targets  = [for i in range(var.masters_count) : "etcd-${i}.${local.cluster_fqdn}"]
      note     = "SRV record pour la découverte etcd"
    }
  }
}

output "load_balancer_config" {
  description = "Configuration suggérée pour le load balancer"
  value = {
    api_backend = {
      port    = 6443
      targets = [for ip in local.master_ips : "${ip}:6443"]
      note    = "API Kubernetes sur les masters"
    }
    machine_config_backend = {
      port    = 22623
      targets = [for ip in local.master_ips : "${ip}:22623"]
      note    = "Machine Config Server sur les masters"
    }
    ingress_http_backend = {
      port    = 80
      targets = [for ip in local.worker_ips : "${ip}:80"]
      note    = "HTTP Ingress sur les workers"
    }
    ingress_https_backend = {
      port    = 443
      targets = [for ip in local.worker_ips : "${ip}:443"]
      note    = "HTTPS Ingress sur les workers"
    }
  }
}

# --- Outputs pour Ansible ou Configuration Post-Déploiement ---

output "ansible_inventory" {
  description = "Inventaire au format pour Ansible (structure de données)"
  value = {
    all = {
      vars = {
        cluster_name = var.cluster_name
        base_domain  = var.base_domain
      }
      children = {
        bootstrap = {
          hosts = {
            "${local.bootstrap_metadata.hostname}" = {
              ansible_host = local.bootstrap_ip
              node_role    = "bootstrap"
            }
          }
        }
        masters = {
          hosts = {
            for i in range(var.masters_count) :
            local.master_metadata[i].hostname => {
              ansible_host = local.master_ips[i]
              node_role    = "master"
              node_index   = i
            }
          }
        }
        workers = {
          hosts = {
            for i in range(var.workers_count) :
            local.worker_metadata[i].hostname => {
              ansible_host = local.worker_ips[i]
              node_role    = "worker"
              node_index   = i
            }
          }
        }
      }
    }
  }
}

# --- Outputs pour la Validation et le Monitoring ---

output "validation_commands" {
  description = "Commandes de validation à exécuter après le déploiement"
  value = {
    check_bootstrap = "ssh core@${local.bootstrap_ip} 'sudo systemctl status bootkube.service'"
    check_masters = [
      for ip in local.master_ips :
      "ssh core@${ip} 'sudo crictl ps'"
    ]
    check_workers = [
      for ip in local.worker_ips :
      "ssh core@${ip} 'sudo crictl ps'"
    ]
    openshift_install = "openshift-install wait-for bootstrap-complete --log-level=info"
  }
}

# --- Output Formaté pour Affichage Console ---

output "deployment_summary" {
  description = "Résumé du déploiement (format lisible)"
  value = <<-EOT
    ========================================
    Cluster OpenShift UPI - Résumé
    ========================================

    Cluster: ${var.cluster_name}.${var.base_domain}
    Plateforme: ${var.platform}

    Bootstrap:
      - ${local.bootstrap_metadata.hostname} (${local.bootstrap_ip})

    Masters (${var.masters_count}):
    %{for i in range(var.masters_count)~}
      - ${local.master_metadata[i].hostname} (${local.master_ips[i]})
    %{endfor~}

    Workers (${var.workers_count}):
    %{for i in range(var.workers_count)~}
      - ${local.worker_metadata[i].hostname} (${local.worker_ips[i]})
    %{endfor~}

    Ressources Totales:
      - Noeuds: ${1 + var.masters_count + var.workers_count}
      - vCPUs: ${var.bootstrap_cpu + (var.masters_count * var.master_cpu) + (var.workers_count * var.worker_cpu)}
      - RAM: ${(var.bootstrap_memory + (var.masters_count * var.master_memory) + (var.workers_count * var.worker_memory)) / 1024} GB

    ========================================
  EOT
}
