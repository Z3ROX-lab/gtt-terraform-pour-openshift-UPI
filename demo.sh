#!/bin/bash

# Script de démonstration Terraform OpenShift UPI
# Usage: ./demo.sh

set -e

echo "======================================"
echo "DÉMO TERRAFORM - OPENSHIFT UPI"
echo "======================================"
echo ""

# Couleurs pour l'output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les étapes
step() {
    echo ""
    echo -e "${BLUE}▶ $1${NC}"
    echo ""
}

# Fonction pour afficher les succès
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Fonction pour afficher les warnings
warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Vérifier que Terraform est installé
if ! command -v terraform &> /dev/null; then
    warn "Terraform n'est pas installé !"
    echo ""
    echo "Installez Terraform :"
    echo "  macOS:   brew install terraform"
    echo "  Linux:   https://developer.hashicorp.com/terraform/downloads"
    echo "  Windows: choco install terraform"
    exit 1
fi

success "Terraform $(terraform version -json | grep -o '"version":"[^"]*' | cut -d'"' -f4) détecté"

# Créer les fichiers Ignition factices si nécessaire
step "Étape 1: Préparation des fichiers Ignition (factices pour la démo)"
if [ ! -f bootstrap.ign ]; then
    echo '{"ignition":{"version":"3.2.0"}}' > bootstrap.ign
    success "bootstrap.ign créé"
fi
if [ ! -f master.ign ]; then
    echo '{"ignition":{"version":"3.2.0"}}' > master.ign
    success "master.ign créé"
fi
if [ ! -f worker.ign ]; then
    echo '{"ignition":{"version":"3.2.0"}}' > worker.ign
    success "worker.ign créé"
fi

# Initialiser Terraform
step "Étape 2: Initialisation Terraform"
terraform init
success "Terraform initialisé avec succès"

# Valider le code
step "Étape 3: Validation de la syntaxe"
terraform validate
success "Code Terraform valide"

# Formatter le code
step "Étape 4: Vérification du formatage"
if terraform fmt -check -recursive; then
    success "Code bien formaté"
else
    warn "Code pourrait être formaté (pas critique)"
fi

# Plan Terraform
step "Étape 5: Planification du déploiement (terraform plan)"
echo "Configuration utilisée:"
echo "  - Cluster: ocp-demo.demo.local"
echo "  - Masters: 3"
echo "  - Workers: 2"
echo "  - Platform: generic"
echo ""
terraform plan

success "Plan généré avec succès"

# Demander si on veut apply
echo ""
echo -e "${YELLOW}Voulez-vous exécuter 'terraform apply' pour créer les ressources (simulation) ? [y/N]${NC}"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    step "Étape 6: Application du plan (terraform apply)"
    terraform apply -auto-approve
    success "Ressources créées (simulation avec null_resource)"

    # Afficher les outputs
    step "Étape 7: Affichage des outputs"
    terraform output

    echo ""
    echo -e "${BLUE}▶ Output spécifique - Résumé du déploiement :${NC}"
    echo ""
    terraform output -raw deployment_summary

    # Proposer de nettoyer
    echo ""
    echo -e "${YELLOW}Voulez-vous nettoyer (terraform destroy) ? [y/N]${NC}"
    read -r cleanup
    if [[ "$cleanup" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        step "Étape 8: Nettoyage (terraform destroy)"
        terraform destroy -auto-approve
        success "Ressources détruites"
    fi
else
    echo ""
    success "Démo terminée (plan uniquement, pas d'apply)"
fi

echo ""
echo "======================================"
echo "✓ DÉMO TERMINÉE AVEC SUCCÈS"
echo "======================================"
echo ""
echo "Points clés démontrés :"
echo "  ✓ Code Terraform syntaxiquement valide"
echo "  ✓ 6 ressources planifiées (1 bootstrap + 3 masters + 2 workers)"
echo "  ✓ IPs calculées automatiquement (.10 à .15)"
echo "  ✓ Outputs riches (IPs, noms, DNS, LB config)"
echo "  ✓ Architecture OpenShift UPI complète"
echo ""
echo "Pour adapter à Nutanix/AWS/Azure, voir main.tf lignes 204-393"
echo ""
