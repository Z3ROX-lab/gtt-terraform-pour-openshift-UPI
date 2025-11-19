# Guide de Démonstration - Terraform OpenShift UPI

Ce guide explique comment **tester et démontrer** le code Terraform lors de l'entretien, même sans infrastructure réelle.

---

## 🎯 Objectif de la Démo

Montrer que :
1. ✅ Le code Terraform est **syntaxiquement correct**
2. ✅ Les variables sont **bien validées**
3. ✅ La logique de calcul (IPs, noms) **fonctionne**
4. ✅ Les outputs **s'affichent correctement**
5. ✅ Le code est **prêt à être utilisé** en production

---

## 📋 Prérequis pour la Démo

### Installation Terraform

```bash
# Vérifier si Terraform est installé
terraform version

# Si pas installé (macOS)
brew install terraform

# Si pas installé (Linux)
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Si pas installé (Windows)
choco install terraform
```

### Fichiers Ignition (factices pour la démo)

```bash
# Créer des fichiers Ignition vides pour la démo
touch bootstrap.ign master.ign worker.ign

# OU créer avec du contenu minimal
echo '{"ignition":{"version":"3.2.0"}}' > bootstrap.ign
echo '{"ignition":{"version":"3.2.0"}}' > master.ign
echo '{"ignition":{"version":"3.2.0"}}' > worker.ign
```

---

## 🚀 Étape 1 : Validation Syntaxique

**Commande** : Vérifier que le code Terraform est valide

```bash
# Se placer dans le répertoire
cd gtt-terraform-pour-openshift-UPI

# Initialiser Terraform (télécharge le provider null)
terraform init

# Sortie attendue :
# Terraform has been successfully initialized!
```

**Points à montrer** :
- ✅ `terraform init` réussit → providers correctement définis
- ✅ `.terraform/` créé → dépendances téléchargées

---

## 🔍 Étape 2 : Validation du Code

**Commande** : Vérifier la syntaxe HCL

```bash
# Valider la syntaxe
terraform validate

# Sortie attendue :
# Success! The configuration is valid.
```

**Points à montrer** :
- ✅ Pas d'erreurs de syntaxe
- ✅ Variables bien définies
- ✅ Ressources correctement référencées

---

## 📊 Étape 3 : Formatage du Code

**Commande** : Vérifier le formatage (best practice)

```bash
# Vérifier le formatage (sans modifier)
terraform fmt -check

# Formater automatiquement si nécessaire
terraform fmt -recursive
```

**Points à montrer** :
- ✅ Code bien formaté
- ✅ Respect des conventions Terraform

---

## 🧮 Étape 4 : Plan Terraform (Sans Création)

**Commande** : Simuler le déploiement

```bash
# Créer un fichier terraform.tfvars pour la démo
cat > terraform.tfvars <<EOF
cluster_name = "ocp-demo"
base_domain  = "demo.local"

masters_count = 3
workers_count = 2

bootstrap_ignition = "./bootstrap.ign"
master_ignition    = "./master.ign"
worker_ignition    = "./worker.ign"

platform = "generic"
EOF

# Exécuter terraform plan
terraform plan
```

**Sortie attendue** :

```
Terraform will perform the following actions:

  # null_resource.bootstrap_node will be created
  + resource "null_resource" "bootstrap_node" {
      + id       = (known after apply)
      + triggers = {
          + "cpu"           = "4"
          + "ignition_file" = "./bootstrap.ign"
          + "ip_address"    = "192.168.50.10"
          + "memory"        = "16384"
          + "name"          = "ocp-demo-bootstrap"
          + "role"          = "bootstrap"
        }
    }

  # null_resource.master_nodes[0] will be created
  # null_resource.master_nodes[1] will be created
  # null_resource.master_nodes[2] will be created
  # null_resource.worker_nodes[0] will be created
  # null_resource.worker_nodes[1] will be created

Plan: 6 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + bootstrap_ip          = "192.168.50.10"
  + bootstrap_hostname    = "ocp-demo-bootstrap"
  + master_ips            = [
      + "192.168.50.11",
      + "192.168.50.12",
      + "192.168.50.13",
    ]
  + master_hostnames      = [
      + "ocp-demo-master-0",
      + "ocp-demo-master-1",
      + "ocp-demo-master-2",
    ]
  + worker_ips            = [
      + "192.168.50.14",
      + "192.168.50.15",
    ]
  + deployment_summary    = <<-EOT
        Cluster: ocp-demo.demo.local
        Masters (3):
          - ocp-demo-master-0 (192.168.50.11)
          - ocp-demo-master-1 (192.168.50.12)
          - ocp-demo-master-2 (192.168.50.13)
        Workers (2):
          - ocp-demo-worker-0 (192.168.50.14)
          - ocp-demo-worker-1 (192.168.50.15)
    EOT
```

**Points à montrer** :
- ✅ **6 ressources** seront créées (1 bootstrap + 3 masters + 2 workers)
- ✅ **IPs calculées automatiquement** (.10, .11, .12, .13, .14, .15)
- ✅ **Noms générés** (ocp-demo-master-0, etc.)
- ✅ **Outputs riches** (IPs, noms, résumé)

---

## 🎭 Étape 5 : Appliquer (Démo Factice)

**⚠️ Option A : Apply pour vraiment tester (sans vraies VMs)**

```bash
# Exécuter terraform apply
terraform apply -auto-approve

# Sortie :
# null_resource.bootstrap_node: Creating...
# null_resource.master_nodes[0]: Creating...
# ...
# Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
```

**Ce qui se passe** :
- ✅ Les `null_resource` sont créés (juste des entrées dans le state)
- ✅ Les `provisioner local-exec` s'exécutent (affichent les infos)
- ✅ Aucune vraie VM n'est créée (c'est une simulation)

**⚠️ Option B : Plan uniquement (recommandé pour l'entretien)**

Si vous ne voulez pas modifier le state, restez à `terraform plan`

---

## 📤 Étape 6 : Afficher les Outputs

**Commande** : Voir les outputs générés

```bash
# Si vous avez fait terraform apply
terraform output

# Sortie :
bootstrap_hostname = "ocp-demo-bootstrap"
bootstrap_ip = "192.168.50.10"
master_ips = [
  "192.168.50.11",
  "192.168.50.12",
  "192.168.50.13",
]
...

# Afficher un output spécifique
terraform output master_ips

# Afficher en format JSON
terraform output -json > outputs.json
```

**Points à montrer** :
- ✅ Outputs structurés et lisibles
- ✅ Format JSON pour intégration (Ansible, scripts)
- ✅ Toutes les infos nécessaires (IPs, DNS, LB)

---

## 🧪 Étape 7 : Tester les Validations

**Objectif** : Montrer que les validations empêchent les erreurs

### Test 1 : Nombre pair de masters (doit échouer)

```bash
# Modifier terraform.tfvars
echo 'masters_count = 4' >> terraform.tfvars

# Tester
terraform plan

# Sortie attendue :
# Error: Invalid value for variable
# Le nombre de masters doit être impair et au minimum 3 (pour le quorum etcd).
```

✅ **Validation fonctionne** : Empêche un nombre pair de masters

### Test 2 : Cluster name trop long (doit échouer)

```bash
# Nom de cluster > 27 caractères
echo 'cluster_name = "ocp-super-long-name-that-exceeds-limit"' >> terraform.tfvars

# Tester
terraform plan

# Sortie attendue :
# Error: Invalid value for variable
# Le nom du cluster doit contenir entre 1 et 27 caractères.
```

✅ **Validation fonctionne** : Respecte les contraintes OpenShift

### Test 3 : Plateforme invalide (doit échouer)

```bash
# Plateforme non supportée (Proxmox n'est pas officiellement supporté)
echo 'platform = "proxmox"' >> terraform.tfvars

# Tester
terraform plan

# Sortie attendue :
# Error: Invalid value for variable
# Plateforme supportée: nutanix, vsphere, rhv, openstack, kvm, baremetal (on-prem) | aws, azure, gcp...
```

✅ **Validation fonctionne** : Seules les plateformes UPI supportées par OpenShift

---

## 🎬 Script de Démo pour l'Entretien

### Scénario recommandé (10 minutes)

```bash
# 1. Introduction (30 sec)
echo "Je vais vous démontrer mon code Terraform pour OpenShift UPI"

# 2. Initialisation (30 sec)
terraform init
# Commentaire : "Terraform télécharge le provider null pour la démo"

# 3. Validation (30 sec)
terraform validate
# Commentaire : "Le code est syntaxiquement correct"

# 4. Plan - Configuration de base (2 min)
cat terraform.tfvars  # Montrer la config
terraform plan
# Commentaire : "Terraform va créer 6 ressources : 1 bootstrap, 3 masters, 2 workers"
# Pointer : "Regardez les IPs auto-calculées, les noms générés, les outputs"

# 5. Tester validation masters impair (2 min)
echo 'masters_count = 4' >> terraform.tfvars
terraform plan
# Commentaire : "Voyez, la validation empêche un nombre pair de masters pour le quorum etcd"

# 6. Revenir à config valide (1 min)
git checkout terraform.tfvars  # Ou supprimer la ligne
terraform plan

# 7. Montrer la flexibilité multi-cloud (2 min)
echo 'platform = "azure"' >> terraform.tfvars
terraform plan
# Commentaire : "Même code, je change juste la plateforme. Support complet on-prem et cloud"

# 8. Afficher outputs détaillés (1 min)
terraform apply -auto-approve  # Si vous voulez aller jusqu'au bout
terraform output deployment_summary
# Commentaire : "Tous les outputs nécessaires : IPs, DNS, config LB, inventaire Ansible"

# 9. Nettoyage (1 min)
terraform destroy -auto-approve
# Commentaire : "Facile à nettoyer, Infrastructure as Code réversible"
```

---

## 🎤 Points à Mentionner Pendant la Démo

### 1. Pendant `terraform init`
> "J'utilise le provider null pour la démo, mais le code est conçu pour être portable. En production, on remplacerait par le provider Nutanix, AWS, ou Azure. J'ai d'ailleurs des exemples commentés dans main.tf."

### 2. Pendant `terraform plan`
> "Terraform calcule automatiquement les IPs séquentielles et génère les noms de manière cohérente. Cela garantit la reproductibilité : même infrastructure à chaque déploiement."

### 3. En montrant les outputs
> "Ces outputs sont conçus pour faciliter l'intégration : configuration DNS, load balancer, inventaire Ansible. C'est du DevOps end-to-end."

### 4. En testant les validations
> "Les validations sont cruciales en SecOps : elles préviennent les erreurs de configuration avant le déploiement. Par exemple, un nombre pair de masters casserait le quorum etcd."

### 5. En montrant le multi-cloud
> "Pour votre architecture IA hybride chez GTT, ce code supporte Nutanix on-premise pour les données sensibles ET Azure pour le compute élastique. Même codebase, juste la variable platform change."

---

## 🚨 Ce qui NE Fonctionnera PAS (et c'est normal)

### ❌ Pas de vraies VMs créées
- Le provider `null` ne crée pas de VMs réelles
- C'est juste pour la démo de la logique Terraform

### ❌ Pas de connexion réseau
- Les IPs sont calculées mais pas assignées
- Pas de DHCP/DNS réel

### ❌ Pas d'OpenShift déployé
- Les fichiers Ignition ne sont pas utilisés
- C'est juste la phase infrastructure

**Comment expliquer en entretien** :
> "J'utilise le provider null pour démontrer la logique Terraform sans avoir besoin d'accès à une infrastructure réelle. En production, on remplacerait ces 20 lignes par les ressources du provider Nutanix/AWS/Azure, et tout fonctionnerait tel quel."

---

## 📸 Captures d'Écran Recommandées

Pour l'entretien, préparez des screenshots de :

1. ✅ `terraform init` → Success
2. ✅ `terraform validate` → Configuration is valid
3. ✅ `terraform plan` → Plan: 6 to add
4. ✅ Outputs affichés (master_ips, deployment_summary)
5. ✅ Erreur de validation (masters_count = 4)

Avoir ces screenshots en backup au cas où Terraform ne serait pas installé sur la machine de l'entretien.

---

## 🎯 Variantes de Démo selon le Temps

### Démo Courte (5 min)
```bash
terraform init
terraform validate
terraform plan
# Pointer les points clés : 6 ressources, IPs auto, outputs
```

### Démo Moyenne (10 min)
```bash
terraform init
terraform validate
terraform plan
# Tester une validation (masters impair)
terraform output (si apply fait)
```

### Démo Complète (15 min)
```bash
# Tout le scénario ci-dessus
# + Montrer le code dans variables.tf, main.tf
# + Expliquer l'architecture hybride GTT
```

---

## 💡 Questions Attendues et Réponses

### Q : "Ce code crée vraiment des VMs ?"
**R** : "Avec le provider null, non. C'est une démo de la logique. Mais le code est production-ready : en remplaçant null_resource par nutanix_virtual_machine, azurerm_linux_virtual_machine, ou aws_instance, tout fonctionne tel quel. J'ai des exemples commentés pour chaque provider dans main.tf."

### Q : "Comment ça marche en vrai avec Nutanix ?"
**R** : "On configure le provider Nutanix avec les credentials, on récupère les data sources (cluster_uuid, subnet_uuid, image RHCOS), et on remplace les null_resource par nutanix_virtual_machine. J'ai un exemple complet commenté lignes 204-246 de main.tf."

### Q : "Et les fichiers Ignition ?"
**R** : "Ils sont générés par openshift-install create ignition-configs. Chaque fichier contient la configuration CoreOS pour un type de noeud. Terraform les passe via user_data (AWS), custom_data (Azure), ou guest_customization_cloud_init_user_data (Nutanix)."

### Q : "Pourquoi null_resource ?"
**R** : "Pour rendre la démo portable et démontrer la logique sans dépendances. C'est une best practice Terraform pour tester du code sans infrastructure réelle. Cela montre aussi la flexibilité du code : facile de basculer entre providers."

---

## ✅ Checklist Avant l'Entretien

- [ ] Terraform installé et testé
- [ ] `terraform init` fonctionne
- [ ] `terraform validate` passe
- [ ] `terraform plan` s'exécute sans erreur
- [ ] Fichiers Ignition factices créés (bootstrap.ign, master.ign, worker.ign)
- [ ] terraform.tfvars configuré avec des valeurs de démo
- [ ] Screenshots de backup préparés
- [ ] Script de démo répété 2-3 fois
- [ ] Questions/réponses anticipées préparées

---

**Avec cette démo, vous montrez une maîtrise complète de Terraform ET d'OpenShift UPI ! 🚀**
