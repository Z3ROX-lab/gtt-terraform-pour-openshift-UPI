# Guide de Préparation Technique - Lead SecOps Senior

## 🎯 Objectif du poste

**Poste** : Lead SecOps Senior
**Client** : GTT (technologies de confinement cryogénique pour GNL)
**Projet** : Infrastructure IA hybride (on-premise + cloud)
**Technologies clés** : Nutanix, OpenShift, Kubernetes, CI/CD

## 📋 Structure de Présentation Recommandée

### 1. Introduction (2-3 minutes)

**Script proposé** :

> "Bonjour, je vous remercie de me recevoir. Pour cet exercice, j'ai modélisé une infrastructure OpenShift UPI complète avec Terraform. J'ai choisi une approche modulaire et portable qui peut s'adapter facilement à différentes plateformes de virtualisation, notamment Nutanix qui est mentionné dans vos besoins.
>
> Mon code déploie un cluster OpenShift conforme aux standards Red Hat : 1 noeud bootstrap temporaire, 3 noeuds masters pour le control plane avec quorum etcd, et un nombre paramétrable de workers pour les workloads applicatifs.
>
> J'ai structuré le projet en 3 fichiers principaux : variables.tf pour la configuration paramétrable, main.tf pour les ressources, et outputs.tf pour exposer les informations nécessaires à l'intégration avec le DNS et le load balancing.
>
> Si vous le souhaitez, je peux vous présenter l'architecture, puis nous pourrons parcourir le code ensemble."

### 2. Présentation de l'Architecture (5 minutes)

#### Points à aborder dans l'ordre :

**a) Contexte OpenShift UPI**
- "J'ai opté pour le mode UPI car c'est le standard pour les déploiements on-premise sur Nutanix"
- "Le mode UPI nous donne le contrôle total sur l'infrastructure, ce qui est crucial pour la sécurité"

**b) Les 3 types de noeuds**
- **Bootstrap** : "Temporaire, il initialise le cluster puis est supprimé pour réduire la surface d'attaque"
- **Masters** : "Nombre impair obligatoire pour le quorum etcd - j'ai implémenté une validation Terraform pour cela"
- **Workers** : "Hébergent les workloads - dimensionnables selon les besoins IA que vous mentionnez"

**c) Sécurité by design**
- "Fichiers Ignition pour la configuration sécurisée dès le boot"
- "Support Secure Boot et vTPM via variables"
- "Tags pour RBAC et audit"
- "Validations Terraform pour prévenir les configurations non conformes"

### 3. Démonstration du Code (10-15 minutes)

#### Parcours recommandé :

##### **variables.tf** (3-4 min)
Montrez ces sections clés :

```hcl
# 1. Variables de cluster
variable "cluster_name" {
  validation {
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 27
    error_message = "..."
  }
}
```
**Dire** : "J'ai ajouté des validations pour garantir la conformité OpenShift"

```hcl
# 2. Compteurs avec validation
variable "masters_count" {
  validation {
    condition     = var.masters_count >= 3 && var.masters_count % 2 == 1
    error_message = "..."
  }
}
```
**Dire** : "Cette validation empêche un nombre pair de masters qui casserait le quorum etcd"

```hcl
# 3. Ressources paramétrables
variable "master_cpu" {
  validation {
    condition     = var.master_cpu >= 4
    error_message = "..."
  }
}
```
**Dire** : "Toutes les ressources sont paramétrables mais respectent les minimums Red Hat"

##### **main.tf** (5-6 min)
Montrez ces sections clés :

```hcl
# 1. Locals pour les calculs
locals {
  cluster_fqdn = "${var.cluster_name}.${var.base_domain}"
  master_ips   = [for i in range(var.masters_count) : format("%s.%d", local.ip_base, local.ip_start + 1 + i)]
}
```
**Dire** : "J'ai centralisé tous les calculs dans les locals pour faciliter la maintenance"

```hcl
# 2. Ressources avec metadata
resource "null_resource" "master_nodes" {
  triggers = {
    name    = local.master_metadata[count.index].hostname
    role    = "master"
    ignition_file = var.master_ignition
  }
}
```
**Dire** : "Chaque VM est taggée avec son rôle pour faciliter l'audit et la gestion"

```hcl
# 3. Exemples commentés
/*
resource "nutanix_virtual_machine" "master" {
  ...
}
*/
```
**Dire** : "J'ai inclus des exemples pour Nutanix et vSphere, prêts à être utilisés"

##### **outputs.tf** (3-4 min)
Montrez ces outputs clés :

```hcl
# 1. Outputs de base
output "master_ips" {
  value = local.master_ips
}
```
**Dire** : "Ces outputs répondent aux exigences de l'exercice"

```hcl
# 2. Configuration DNS
output "dns_records" {
  value = {
    api = { ... }
    etcd_srv = { ... }
  }
}
```
**Dire** : "J'ai anticipé les besoins d'intégration avec le DNS et le load balancing"

```hcl
# 3. Résumé formaté
output "deployment_summary" {
  value = <<-EOT
    Cluster: ${var.cluster_name}
    Masters: ${var.masters_count}
    ...
  EOT
}
```
**Dire** : "Ce résumé facilite la validation visuelle de la configuration"

### 4. Perspective Sécurité (5 minutes)

**Points à aborder spontanément** :

#### a) Sécurité de l'infrastructure

"D'un point de vue SecOps, j'ai pris plusieurs mesures :

1. **Configuration sécurisée** : Ignition permet une configuration immuable dès le boot, réduisant les risques de drift
2. **Isolation** : Séparation claire entre masters (control plane) et workers (workloads)
3. **Audit trail** : Tags et labels permettent le tracking, outputs fournissent un inventaire complet
4. **Validation** : Prévention des configurations non conformes via Terraform validations
5. **Secrets management** : Les fichiers Ignition ne sont jamais commités, backend Terraform chiffré recommandé"

#### b) Stratégie Zero Trust (lié au poste)

"Pour votre stratégie Zero Trust mentionnée dans l'offre :

- **Network segmentation** : Ce code peut être étendu pour créer des VLANs dédiés
- **mTLS** : OpenShift intègre Mutual TLS natif entre composants
- **RBAC** : Les tags permettent un RBAC granulaire au niveau infrastructure
- **Policy-as-Code** : Cette base Terraform peut intégrer Sentinel/OPA pour validation automatique
- **Least privilege** : Chaque noeud ne reçoit que la config Ignition nécessaire à son rôle"

#### c) Conformité et Audit

"Pour la conformité réglementaire :

- **Infrastructure as Code** : Tout est versionné, auditable, reproductible
- **State management** : Terraform state contient l'historique complet
- **Outputs structurés** : Facilite l'export vers des outils de compliance (Prisma, Lacework)
- **Immutabilité** : RHCOS avec Ignition garantit la non-modification post-boot"

## 🎤 Questions/Réponses Attendues

### Questions Techniques

#### Q1 : "Pourquoi avoir utilisé null_resource au lieu d'un vrai provider ?"

**Réponse** :
> "J'ai utilisé null_resource pour rendre le code portable et démonstratif. L'exercice précisait qu'on pouvait utiliser un provider fictif. Cela permet de comprendre la logique sans dépendances.
>
> En production, je le remplacerais par le provider Nutanix. J'ai d'ailleurs inclus des exemples commentés dans main.tf montrant comment utiliser `nutanix_virtual_machine` avec les bonnes propriétés : cluster_uuid, num_vcpus, categories pour les tags, et cloud-init pour l'Ignition.
>
> La transition serait rapide : remplacer les ressources null_resource, ajouter les data sources pour récupérer cluster et subnet, et configurer les credentials Nutanix."

#### Q2 : "Comment gérez-vous les fichiers Ignition sensibles ?"

**Réponse** :
> "Excellente question de sécurité. Les fichiers Ignition contiennent des secrets (certificats, tokens).
>
> Ma stratégie :
> 1. **Jamais dans Git** : .gitignore pour *.ign
> 2. **Backend chiffré** : S3 avec KMS ou Azure Blob avec encryption pour le state Terraform
> 3. **Variables sensibles** : Utiliser Vault provider ou cloud secret managers
> 4. **Rotation** : Les certificats générés par openshift-install sont temporaires (24h pour bootstrap)
> 5. **Permissions** : 600 sur les fichiers locaux
> 6. **CI/CD sécurisé** : Variables sealed dans GitLab CI / GitHub Actions
>
> Pour GTT, je recommanderais HashiCorp Vault ou Azure Key Vault selon votre stack."

#### Q3 : "Comment ce code s'intègre dans une architecture hybride (on-prem + cloud) ?"

**Réponse** :
> "C'est directement lié à votre projet IA hybride. Ce code gère la partie on-premise (Nutanix).
>
> Pour l'hybride :
> 1. **Workspaces Terraform** : Un workspace 'nutanix' pour on-prem, un workspace 'azure' pour cloud
> 2. **Modules partagés** : Variables communes (cluster_name, sizing) dans un module réutilisable
> 3. **Backend partagé** : State centralisé pour visibilité cross-environment
> 4. **Outputs standardisés** : Mes outputs permettent de référencer les clusters dans une config supérieure
>
> Exemple :
> ```hcl
> module "ocp_onprem" {
>   source = "./modules/openshift-upi"
>   platform = "nutanix"
> }
>
> module "ocp_cloud" {
>   source = "./modules/openshift-upi"
>   platform = "azure"
> }
> ```
>
> Pour la souveraineté des données mentionnée dans le poste, on peut router certains workloads sensibles uniquement vers le cluster on-prem via des labels Kubernetes."

#### Q4 : "Quels sont les prérequis réseau pour OpenShift UPI ?"

**Réponse** :
> "OpenShift UPI a des besoins réseau stricts :
>
> **Load Balancer** (non inclus dans cet exercice mais mes outputs facilitent la config) :
> - Port 6443 : API Kubernetes → vers les 3 masters
> - Port 22623 : Machine Config Server → vers masters (durant install uniquement)
> - Ports 80/443 : Ingress HTTP/HTTPS → vers workers
>
> **DNS** (outputs dns_records fournis) :
> - `api.cluster.domain` et `api-int.cluster.domain` → LB masters
> - `*.apps.cluster.domain` → LB workers (wildcard pour les routes)
> - SRV record pour etcd discovery
>
> **Firewall** :
> - Masters ↔ Masters : etcd (2379-2380), VXLAN (4789)
> - Masters ↔ Workers : kubelet (10250)
> - Tous ↔ Internet : pull images (registry.redhat.io)
>
> **Pour GTT** : Je recommanderais des VLANs dédiés (management, control plane, data plane) pour la segmentation réseau conforme à Zero Trust."

#### Q5 : "Comment sécurisez-vous le déploiement CI/CD ?"

**Réponse** :
> "Pour un pipeline CI/CD sécurisé de cette infra :
>
> 1. **GitOps** :
>    - Code Terraform dans Git
>    - Pull Request obligatoire avec `terraform plan`
>    - Reviewers approuvent avant merge
>
> 2. **Pipeline stages** :
>    ```
>    PR → terraform fmt → terraform validate → terraform plan → Review
>    Merge → terraform apply (auto si QA, manuel si PROD)
>    ```
>
> 3. **Sécurité** :
>    - Secrets jamais en clair : Vault, Azure KeyVault
>    - State backend chiffré et avec locking
>    - Service accounts avec least privilege
>    - Audit logs de tous les apply
>
> 4. **Policy as Code** :
>    - Sentinel ou OPA pour valider :
>      - Tags obligatoires (cost center, environment)
>      - Sizing conforme aux standards
>      - Pas de Secure Boot désactivé en prod
>
> 5. **Drift detection** :
>    - Cron job quotidien `terraform plan` → alerte si drift
>    - Intégration avec Datadog/Prometheus pour monitoring
>
> Vous utilisez quelle plateforme CI/CD chez GTT ? GitLab, Azure DevOps ?"

### Questions Comportementales / Leadership

#### Q6 : "Comment prendriez-vous le lead sur la sécurité de ce projet IA ?"

**Réponse** :
> "Mon approche Lead SecOps pour ce projet :
>
> **Phase 1 - Discovery (Semaine 1-2)** :
> - Mener les discussions sécurité avec RSSI, DSI, équipes cloud (mentionné dans l'offre)
> - Cartographier les flux de données sensibles
> - Identifier les exigences réglementaires (RGPD, sectorielles)
>
> **Phase 2 - Strategy (Semaine 2-3)** :
> - Définir l'architecture sécurité hybride (on-prem pour data sensibles, cloud pour compute)
> - Contribuer aux ADRs sur :
>   - Zero Trust : mTLS, microsegmentation, identity-based access
>   - Souveraineté : choix cloud provider (Azure France Central ?)
>   - Conformité : encryption at-rest/in-transit, audit logs
>
> **Phase 3 - Implementation (Semaine 3-6)** :
> - Valider les configs sécurité (ce code Terraform, Kubernetes policies, CI/CD)
> - Implémenter :
>   - Network policies Kubernetes restrictives
>   - Pod Security Standards (restricted profile)
>   - Image scanning (Prisma, Trivy) dans CI/CD
>   - Secret management (Vault + External Secrets Operator)
>
> **Phase 4 - Validation** :
> - Pentesting interne
> - Compliance audit
> - Documentation sécurité
>
> **Tout au long** :
> - Points hebdo avec RSSI
> - Threat modeling sessions
> - Security champions dans chaque équipe"

#### Q7 : "Vous avez 6 semaines part-time. Comment priorisez-vous ?"

**Réponse** :
> "6 semaines part-time, c'est serré. Ma priorisation :
>
> **Must-have (Semaines 1-4)** :
> - Architecture sécurité de base validée
> - ADRs clés documentés et approuvés
> - Configs critiques validées (réseau, Kubernetes RBAC)
> - Pipeline CI/CD sécurisé opérationnel
>
> **Should-have (Semaines 4-5)** :
> - Audit et compliance baseline
> - Monitoring sécurité (Falco, audit logs)
> - Documentation complète
>
> **Nice-to-have (Semaine 6)** :
> - Automation avancée (policy-as-code)
> - Disaster recovery tests
> - Threat modeling approfondi
>
> **Stratégie** :
> - Identifier un Security Champion dans l'équipe pour continuer après ma mission
> - Documenter toutes les décisions (ADRs)
> - Automatiser au maximum pour la maintenabilité
>
> Je proposerais des points 2x/semaine (je suis part-time) pour garder le momentum."

#### Q8 : "Quels outils utiliseriez-vous pour le monitoring sécurité ?"

**Réponse** :
> "Pour une stack sécurité complète sur OpenShift + Nutanix :
>
> **Niveau Infrastructure** :
> - **Prisma Cloud** ou **Lacework** : Compliance, misconfig, CSPM
> - **Nutanix Flow** : Microsegmentation et visibilité réseau
>
> **Niveau Kubernetes** :
> - **Falco** : Runtime security, détection d'anomalies
> - **OPA Gatekeeper** : Policy enforcement
> - **Kyverno** : Alternative OPA, plus simple
>
> **Niveau CI/CD** :
> - **Trivy** ou **Grype** : Image scanning
> - **Snyk** : Vulnerability management
> - **SonarQube** : Code quality + security
>
> **Niveau Monitoring** :
> - **Prometheus + Grafana** : Métriques sécurité
> - **ELK** ou **Loki** : Centralisation logs
> - **Wazuh** : HIDS, compliance (PCI-DSS, RGPD)
>
> **SIEM** :
> - **Splunk** ou **Elastic SIEM** pour corrélation
>
> **Secrets** :
> - **HashiCorp Vault** ou **Azure Key Vault**
> - **External Secrets Operator** pour sync dans Kubernetes
>
> Chez GTT, qu'est-ce qui est déjà en place ?"

## 🚨 Pièges à Éviter

### 1. Ne pas connaître les bases OpenShift
- ❌ "Je ne connais pas bien la différence entre master et worker"
- ✅ "Les masters hébergent le control plane (API, etcd, scheduler), les workers les workloads"

### 2. Négliger l'aspect sécurité
- ❌ Présenter uniquement le code Terraform sans parler sécurité
- ✅ Toujours ramener à la sécurité (vous postulez Lead **SecOps**)

### 3. Être trop technique sans contexte business
- ❌ "J'ai utilisé un for loop avec count.index"
- ✅ "J'ai automatisé la création des masters pour garantir la scalabilité et réduire les erreurs manuelles"

### 4. Ne pas poser de questions
- ❌ Attendre passivement les questions
- ✅ "Quelle est votre stack actuelle ?" "Avez-vous déjà du Terraform en prod ?"

### 5. Prétendre tout savoir
- ❌ "Oui je maîtrise parfaitement Nutanix" (si c'est faux)
- ✅ "Je n'ai pas encore utilisé Nutanix en production, mais j'ai étudié leur provider Terraform et les concepts sont similaires à vSphere que je connais bien"

## 💡 Questions à Poser à l'Employeur

**Questions à poser pour montrer votre intérêt** :

### Questions Techniques
1. "Quelle est votre stack de sécurité actuelle ? Avez-vous déjà des outils CSPM ou SIEM en place ?"
2. "Votre infrastructure Nutanix est-elle déjà configurée avec des network segments pour la microsegmentation ?"
3. "Pour le projet IA, avez-vous des contraintes de souveraineté des données spécifiques ?"

### Questions Projet
4. "Quelles sont les plus grandes préoccupations sécurité pour ce projet d'infrastructure IA ?"
5. "Qui seraient mes principaux interlocuteurs ? RSSI, architecte cloud, équipes dev ?"
6. "Y a-t-il déjà une baseline de sécurité définie ou faut-il la créer from scratch ?"

### Questions Process
7. "Quelle est la méthodologie projet utilisée ? Agile, Waterfall ?"
8. "Y a-t-il une possibilité d'extension après les 6 semaines si le projet nécessite plus de temps ?"

## 📊 Checklist de Préparation

### Matériel à préparer
- [ ] Code Terraform imprimé ou sur laptop
- [ ] Diagramme d'architecture (voir ARCHITECTURE.md)
- [ ] Notes de présentation
- [ ] Liste de questions à poser

### Connaissances à réviser
- [ ] OpenShift UPI vs IPI
- [ ] Architecture etcd et quorum
- [ ] Fichiers Ignition et RHCOS
- [ ] Bases Nutanix (AHV, Prism, Flow)
- [ ] Zero Trust principles
- [ ] Terraform best practices

### Tests à faire
- [ ] `terraform init` fonctionne
- [ ] `terraform validate` passe
- [ ] `terraform plan` s'exécute sans erreur
- [ ] Les outputs s'affichent correctement

### Soft Skills
- [ ] Préparer une introduction de 30 secondes
- [ ] S'entraîner à expliquer le code à voix haute
- [ ] Anticiper 5 questions difficiles
- [ ] Préparer des exemples de situations passées (STAR method)

## 🎯 Messages Clés à Faire Passer

### 1. Expertise Technique
"J'ai une solide compréhension de l'architecture OpenShift et des bonnes pratiques Terraform"

### 2. Vision Sécurité
"Je ne fais pas que du code, je pense sécurité à chaque étape : Ignition, validations, tags, secrets management"

### 3. Leadership
"Je sais prendre le lead sur la stratégie sécurité et collaborer avec RSSI, DSI, et équipes techniques"

### 4. Adaptabilité
"Mon code est portable et peut s'adapter à Nutanix, vSphere, ou tout autre platform"

### 5. Pragmatisme
"Je priorise intelligemment pour livrer de la valeur dans un contexte contraint (6 semaines)"

## ⏰ Timing de la Présentation

**Total recommandé : 30-40 minutes**

| Section | Durée | Contenu |
|---------|-------|---------|
| Introduction | 2-3 min | Vous + approche générale |
| Architecture | 5 min | Diagramme + explication composants |
| Code - variables.tf | 3-4 min | Variables clés + validations |
| Code - main.tf | 5-6 min | Ressources + locals + exemples |
| Code - outputs.tf | 3-4 min | Outputs + intégrations |
| Perspective Sécurité | 5 min | SecOps mindset |
| Questions/Réponses | 10-15 min | Interaction |
| Vos questions | 3-5 min | Questions à l'employeur |

## 🎤 Phrases d'Accroche

**Début** :
> "Ce code Terraform représente une base solide et sécurisée pour déployer OpenShift en mode UPI. Il intègre les best practices Red Hat et les principes SecOps dès le design."

**Transition vers sécurité** :
> "Au-delà du déploiement, j'ai pensé ce code avec une approche sécurité by design..."

**Conclusion** :
> "Pour résumer, ce code offre une base flexible, sécurisée et auditable pour votre projet d'infrastructure IA. Je suis prêt à l'adapter aux spécificités GTT et à contribuer aux ADRs sécurité dès le premier jour."

---

**Vous avez toutes les cartes en main. Bonne chance ! 🚀**
