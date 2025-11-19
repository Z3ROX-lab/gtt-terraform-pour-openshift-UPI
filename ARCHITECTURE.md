# Architecture OpenShift UPI - Diagrammes

## 🏗️ Vue d'ensemble de l'infrastructure

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CLUSTER OPENSHIFT UPI                              │
│                     ocp-cluster.example.com                                 │
└─────────────────────────────────────────────────────────────────────────────┘

                              ┌───────────────┐
                              │  LOAD BALANCER│
                              │               │
                              │ API: 6443     │
                              │ MCS: 22623    │
                              │ HTTP: 80/443  │
                              └───────┬───────┘
                                      │
            ┌─────────────────────────┼─────────────────────────┐
            │                         │                         │
            │                         │                         │
    ┌───────▼───────┐         ┌───────▼───────┐       ┌────────▼────────┐
    │   BOOTSTRAP   │         │    MASTERS    │       │     WORKERS     │
    │  (Temporaire) │         │ (Control Plane│       │    (Compute)    │
    │               │         │               │       │                 │
    │ • 4 vCPU      │         │ • 3 noeuds    │       │ • 2+ noeuds     │
    │ • 16 GB RAM   │         │ • 8 vCPU each │       │ • 8 vCPU each   │
    │ • 120 GB      │         │ • 32 GB each  │       │ • 32 GB each    │
    │               │         │ • 200 GB each │       │ • 200 GB each   │
    │ Role:         │         │               │       │                 │
    │ • Init cluster│         │ Hébergent:    │       │ Hébergent:      │
    │ • MCS initial │         │ • API Server  │       │ • Pods apps     │
    │               │         │ • etcd        │       │ • Ingress       │
    │ Supprimé après│         │ • Scheduler   │       │ • Monitoring    │
    │ install ✓     │         │ • Controllers │       │ • Logging       │
    └───────────────┘         └───────────────┘       └─────────────────┘
         │                            │                        │
         │                            │                        │
         └────────────────────────────┼────────────────────────┘
                                      │
                              ┌───────▼───────┐
                              │   NETWORK     │
                              │ 192.168.50.0  │
                              │     /24       │
                              └───────────────┘
```

## 🔄 Flux de Déploiement Détaillé

```
┌────────────────────────────────────────────────────────────────────────────┐
│  PHASE 1: PROVISIONNEMENT INFRASTRUCTURE (Terraform)                       │
└────────────────────────────────────────────────────────────────────────────┘

    1. Terraform Apply
           │
           ├─► Créer Bootstrap VM
           │   • IP: 192.168.50.10
           │   • Ignition: bootstrap.ign
           │   • Tag: role=bootstrap
           │
           ├─► Créer Master VMs (x3)
           │   • IP: .11, .12, .13
           │   • Ignition: master.ign
           │   • Tag: role=master
           │
           └─► Créer Worker VMs (x2+)
               • IP: .14, .15, ...
               • Ignition: worker.ign
               • Tag: role=worker

┌────────────────────────────────────────────────────────────────────────────┐
│  PHASE 2: INITIALISATION BOOTSTRAP (0-10 min)                             │
└────────────────────────────────────────────────────────────────────────────┘

    Bootstrap Node
         │
         ├─► Boot avec bootstrap.ign
         │
         ├─► Démarrer Machine Config Server (MCS)
         │   • Port 22623
         │   • Sert master.ign et worker.ign
         │
         └─► Démarrer containers temporaires:
             • etcd (temporaire)
             • kube-apiserver (temporaire)
             • kube-controller-manager
             • kube-scheduler

┌────────────────────────────────────────────────────────────────────────────┐
│  PHASE 3: DÉMARRAGE MASTERS (10-30 min)                                   │
└────────────────────────────────────────────────────────────────────────────┘

    Master-0, Master-1, Master-2
         │
         ├─► Boot avec master.ign depuis MCS
         │
         ├─► Former le cluster etcd
         │   • Master-0 → etcd member 0
         │   • Master-1 → etcd member 1  │ Quorum
         │   • Master-2 → etcd member 2  │
         │
         ├─► Démarrer Control Plane permanent:
         │   • kube-apiserver (sur chaque master)
         │   • kube-controller-manager
         │   • kube-scheduler
         │
         └─► Approuver CSR (Certificate Signing Requests)

┌────────────────────────────────────────────────────────────────────────────┐
│  PHASE 4: TRANSITION CONTROL PLANE (30-45 min)                            │
└────────────────────────────────────────────────────────────────────────────┘

         Bootstrap                    Masters
            │                            │
            ├──────► Migration ─────────►│
            │        Control Plane       │
            │                            │
            │                            ├─► etcd (permanent)
            │                            ├─► API Server (permanent)
            │                            └─► Controllers (permanent)
            │
            └─► Bootstrap peut être supprimé ✓
                (terraform destroy -target=...)

┌────────────────────────────────────────────────────────────────────────────┐
│  PHASE 5: DÉMARRAGE WORKERS (45-60 min)                                   │
└────────────────────────────────────────────────────────────────────────────┘

    Worker-0, Worker-1, Worker-2, ...
         │
         ├─► Boot avec worker.ign depuis Masters
         │
         ├─► Rejoindre le cluster
         │   • Enregistrement kubelet
         │   • Approbation CSR (automatique)
         │
         ├─► Démarrer pods système:
         │   • DNS (CoreDNS)
         │   • Ingress Controller (Router)
         │   • Monitoring (Prometheus)
         │   • Logging (Fluentd)
         │
         └─► Prêt pour workloads applicatifs ✓

┌────────────────────────────────────────────────────────────────────────────┐
│  PHASE 6: CLUSTER OPÉRATIONNEL (60+ min)                                  │
└────────────────────────────────────────────────────────────────────────────┘

                    ┌──────────────────────┐
                    │  CLUSTER READY ✓     │
                    │                      │
                    │  • API accessible    │
                    │  • Masters: 3/3      │
                    │  • Workers: N/N      │
                    │  • Operators: OK     │
                    └──────────────────────┘
```

## 🌐 Architecture Réseau Détaillée

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              RÉSEAU & DNS                                   │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│  DNS EXTERNE                                                             │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  api.ocp-cluster.example.com         → Load Balancer (Masters)          │
│  api-int.ocp-cluster.example.com     → Load Balancer (Masters)          │
│  *.apps.ocp-cluster.example.com      → Load Balancer (Workers)          │
│                                                                          │
│  etcd-0.ocp-cluster.example.com      → 192.168.50.11 (Master-0)         │
│  etcd-1.ocp-cluster.example.com      → 192.168.50.12 (Master-1)         │
│  etcd-2.ocp-cluster.example.com      → 192.168.50.13 (Master-2)         │
│                                                                          │
│  _etcd-server-ssl._tcp.ocp-cluster.example.com (SRV)                    │
│    → 0 10 2380 etcd-0.ocp-cluster.example.com                           │
│    → 0 10 2380 etcd-1.ocp-cluster.example.com                           │
│    → 0 10 2380 etcd-2.ocp-cluster.example.com                           │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│  LOAD BALANCER                                                           │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Frontend: api.ocp-cluster.example.com:6443                              │
│  Backend:  192.168.50.11:6443  (Master-0) ──┐                           │
│            192.168.50.12:6443  (Master-1) ──┼─► API Kubernetes          │
│            192.168.50.13:6443  (Master-2) ──┘                           │
│                                                                          │
│  Frontend: api.ocp-cluster.example.com:22623                             │
│  Backend:  192.168.50.11:22623 (Master-0) ──┐                           │
│            192.168.50.12:22623 (Master-1) ──┼─► Machine Config Server   │
│            192.168.50.13:22623 (Master-2) ──┘   (install only)          │
│                                                                          │
│  Frontend: *.apps.ocp-cluster.example.com:80                             │
│  Backend:  192.168.50.14:80    (Worker-0) ──┐                           │
│            192.168.50.15:80    (Worker-1) ──┼─► HTTP Ingress            │
│            192.168.50.16:80    (Worker-2) ──┘                           │
│                                                                          │
│  Frontend: *.apps.ocp-cluster.example.com:443                            │
│  Backend:  192.168.50.14:443   (Worker-0) ──┐                           │
│            192.168.50.15:443   (Worker-1) ──┼─► HTTPS Ingress           │
│            192.168.50.16:443   (Worker-2) ──┘                           │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│  ALLOCATION IP (192.168.50.0/24)                                         │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  192.168.50.1        → Gateway                                           │
│  192.168.50.2-9      → Réservé (DNS, LB, etc.)                          │
│  192.168.50.10       → Bootstrap                                         │
│  192.168.50.11       → Master-0                                          │
│  192.168.50.12       → Master-1                                          │
│  192.168.50.13       → Master-2                                          │
│  192.168.50.14       → Worker-0                                          │
│  192.168.50.15       → Worker-1                                          │
│  192.168.50.16       → Worker-2                                          │
│  192.168.50.17-254   → Workers additionnels / DHCP pool                  │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

## 🔒 Architecture Sécurité (Zero Trust)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     ARCHITECTURE SÉCURITÉ ZERO TRUST                        │
└─────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│  COUCHE 1: RÉSEAU                                                          │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐              │
│   │   VLAN 10   │      │   VLAN 20   │      │   VLAN 30   │              │
│   │ Management  │      │ Control     │      │   Data      │              │
│   │             │      │  Plane      │      │   Plane     │              │
│   │ • Bootstrap │      │ • Masters   │      │ • Workers   │              │
│   │ • Bastion   │      │ • etcd      │      │ • Apps      │              │
│   └─────────────┘      └─────────────┘      └─────────────┘              │
│         │                     │                     │                     │
│         └─────────────────────┼─────────────────────┘                     │
│                               │                                           │
│                    ┌──────────▼──────────┐                                │
│                    │  Nutanix Flow      │                                 │
│                    │  Microsegmentation │                                 │
│                    │  • Policy-based    │                                 │
│                    │  • Zero Trust      │                                 │
│                    └────────────────────┘                                 │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│  COUCHE 2: IDENTITÉ & ACCÈS                                                │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│   ┌───────────────────────────────────────────────────────────────┐       │
│   │  OpenShift RBAC + OAuth                                       │       │
│   │                                                                │       │
│   │  • Intégration LDAP/AD                                         │       │
│   │  • Service Accounts avec least privilege                      │       │
│   │  • Pod Security Admission (restricted profile)                │       │
│   │  • Network Policies (deny all by default)                     │       │
│   └───────────────────────────────────────────────────────────────┘       │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│  COUCHE 3: CHIFFREMENT                                                     │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│   At-Rest:                          In-Transit:                           │
│   • VM Disks (Nutanix encryption)   • mTLS entre composants              │
│   • etcd (encrypted)                • Ingress TLS (cert-manager)         │
│   • Secrets (sealed-secrets)        • Service Mesh (Istio optional)      │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│  COUCHE 4: MONITORING & AUDIT                                              │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│   Runtime Security:              Compliance:                              │
│   • Falco (anomaly detection)    • OpenSCAP scanning                      │
│   • Audit logs → SIEM            • CIS benchmarks                         │
│   • File integrity (AIDE)        • Policy enforcement (OPA)               │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

## 📊 Architecture Haute Disponibilité

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    HAUTE DISPONIBILITÉ & RÉSILIENCE                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│  CONTROL PLANE (Masters)                                                   │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│   Master-0          Master-1          Master-2                            │
│      │                 │                 │                                 │
│      ├─ etcd-0 ────────┼─ etcd-1 ───────┼─ etcd-2                         │
│      │  (leader)       │  (follower)     │  (follower)                     │
│      │                 │                 │                                 │
│      │  Quorum: 2/3 minimum requis                                        │
│      │  Tolère: 1 panne                                                   │
│      │                                                                     │
│      ├─ API Server ────┼─ API Server ───┼─ API Server                     │
│      │  (active)       │  (active)       │  (active)                       │
│      │                 │                 │                                 │
│      │  Load Balanced (tous actifs)                                       │
│      │  Tolère: 2 pannes (degraded) / 0 panne (normal)                   │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│  DATA PLANE (Workers)                                                      │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│   Worker-0          Worker-1          Worker-2                            │
│      │                 │                 │                                 │
│      ├─ Pods ──────────┼─ Pods ─────────┼─ Pods                           │
│      │  (replicas)     │  (replicas)     │  (replicas)                     │
│      │                 │                 │                                 │
│      │  Workload distribué via Kubernetes Scheduler                       │
│      │  Tolère: N-1 pannes (selon replicas)                               │
│      │                                                                     │
│      ├─ Ingress ───────┼─ Ingress ──────┼─ Ingress                        │
│      │  (Router)       │  (Router)       │  (Router)                       │
│      │                 │                 │                                 │
│      │  Load Balanced (tous actifs)                                       │
│      │  Tolère: N-1 pannes                                                │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│  SCÉNARIOS DE PANNE                                                        │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  1 Master down:   ✓ Cluster OK (etcd quorum: 2/3)                         │
│  2 Masters down:  ✗ Cluster degraded (etcd no quorum: 1/3)                │
│  3 Masters down:  ✗ Cluster down                                          │
│                                                                            │
│  1 Worker down:   ✓ Workloads OK (pods rescheduled)                       │
│  2 Workers down:  ✓ Workloads OK (selon replicas)                         │
│  N Workers down:  Status dépend du nombre de replicas                     │
│                                                                            │
│  Bootstrap down:  ✓ OK (bootstrap supprimé post-install)                  │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

## 🔄 Flux de Données - Requête Applicative

```
┌─────────────────────────────────────────────────────────────────────────────┐
│               FLUX D'UNE REQUÊTE APPLICATIVE (HTTP/HTTPS)                   │
└─────────────────────────────────────────────────────────────────────────────┘

  1. Client
     │
     │ GET https://myapp.apps.ocp-cluster.example.com
     │
     ▼
  2. DNS Resolution
     │
     │ *.apps.ocp-cluster.example.com → Load Balancer IP
     │
     ▼
  3. Load Balancer
     │
     │ Round-robin vers Workers (192.168.50.14, .15, .16)
     │
     ▼
  4. Worker Node (ex: Worker-0)
     │
     │ Réception sur port 443
     │
     ▼
  5. Ingress Controller (Router Pod)
     │
     │ • TLS termination
     │ • Route matching (myapp.apps...)
     │ • Backend selection
     │
     ▼
  6. Service (ClusterIP)
     │
     │ • Load balance vers Pods
     │ • kube-proxy (iptables/IPVS)
     │
     ▼
  7. Application Pod
     │
     │ • Process request
     │ • Return response
     │
     ▼
  8. Response (reverse path)
     │
     │ Pod → Service → Router → LB → Client
     │
     ▼
  9. Client receives response ✓
```

## 🛠️ Ports et Protocoles OpenShift

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     PORTS ET PROTOCOLES REQUIS                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│  MASTERS (Control Plane)                                                   │
├────────────────────────────────────────────────────────────────────────────┤
│  Port   │ Protocol │ Service                    │ Source                  │
├─────────┼──────────┼────────────────────────────┼─────────────────────────┤
│  6443   │ TCP      │ Kubernetes API             │ All (via LB)            │
│  22623  │ TCP      │ Machine Config Server      │ Bootstrap, Nodes        │
│  2379   │ TCP      │ etcd client                │ Masters                 │
│  2380   │ TCP      │ etcd peer                  │ Masters                 │
│  10250  │ TCP      │ Kubelet                    │ Masters                 │
│  10257  │ TCP      │ kube-controller-manager    │ Localhost               │
│  10259  │ TCP      │ kube-scheduler             │ Localhost               │
│  9100   │ TCP      │ Node exporter (monitoring) │ Masters, Workers        │
└─────────┴──────────┴────────────────────────────┴─────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│  WORKERS (Compute)                                                         │
├────────────────────────────────────────────────────────────────────────────┤
│  Port   │ Protocol │ Service                    │ Source                  │
├─────────┼──────────┼────────────────────────────┼─────────────────────────┤
│  80     │ TCP      │ HTTP Ingress               │ All (via LB)            │
│  443    │ TCP      │ HTTPS Ingress              │ All (via LB)            │
│  10250  │ TCP      │ Kubelet                    │ Masters                 │
│  9100   │ TCP      │ Node exporter              │ Masters, Workers        │
└─────────┴──────────┴────────────────────────────┴─────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│  ALL NODES (Networking)                                                    │
├────────────────────────────────────────────────────────────────────────────┤
│  Port   │ Protocol │ Service                    │ Source                  │
├─────────┼──────────┼────────────────────────────┼─────────────────────────┤
│  4789   │ UDP      │ VXLAN (OVN overlay)        │ All nodes               │
│  6081   │ UDP      │ Geneve (OVN overlay)       │ All nodes               │
│  9000   │ TCP      │ OVN northbound DB          │ Masters                 │
│  9001   │ TCP      │ OVN southbound DB          │ All nodes               │
└─────────┴──────────┴────────────────────────────┴─────────────────────────┘
```

## 📦 Terraform Resource Mapping

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       TERRAFORM → INFRASTRUCTURE                            │
└─────────────────────────────────────────────────────────────────────────────┘

variables.tf                     main.tf                      outputs.tf
     │                              │                              │
     │                              │                              │
     ├─ cluster_name ──────────────►├─ locals.cluster_fqdn        │
     │                              │  locals.bootstrap_metadata   │
     │                              │                              │
     ├─ masters_count = 3 ─────────►├─ resource "..." "master" {  │
     │                              │    count = 3                 │
     │                              │  }                           │
     │                              │                              │
     ├─ master_cpu = 8 ────────────►├─ triggers {                 │
     ├─ master_memory = 32768       │    cpu = var.master_cpu     ├─► master_ips
     ├─ master_disk = 200           │    memory = var...          ├─► master_hostnames
     │                              │  }                           ├─► deployment_summary
     │                              │                              │
     ├─ master_ignition ───────────►├─ ignition_file = ...        │
     │                              │                              │
     │                              │                              │
     └─ bootstrap_* ───────────────►└─ resource "..." "bootstrap" └─► bootstrap_ip
        worker_*                       resource "..." "worker"        worker_ips

┌────────────────────────────────────────────────────────────────────────────┐
│  EXEMPLE D'EXÉCUTION                                                       │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  $ terraform plan                                                          │
│                                                                            │
│  Terraform will perform the following actions:                            │
│                                                                            │
│    # null_resource.bootstrap_node will be created                         │
│    + resource "null_resource" "bootstrap_node" {                          │
│        + id = (known after apply)                                         │
│        + triggers = {                                                     │
│            + "name"      = "ocp-cluster-bootstrap"                        │
│            + "cpu"       = "4"                                            │
│            + "memory"    = "16384"                                        │
│            + "ip_address"= "192.168.50.10"                                │
│          }                                                                │
│      }                                                                    │
│                                                                            │
│    # null_resource.master_nodes[0] will be created                        │
│    # null_resource.master_nodes[1] will be created                        │
│    # null_resource.master_nodes[2] will be created                        │
│    ...                                                                    │
│                                                                            │
│  Plan: 6 to add, 0 to change, 0 to destroy.                               │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```
