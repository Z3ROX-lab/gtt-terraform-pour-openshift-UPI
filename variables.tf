# ============================================================================
# Variables pour le déploiement OpenShift UPI
# ============================================================================

# --- Configuration du Cluster ---
variable "cluster_name" {
  description = "Nom du cluster OpenShift"
  type        = string
  default     = "ocp-cluster"

  validation {
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 27
    error_message = "Le nom du cluster doit contenir entre 1 et 27 caractères."
  }
}

variable "base_domain" {
  description = "Domaine de base pour le cluster OpenShift"
  type        = string
  default     = "example.com"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$", var.base_domain))
    error_message = "Le domaine de base doit être un nom de domaine valide."
  }
}

# --- Compteurs de Noeuds ---
variable "masters_count" {
  description = "Nombre de noeuds master (doit être impair pour le quorum etcd)"
  type        = number
  default     = 3

  validation {
    condition     = var.masters_count >= 3 && var.masters_count % 2 == 1
    error_message = "Le nombre de masters doit être impair et au minimum 3 (pour le quorum etcd)."
  }
}

variable "workers_count" {
  description = "Nombre de noeuds worker"
  type        = number
  default     = 2

  validation {
    condition     = var.workers_count >= 2
    error_message = "Le nombre de workers doit être au minimum 2 pour la haute disponibilité."
  }
}

# --- Configuration Réseau ---
variable "network_name" {
  description = "Nom du réseau pour les VMs"
  type        = string
  default     = "ocp-network"
}

variable "network_cidr" {
  description = "CIDR du réseau pour le cluster"
  type        = string
  default     = "192.168.50.0/24"

  validation {
    condition     = can(cidrhost(var.network_cidr, 0))
    error_message = "Le CIDR réseau doit être un CIDR valide."
  }
}

variable "ip_range_start" {
  description = "Adresse IP de départ pour l'allocation des VMs"
  type        = string
  default     = "192.168.50.10"
}

# --- Configuration des ressources Bootstrap ---
variable "bootstrap_cpu" {
  description = "Nombre de vCPUs pour le noeud bootstrap"
  type        = number
  default     = 4

  validation {
    condition     = var.bootstrap_cpu >= 4
    error_message = "Le bootstrap nécessite au minimum 4 vCPUs."
  }
}

variable "bootstrap_memory" {
  description = "Mémoire RAM pour le noeud bootstrap (en MB)"
  type        = number
  default     = 16384

  validation {
    condition     = var.bootstrap_memory >= 16384
    error_message = "Le bootstrap nécessite au minimum 16 GB de RAM."
  }
}

variable "bootstrap_disk_size" {
  description = "Taille du disque pour le noeud bootstrap (en GB)"
  type        = number
  default     = 120

  validation {
    condition     = var.bootstrap_disk_size >= 120
    error_message = "Le bootstrap nécessite au minimum 120 GB de disque."
  }
}

# --- Configuration des ressources Master ---
variable "master_cpu" {
  description = "Nombre de vCPUs pour chaque noeud master"
  type        = number
  default     = 8

  validation {
    condition     = var.master_cpu >= 4
    error_message = "Chaque master nécessite au minimum 4 vCPUs."
  }
}

variable "master_memory" {
  description = "Mémoire RAM pour chaque noeud master (en MB)"
  type        = number
  default     = 16384

  validation {
    condition     = var.master_memory >= 16384
    error_message = "Chaque master nécessite au minimum 16 GB de RAM."
  }
}

variable "master_disk_size" {
  description = "Taille du disque pour chaque noeud master (en GB)"
  type        = number
  default     = 120

  validation {
    condition     = var.master_disk_size >= 120
    error_message = "Chaque master nécessite au minimum 120 GB de disque."
  }
}

# --- Configuration des ressources Worker ---
variable "worker_cpu" {
  description = "Nombre de vCPUs pour chaque noeud worker"
  type        = number
  default     = 4

  validation {
    condition     = var.worker_cpu >= 2
    error_message = "Chaque worker nécessite au minimum 2 vCPUs."
  }
}

variable "worker_memory" {
  description = "Mémoire RAM pour chaque noeud worker (en MB)"
  type        = number
  default     = 8192

  validation {
    condition     = var.worker_memory >= 8192
    error_message = "Chaque worker nécessite au minimum 8 GB de RAM."
  }
}

variable "worker_disk_size" {
  description = "Taille du disque pour chaque noeud worker (en GB)"
  type        = number
  default     = 120

  validation {
    condition     = var.worker_disk_size >= 120
    error_message = "Chaque worker nécessite au minimum 120 GB de disque."
  }
}

# --- Fichiers Ignition ---
variable "bootstrap_ignition" {
  description = "Chemin vers le fichier Ignition pour le noeud bootstrap"
  type        = string
  default     = "bootstrap.ign"
}

variable "master_ignition" {
  description = "Chemin vers le fichier Ignition pour les noeuds master"
  type        = string
  default     = "master.ign"
}

variable "worker_ignition" {
  description = "Chemin vers le fichier Ignition pour les noeuds worker"
  type        = string
  default     = "worker.ign"
}

# --- Configuration de la Plateforme ---
variable "platform" {
  description = "Plateforme de virtualisation cible (nutanix, vsphere, kvm, etc.)"
  type        = string
  default     = "generic"

  validation {
    condition     = contains(["nutanix", "vsphere", "kvm", "generic"], var.platform)
    error_message = "La plateforme doit être: nutanix, vsphere, kvm, ou generic."
  }
}

variable "image_name" {
  description = "Nom de l'image RHCOS (Red Hat CoreOS) à utiliser"
  type        = string
  default     = "rhcos-latest"
}

variable "datacenter" {
  description = "Nom du datacenter ou cluster de virtualisation"
  type        = string
  default     = "dc-01"
}

# --- Tags et Labels ---
variable "common_tags" {
  description = "Tags communs à appliquer à toutes les ressources"
  type        = map(string)
  default = {
    managed_by = "terraform"
    purpose    = "openshift-upi"
  }
}

# --- Configuration de Sécurité ---
variable "enable_secure_boot" {
  description = "Activer le Secure Boot pour les VMs"
  type        = bool
  default     = false
}

variable "enable_vtpm" {
  description = "Activer le vTPM (Virtual Trusted Platform Module) pour les VMs"
  type        = bool
  default     = false
}
