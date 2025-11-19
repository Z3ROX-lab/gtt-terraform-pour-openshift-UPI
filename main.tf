# ============================================================================
# Configuration Terraform et Provider
# ============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    # Utilisation d'un provider générique pour démonstration
    # En production, remplacer par le provider spécifique:
    # - nutanix/nutanix pour Nutanix
    # - hashicorp/vsphere pour VMware vSphere
    # - dmacvicar/libvirt pour KVM/libvirt
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# ============================================================================
# Locals - Calculs et structures de données
# ============================================================================

locals {
  # FQDN du cluster
  cluster_fqdn = "${var.cluster_name}.${var.base_domain}"

  # Calcul des adresses IP (simulation pour la démonstration)
  # En production, ceci serait géré par le provider de virtualisation
  ip_octets = split(".", var.ip_range_start)
  ip_base   = format("%s.%s.%s", local.ip_octets[0], local.ip_octets[1], local.ip_octets[2])
  ip_start  = parseint(local.ip_octets[3], 10)

  # Attribution des IPs
  bootstrap_ip = format("%s.%d", local.ip_base, local.ip_start)
  master_ips   = [for i in range(var.masters_count) : format("%s.%d", local.ip_base, local.ip_start + 1 + i)]
  worker_ips   = [for i in range(var.workers_count) : format("%s.%d", local.ip_base, local.ip_start + 1 + var.masters_count + i)]

  # Tags communs pour toutes les ressources
  all_tags = merge(
    var.common_tags,
    {
      cluster_name = var.cluster_name
      base_domain  = var.base_domain
      environment  = "production"
    }
  )

  # Métadonnées pour chaque type de noeud
  bootstrap_metadata = {
    hostname = "${var.cluster_name}-bootstrap"
    role     = "bootstrap"
    fqdn     = "${var.cluster_name}-bootstrap.${var.base_domain}"
  }

  master_metadata = [
    for i in range(var.masters_count) : {
      hostname = "${var.cluster_name}-master-${i}"
      role     = "master"
      fqdn     = "${var.cluster_name}-master-${i}.${var.base_domain}"
      index    = i
    }
  ]

  worker_metadata = [
    for i in range(var.workers_count) : {
      hostname = "${var.cluster_name}-worker-${i}"
      role     = "worker"
      fqdn     = "${var.cluster_name}-worker-${i}.${var.base_domain}"
      index    = i
    }
  ]
}

# ============================================================================
# Noeud Bootstrap
# ============================================================================

# Le noeud bootstrap est temporaire et sert à initialiser le cluster
# Il sera supprimé une fois le cluster opérationnel
resource "null_resource" "bootstrap_node" {
  # En production, remplacer par la ressource du provider approprié
  # Exemple Nutanix: nutanix_virtual_machine
  # Exemple vSphere: vsphere_virtual_machine
  # Exemple KVM: libvirt_domain

  triggers = {
    # Recréer si la configuration change
    name           = local.bootstrap_metadata.hostname
    cpu            = var.bootstrap_cpu
    memory         = var.bootstrap_memory
    disk_size      = var.bootstrap_disk_size
    ignition_file  = var.bootstrap_ignition
    ip_address     = local.bootstrap_ip
    role           = local.bootstrap_metadata.role
  }

  # Simulation de la création de la VM
  provisioner "local-exec" {
    command = <<-EOT
      echo "Création du noeud bootstrap:"
      echo "  - Nom: ${local.bootstrap_metadata.hostname}"
      echo "  - FQDN: ${local.bootstrap_metadata.fqdn}"
      echo "  - Rôle: ${local.bootstrap_metadata.role}"
      echo "  - CPU: ${var.bootstrap_cpu} vCPUs"
      echo "  - RAM: ${var.bootstrap_memory} MB"
      echo "  - Disque: ${var.bootstrap_disk_size} GB"
      echo "  - IP: ${local.bootstrap_ip}"
      echo "  - Ignition: ${var.bootstrap_ignition}"
      echo "  - Plateforme: ${var.platform}"
    EOT
  }
}

# ============================================================================
# Noeuds Master (Control Plane)
# ============================================================================

# Les noeuds master hébergent le control plane OpenShift:
# - API Server
# - etcd (nécessite un nombre impair pour le quorum)
# - Controller Manager
# - Scheduler
resource "null_resource" "master_nodes" {
  count = var.masters_count

  triggers = {
    # Recréer si la configuration change
    name           = local.master_metadata[count.index].hostname
    cpu            = var.master_cpu
    memory         = var.master_memory
    disk_size      = var.master_disk_size
    ignition_file  = var.master_ignition
    ip_address     = local.master_ips[count.index]
    role           = local.master_metadata[count.index].role
    index          = count.index
  }

  # Simulation de la création de la VM
  provisioner "local-exec" {
    command = <<-EOT
      echo "Création du noeud master ${count.index}:"
      echo "  - Nom: ${local.master_metadata[count.index].hostname}"
      echo "  - FQDN: ${local.master_metadata[count.index].fqdn}"
      echo "  - Rôle: ${local.master_metadata[count.index].role}"
      echo "  - CPU: ${var.master_cpu} vCPUs"
      echo "  - RAM: ${var.master_memory} MB"
      echo "  - Disque: ${var.master_disk_size} GB"
      echo "  - IP: ${local.master_ips[count.index]}"
      echo "  - Ignition: ${var.master_ignition}"
      echo "  - Plateforme: ${var.platform}"
    EOT
  }

  depends_on = [null_resource.bootstrap_node]
}

# ============================================================================
# Noeuds Worker (Compute)
# ============================================================================

# Les noeuds worker hébergent les workloads applicatifs
# Le nombre est paramétrable selon les besoins
resource "null_resource" "worker_nodes" {
  count = var.workers_count

  triggers = {
    # Recréer si la configuration change
    name           = local.worker_metadata[count.index].hostname
    cpu            = var.worker_cpu
    memory         = var.worker_memory
    disk_size      = var.worker_disk_size
    ignition_file  = var.worker_ignition
    ip_address     = local.worker_ips[count.index]
    role           = local.worker_metadata[count.index].role
    index          = count.index
  }

  # Simulation de la création de la VM
  provisioner "local-exec" {
    command = <<-EOT
      echo "Création du noeud worker ${count.index}:"
      echo "  - Nom: ${local.worker_metadata[count.index].hostname}"
      echo "  - FQDN: ${local.worker_metadata[count.index].fqdn}"
      echo "  - Rôle: ${local.worker_metadata[count.index].role}"
      echo "  - CPU: ${var.worker_cpu} vCPUs"
      echo "  - RAM: ${var.worker_memory} MB"
      echo "  - Disque: ${var.worker_disk_size} GB"
      echo "  - IP: ${local.worker_ips[count.index]}"
      echo "  - Ignition: ${var.worker_ignition}"
      echo "  - Plateforme: ${var.platform}"
    EOT
  }

  depends_on = [null_resource.bootstrap_node]
}

# ============================================================================
# Exemple de structure pour un provider réel (commenté)
# ============================================================================

/*
# Exemple pour Nutanix Provider
resource "nutanix_virtual_machine" "bootstrap" {
  name                 = local.bootstrap_metadata.hostname
  cluster_uuid         = data.nutanix_cluster.cluster.id
  num_vcpus_per_socket = var.bootstrap_cpu
  num_sockets          = 1
  memory_size_mib      = var.bootstrap_memory

  disk_list {
    data_source_reference = {
      kind = "image"
      uuid = data.nutanix_image.rhcos.id
    }
    device_properties {
      disk_address = {
        device_index = 0
        adapter_type = "SCSI"
      }
      device_type = "DISK"
    }
    disk_size_mib = var.bootstrap_disk_size * 1024
  }

  nic_list {
    subnet_uuid = data.nutanix_subnet.subnet.id
    ip_endpoint_list {
      ip   = local.bootstrap_ip
      type = "ASSIGNED"
    }
  }

  guest_customization_cloud_init_user_data = base64encode(file(var.bootstrap_ignition))

  categories {
    name  = "openshift-role"
    value = "bootstrap"
  }

  categories {
    name  = "cluster-name"
    value = var.cluster_name
  }
}

# Exemple pour VMware vSphere Provider
resource "vsphere_virtual_machine" "master" {
  count            = var.masters_count
  name             = local.master_metadata[count.index].hostname
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = var.cluster_name

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

  tags = [
    vsphere_tag.role_master.id,
    vsphere_tag.cluster.id,
  ]
}

# Exemple pour AWS Provider (Cloud Public)
resource "aws_instance" "master" {
  count         = var.masters_count
  ami           = data.aws_ami.rhcos.id
  instance_type = "m5.2xlarge"  # 8 vCPU, 32 GB RAM

  subnet_id              = data.aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.master.id]
  iam_instance_profile   = aws_iam_instance_profile.master.name

  root_block_device {
    volume_type = "gp3"
    volume_size = var.master_disk_size
    encrypted   = true
  }

  user_data = file(var.master_ignition)

  tags = merge(
    local.all_tags,
    {
      Name = local.master_metadata[count.index].hostname
      Role = "master"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

# Exemple pour Azure Provider (Cloud Public)
resource "azurerm_linux_virtual_machine" "master" {
  count               = var.masters_count
  name                = local.master_metadata[count.index].hostname
  resource_group_name = azurerm_resource_group.openshift.name
  location            = azurerm_resource_group.openshift.location
  size                = "Standard_D8s_v3"  # 8 vCPU, 32 GB RAM

  admin_username                  = "core"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "core"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  network_interface_ids = [
    azurerm_network_interface.master[count.index].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.master_disk_size
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "rhcos"
    sku       = "rhcos"
    version   = "latest"
  }

  custom_data = base64encode(file(var.master_ignition))

  tags = merge(
    local.all_tags,
    {
      Role = "master"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

# Exemple pour GCP Provider (Cloud Public)
resource "google_compute_instance" "master" {
  count        = var.masters_count
  name         = local.master_metadata[count.index].hostname
  machine_type = "n2-standard-8"  # 8 vCPU, 32 GB RAM
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = data.google_compute_image.rhcos.self_link
      size  = var.master_disk_size
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.openshift.id
    subnetwork = google_compute_subnetwork.master.id
  }

  metadata = {
    user-data = file(var.master_ignition)
  }

  labels = merge(
    local.all_tags,
    {
      role = "master"
      "kubernetes-io-cluster-${var.cluster_name}" = "owned"
    }
  )

  service_account {
    email  = google_service_account.master.email
    scopes = ["cloud-platform"]
  }
}
*/
