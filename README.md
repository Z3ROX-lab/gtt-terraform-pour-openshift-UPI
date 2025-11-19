# Terraform pour OpenShift UPI (User Provisioned Infrastructure)

## 📋 Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Architecture OpenShift UPI](#architecture-openshift-upi)
- [Diagrammes Interactifs](#diagrammes-interactifs)
- [Structure du projet](#structure-du-projet)
- [Prérequis](#prérequis)
- [Utilisation](#utilisation)
- [Décisions de design](#décisions-de-design)
- [Adaptation à des providers spécifiques](#adaptation-à-des-providers-spécifique)
- [Points clés pour la présentation](#points-clés-pour-la-présentation)

## 🎯 Vue d'ensemble

Ce projet Terraform modélise l'infrastructure nécessaire au déploiement d'un cluster **OpenShift 4** en mode **UPI (User Provisioned Infrastructure)**.

### Qu'est-ce qu'OpenShift UPI ?

OpenShift peut être déployé de deux manières :

- **IPI (Installer Provisioned Infrastructure)** : L'installeur gère automatiquement le provisionnement de l'infrastructure (AWS, Azure, GCP)
- **UPI (User Provisioned Infrastructure)** : L'utilisateur provisionne manuellement l'infrastructure (VMs, réseau, stockage)

Le mode UPI est utilisé dans les cas suivants :
- Environnements on-premise (VMware, Nutanix, KVM, bare metal)
- **Cloud public** (AWS, Azure, GCP) avec contrôle personnalisé
- Architectures **hybrides** (on-premise + cloud)
- Besoin de contrôle granulaire sur l'infrastructure
- Restrictions de sécurité ou de conformité
- Plateformes non supportées en mode IPI

### Plateformes supportées par ce code

Ce projet Terraform supporte **toutes les plateformes OpenShift UPI** :

#### On-Premise / Private Cloud
- ✅ **Nutanix** AHV
- ✅ **VMware vSphere**
- ✅ **Red Hat Virtualization** (RHV)
- ✅ **Red Hat OpenStack** Platform
- ✅ **KVM** / libvirt
- ✅ **Bare Metal**

#### Cloud Public
- ✅ **AWS** (EC2)
- ✅ **Microsoft Azure** (VMs)
- ✅ **Google Cloud** (Compute Engine)
- ✅ **IBM Cloud**
- ✅ **Alibaba Cloud**

#### Hybride
- ✅ **Generic** : Code portable pour architectures multi-cloud

> 💡 **Pour GTT** : Ce code supporte l'architecture IA hybride mentionnée dans l'offre - données sensibles on-premise (Nutanix) + compute élastique cloud (Azure/AWS).

## 🏗️ Architecture OpenShift UPI

### Composants du cluster

Un cluster OpenShift UPI comprend **3 types de noeuds** :

#### 1. **Bootstrap** (temporaire)
- **Rôle** : Initialiser le cluster en démarrant les premiers composants du control plane
- **Cycle de vie** : Détruit après l'installation complète
- **Héberge** :
  - Machine Config Server (port 22623)
  - Services d'amorçage temporaires
- **Ressources minimales** : 4 vCPU, 16 GB RAM, 120 GB disque

#### 2. **Masters** (control plane)
- **Rôle** : Gérer le control plane du cluster
- **Nombre** : Toujours impair (3, 5, 7) pour le quorum etcd
- **Héberge** :
  - **API Server** : API Kubernetes (port 6443)
  - **etcd** : Base de données distribuée pour l'état du cluster (port 2379-2380)
  - **Controller Manager** : Boucles de contrôle Kubernetes
  - **Scheduler** : Planification des pods
  - **Machine Config Operator** : Gestion de la configuration des noeuds
- **Ressources minimales** : 4 vCPU, 16 GB RAM, 120 GB disque
- **Ressources recommandées** : 8+ vCPU, 32 GB RAM, 200 GB disque

#### 3. **Workers** (compute)
- **Rôle** : Exécuter les workloads applicatifs
- **Nombre** : Minimum 2 pour la haute disponibilité
- **Héberge** :
  - Pods applicatifs
  - Ingress Controllers (Router)
  - Monitoring, Logging
- **Ressources minimales** : 2 vCPU, 8 GB RAM, 120 GB disque
- **Ressources recommandées** : 8+ vCPU, 16-32 GB RAM, 200 GB disque

### Fichiers Ignition

OpenShift utilise **Ignition** pour configurer les noeuds au premier démarrage :

- **Ignition** est un système de provisionnement bas niveau pour Red Hat CoreOS (RHCOS)
- Chaque type de noeud a son propre fichier `.ign` généré par `openshift-install`
- Les fichiers Ignition contiennent :
  - Configuration réseau
  - Certificats et secrets
  - Configuration du kubelet
  - Scripts de démarrage

### Flux de déploiement

```
1. Provisionnement Infrastructure (Terraform)
   ├── Création des VMs
   ├── Configuration réseau
   └── Injection des fichiers Ignition

2. Démarrage Bootstrap
   ├── Bootstrap démarre et héberge le Machine Config Server
   └── Bootstrap démarre les premiers containers du control plane

3. Démarrage Masters
   ├── Masters récupèrent leur config depuis Bootstrap
   ├── Masters démarrent etcd et forment le quorum
   └── Masters démarrent l'API Server et les controllers

4. Transition du Control Plane
   ├── Control plane migre de Bootstrap vers Masters
   └── Bootstrap peut être supprimé

5. Démarrage Workers
   ├── Workers récupèrent leur config
   ├── Workers rejoignent le cluster
   └── Workers démarrent les pods système
```

## 📊 Diagrammes Interactifs

Pour une visualisation complète et interactive de l'architecture, consultez **[DIAGRAMS_MERMAID.md](DIAGRAMS_MERMAID.md)** qui contient 8 diagrammes Mermaid :

1. **Architecture Générale** - Vue d'ensemble du cluster avec bootstrap, masters, workers
2. **Flux de Déploiement** - Étapes complètes de Terraform init jusqu'au cluster opérationnel
3. **Architecture Réseau** - DNS, Load Balancer, VLANs, allocation IPs
4. **Flux de Requête HTTP** - Lifecycle d'une requête depuis le client jusqu'au pod
5. **Structure Terraform** - Flow des variables, locals, ressources, et outputs
6. **Haute Disponibilité** - Scénarios de panne et tolérance aux pannes
7. **Sécurité Zero Trust** - 4 couches de défense (réseau, identité, chiffrement, monitoring)
8. **Lifecycle OpenShift UPI** - State diagram du déploiement à la mise hors service

> 💡 **Astuce** : Ces diagrammes s'affichent automatiquement sur GitHub et dans la plupart des éditeurs Markdown modernes. Imprimez-les pour vos présentations !

## 📁 Structure du projet

```
.
├── main.tf                      # Ressources principales (VMs)
├── variables.tf                 # Définition des variables
├── outputs.tf                   # Outputs (IPs, noms, résumés)
├── terraform.tfvars.example     # Exemple de configuration
├── .gitignore                   # Exclusion fichiers sensibles
├── README.md                    # Cette documentation
├── DIAGRAMS_MERMAID.md          # Diagrammes interactifs Mermaid
├── ARCHITECTURE.md              # Diagrammes ASCII détaillés
├── GUIDE_PREPARATION.md         # Guide de préparation technique
└── POINTS_CLES_EXPLICATIONS.md  # Explications par fichier
```

### Fichiers détaillés

#### `variables.tf`
Contient **toutes les variables paramétrables** :
- Configuration du cluster (nom, domaine)
- Compteurs de noeuds (masters, workers)
- Ressources CPU/RAM/Disque pour chaque type de noeud
- Chemins des fichiers Ignition
- Configuration réseau
- Tags et labels
- Validations pour garantir la cohérence

#### `main.tf`
Définit **les ressources Terraform** :
- Configuration du provider
- Calculs dans `locals` (IPs, métadonnées)
- Ressources pour le bootstrap (1 VM)
- Ressources pour les masters (count)
- Ressources pour les workers (count)
- Exemples commentés pour Nutanix et vSphere

#### `outputs.tf`
Fournit **des informations utiles** après déploiement :
- Informations générales du cluster
- Liste des noeuds (bootstrap, masters, workers)
- Adresses IP et FQDN
- Configuration DNS recommandée
- Configuration Load Balancer
- Inventaire Ansible
- Commandes de validation

## 🔧 Prérequis

### Logiciels requis

```bash
# Terraform
terraform version  # >= 1.0

# OpenShift Installer (pour générer les fichiers Ignition)
openshift-install version  # >= 4.12

# (Optionnel) oc CLI
oc version
```

### Fichiers Ignition

Les fichiers Ignition doivent être générés **avant** d'exécuter Terraform :

```bash
# 1. Créer un répertoire pour l'installation
mkdir ocp-install
cd ocp-install

# 2. Créer install-config.yaml
cat <<EOF > install-config.yaml
apiVersion: v1
baseDomain: company.local
compute:
- name: worker
  replicas: 0  # UPI : workers ajoutés manuellement
controlPlane:
  name: master
  replicas: 3
metadata:
  name: ocp-prod
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {}  # UPI
pullSecret: '...'
sshKey: 'ssh-rsa ...'
EOF

# 3. Générer les manifests
openshift-install create manifests --dir=.

# 4. (Optionnel) Modifier les manifests

# 5. Générer les fichiers Ignition
openshift-install create ignition-configs --dir=.

# Résultat : bootstrap.ign, master.ign, worker.ign
```

## 🚀 Utilisation

### 1. Configuration

```bash
# Copier le fichier d'exemple
cp terraform.tfvars.example terraform.tfvars

# Éditer les valeurs
vim terraform.tfvars
```

Exemple de configuration minimale :

```hcl
cluster_name = "ocp-prod"
base_domain  = "company.local"

masters_count = 3
workers_count = 3

bootstrap_ignition = "./ocp-install/bootstrap.ign"
master_ignition    = "./ocp-install/master.ign"
worker_ignition    = "./ocp-install/worker.ign"

platform = "nutanix"
```

### 2. Initialisation

```bash
terraform init
```

### 3. Planification

```bash
terraform plan
```

### 4. Déploiement

```bash
terraform apply
```

### 5. Visualiser les outputs

```bash
# Tous les outputs
terraform output

# Un output spécifique
terraform output bootstrap_ip
terraform output master_ips
terraform output deployment_summary
```

### 6. Post-déploiement

Après le déploiement Terraform, suivre le processus d'installation OpenShift :

```bash
# Attendre que le bootstrap soit prêt (15-30 min)
openshift-install wait-for bootstrap-complete --log-level=info

# Une fois terminé, supprimer le bootstrap
terraform destroy -target=null_resource.bootstrap_node

# Attendre que l'installation soit complète (30-60 min)
openshift-install wait-for install-complete --log-level=info
```

## 🎨 Décisions de design

### 1. Provider générique (null_resource)

**Choix** : Utilisation du provider `null` avec des `local-exec` provisioners

**Rationale** :
- ✅ **Portable** : Fonctionne sans dépendance à un provider spécifique
- ✅ **Démonstratif** : Montre la structure sans complexité d'un vrai provider
- ✅ **Adaptable** : Facile à convertir vers Nutanix, vSphere, KVM
- ⚠️ Ne crée pas de vraies VMs (seulement pour démonstration)

**En production** : Remplacer par un vrai provider (voir exemples dans main.tf)

### 2. Séparation des variables

**Choix** : Variables dédiées pour chaque type de noeud (bootstrap, master, worker)

**Rationale** :
- ✅ **Flexibilité** : Permet de dimensionner différemment chaque type
- ✅ **Clarté** : Explicite sur les ressources allouées
- ✅ **Validation** : Garantit le respect des minimums OpenShift

### 3. Locals pour les calculs

**Choix** : Utilisation de `locals` pour calculer IPs et métadonnées

**Rationale** :
- ✅ **DRY** : Pas de répétition de code
- ✅ **Maintenance** : Changements centralisés
- ✅ **Lisibilité** : Logique métier séparée de la configuration

#### ⚠️ IPs Statiques vs DHCP en Production

**Dans ce code (démo)** :
- Utilisation de `ip_range_start = "192.168.50.10"` pour calculer les IPs séquentiellement
- Nécessaire car `null_resource` ne crée pas de vraies VMs avec interfaces réseau

**En production réelle** :

| Type de Noeud | IP | Raison |
|---------------|-----|--------|
| **Masters** | ⚠️ **OBLIGATOIREMENT statiques** | Exigence Red Hat : DNS A records, etcd SRV records, stabilité control plane |
| **Workers** | ✅ DHCP possible | Terraform récupère les IPs via attributs computed (`vm.default_ip_address`) |
| **Bootstrap** | ✅ DHCP possible | Noeud temporaire (supprimé après installation) |

**Exemple adaptation avec IPs statiques (Masters) et DHCP (Workers)** :

```hcl
# variables.tf - IPs statiques pour masters
variable "master_static_ips" {
  description = "IPs statiques pour les masters (exigence OpenShift UPI)"
  type        = list(string)
  default     = ["192.168.50.11", "192.168.50.12", "192.168.50.13"]
}

# main.tf - Nutanix exemple
resource "nutanix_virtual_machine" "master_nodes" {
  count = var.masters_count
  name  = "ocp-master-${count.index}"

  nic_list {
    subnet_uuid = data.nutanix_subnet.ocp_network.id
    # IP statique assignée
    ip_endpoint_list {
      ip   = var.master_static_ips[count.index]
      type = "ASSIGNED"
    }
  }
}

resource "nutanix_virtual_machine" "worker_nodes" {
  count = var.workers_count
  name  = "ocp-worker-${count.index}"

  nic_list {
    subnet_uuid = data.nutanix_subnet.ocp_network.id
    # Pas d'ip_endpoint_list → DHCP automatique
  }
}

# outputs.tf - Récupération des IPs
output "master_ips" {
  description = "IPs statiques des masters"
  value       = var.master_static_ips
}

output "worker_ips" {
  description = "IPs assignées par DHCP aux workers"
  value       = [for vm in nutanix_virtual_machine.worker_nodes :
                 vm.nic_list[0].ip_endpoint_list[0].ip]
}
```

**Recommandations GTT** :
- 🔴 **Masters** : Toujours IPs statiques + réservations DHCP (MAC binding)
- 🟢 **Workers** : DHCP acceptable si DNS dynamique configuré (ddns-update-style interim)
- 🔵 **Best Practice** : Même avec DHCP, créer des réservations par adresse MAC dans le serveur DHCP

### 4. Outputs détaillés

**Choix** : Outputs riches avec informations DNS, LB, Ansible

**Rationale** :
- ✅ **Utilisabilité** : Toutes les infos nécessaires en un coup d'oeil
- ✅ **Automation** : Facilite l'intégration avec d'autres outils
- ✅ **Documentation** : Auto-documention de l'infrastructure

### 5. Validations strictes

**Choix** : Validations sur les variables (count impair pour masters, minimums CPU/RAM)

**Rationale** :
- ✅ **Sécurité** : Empêche les erreurs de configuration
- ✅ **Conformité** : Respecte les exigences OpenShift
- ✅ **Feedback** : Messages d'erreur clairs pour l'utilisateur

## 🔄 Adaptation à des providers spécifiques

Le code actuel utilise `null_resource` pour la démonstration. Voici comment l'adapter :

### Nutanix

```hcl
# Provider
terraform {
  required_providers {
    nutanix = {
      source  = "nutanix/nutanix"
      version = "~> 1.9"
    }
  }
}

provider "nutanix" {
  username     = var.nutanix_username
  password     = var.nutanix_password
  endpoint     = var.nutanix_endpoint
  insecure     = false
  port         = 9440
  wait_timeout = 60
}

# Ressource Master
resource "nutanix_virtual_machine" "master" {
  count                = var.masters_count
  name                 = local.master_metadata[count.index].hostname
  cluster_uuid         = data.nutanix_cluster.cluster.id
  num_vcpus_per_socket = var.master_cpu
  num_sockets          = 1
  memory_size_mib      = var.master_memory

  disk_list {
    data_source_reference = {
      kind = "image"
      uuid = data.nutanix_image.rhcos.id
    }
    disk_size_mib = var.master_disk_size * 1024
  }

  nic_list {
    subnet_uuid = data.nutanix_subnet.subnet.id
  }

  guest_customization_cloud_init_user_data = base64encode(file(var.master_ignition))

  categories {
    name  = "openshift-role"
    value = "master"
  }
}
```

### VMware vSphere

```hcl
# Provider
terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.5"
    }
  }
}

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = false
}

# Ressource Master
resource "vsphere_virtual_machine" "master" {
  count            = var.masters_count
  name             = local.master_metadata[count.index].hostname
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus = var.master_cpu
  memory   = var.master_memory

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  disk {
    label            = "disk0"
    size             = var.master_disk_size
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.rhcos_template.id
  }

  extra_config = {
    "guestinfo.ignition.config.data"          = base64encode(file(var.master_ignition))
    "guestinfo.ignition.config.data.encoding" = "base64"
  }
}
```

### KVM/libvirt

```hcl
# Provider
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Ressource Master
resource "libvirt_domain" "master" {
  count  = var.masters_count
  name   = local.master_metadata[count.index].hostname
  memory = var.master_memory
  vcpu   = var.master_cpu

  disk {
    volume_id = libvirt_volume.master[count.index].id
  }

  network_interface {
    network_name   = var.network_name
    wait_for_lease = true
  }

  coreos_ignition = libvirt_ignition.master.id
}

resource "libvirt_ignition" "master" {
  name    = "master-ignition"
  content = file(var.master_ignition)
}
```

## 📝 Points clés pour la présentation

### Compréhension d'OpenShift UPI

**Note** : *Différence entre IPI et UPI*

- **IPI** : Mode automatisé où l'installeur OpenShift crée toute l'infrastructure (cloud public)
- **UPI** : Mode manuel où l'utilisateur provisionne l'infrastructure (on-premise, contrôle total)
- **Cas d'usage UPI** : Nutanix, VMware, bare metal, AWS, Azure, GCP, restrictions de sécurité, environnements air-gapped

**Note** : *3 masters minimum*

- **etcd** nécessite un quorum pour fonctionner
- Quorum = (n/2) + 1
- Avec 3 masters : on tolère 1 panne (quorum = 2/3)
- Toujours un nombre impair (3, 5, 7) pour éviter le split-brain

### Terraform

**Note** : *Structure du code*

- **Séparation des concerns** : variables, ressources, outputs dans des fichiers dédiés
- **Réutilisabilité** : Facile de créer des modules
- **Maintenabilité** : Code clair et bien commenté
- **Validation** : Prévention des erreurs de configuration

**Note** : *Adaptabilité du code*

- Variables pour tous les paramètres importants
- Provider générique facilement remplaçable
- Exemples pour Nutanix, vSphere, KVM dans le code
- Outputs riches pour intégration avec d'autres outils

### Sécurité (SecOps)

**Note** : *Aspects de sécurité considérés*

- **Ignition** : Configuration sécurisée dès le boot (immuable)
- **Secure Boot** : Variable pour activer (conformité)
- **vTPM** : Support pour le chiffrement
- **Tags/Labels** : Métadonnées (clé-valeur) pour identification des ressources, RBAC, facturation, automation (ex: `role=master`, `team=platform`)
- **Validations** : Prévention de configurations non conformes (shift-left security)
- **Séparation réseau** : Masters et workers isolables (VLANs, NetworkPolicies, SCC)
- **Secrets Management** : HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, External Secrets Operator
- **Encryption** : At-rest (etcd natif, PV, VM disks), In-transit (mTLS natif, Ingress TLS)
- **Compliance** : OpenSCAP natif (Compliance Operator), Prowler pour clouds publics

**Note** : *Sécurisation des fichiers Ignition*

- Ne jamais commiter les `.ign` dans Git
- Utiliser des backends Terraform chiffrés (S3 + KMS, Azure Blob + encryption)
- Variables sensibles via Vault ou cloud secret managers
- Rotation des certificats générés
- Permissions restrictives sur les fichiers (600)

### Architecture Réseau et Load Balancing

**Note** : *Besoins réseau pour OpenShift UPI*

- **Load Balancer** requis (non géré par Terraform dans cet exercice) :
  - API (6443) → Masters
  - Machine Config (22623) → Masters (durant install)
  - HTTP/HTTPS (80/443) → Workers (Ingress)
- **DNS** requis :
  - `api.cluster.domain` → LB masters
  - `api-int.cluster.domain` → LB masters
  - `*.apps.cluster.domain` → LB workers
  - SRV records pour etcd

**Note** : *Gestion DNS et Load Balancer*

- Hors scope de cet exercice (précisé dans le brief)
- Mais outputs fournis pour faciliter la configuration
- En production : Terraform peut aussi gérer DNS (Route53, Azure DNS)
- LB : F5, HAProxy, NGINX, ou LB natif du provider

### Démonstration pratique

1. **Expliquer chaque section** de `variables.tf`, `main.tf`, `outputs.tf`
2. **Montrer un plan Terraform** : `terraform plan`
3. **Expliquer les outputs** : Comment les utiliser pour la suite
4. **Discuter des adaptations** : Comment passer à Nutanix réel
5. **Parler d'évolutions** : Modules, workspaces, remote state

### Questions de sécurité avancées

**Note** : *Audit de l'infrastructure*

- **Terraform state** contient toute la config (audit trail)
- **Tags/Labels** permettent le tracking des ressources (qui a créé quoi, pour quel projet)
- **Outputs** fournissent inventaire pour scanning de sécurité
- **Intégration CI/CD** : `terraform plan` en PR pour review
- **Policy-as-Code** : Sentinel, OPA pour valider la conformité

**Note** : *Gestion des secrets*

- **Ne jamais** mettre de secrets en clair dans `.tf` ou `.tfvars`
- Utiliser :
  - Terraform Cloud/Enterprise (encrypted variables)
  - Vault provider
  - AWS Secrets Manager / Azure Key Vault
  - Variables d'environnement (`TF_VAR_*`)
- **State encryption** : Backend S3 + KMS, Azure + encryption

### Évolutions possibles

**Note** : *Évolution du code*

- **Modules** : Créer un module réutilisable `openshift-upi`
- **Workspaces** : Gérer dev/staging/prod
- **Remote State** : S3, Azure Blob, Terraform Cloud
- **CI/CD** : GitLab CI, GitHub Actions pour `terraform plan/apply`
- **Monitoring** : Intégration avec Datadog, Prometheus
- **Backup** : Automation des backups etcd
- **Disaster Recovery** : Scripts de restauration

## 📚 Ressources complémentaires

- [OpenShift Documentation - UPI](https://docs.openshift.com/container-platform/latest/installing/installing_platform_agnostic/installing-platform-agnostic.html)
- [Red Hat CoreOS Ignition](https://coreos.github.io/ignition/)
- [Terraform Nutanix Provider](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs)
- [Terraform vSphere Provider](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs)
- [OpenShift Network Requirements](https://docs.openshift.com/container-platform/latest/installing/installing_platform_agnostic/installing-platform-agnostic.html#installation-network-user-infra_installing-platform-agnostic)

---

**Bonne chance pour votre présentation !** 🚀
