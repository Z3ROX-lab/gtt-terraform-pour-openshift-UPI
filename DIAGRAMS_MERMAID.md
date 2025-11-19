# Diagrammes Mermaid - Architecture OpenShift UPI

Ce fichier contient des diagrammes Mermaid interactifs pour visualiser l'architecture OpenShift UPI et le code Terraform.

> **Note** : Ces diagrammes sont rendus automatiquement sur GitHub, GitLab, et dans la plupart des éditeurs Markdown modernes.

---

## 📊 Table des Matières

1. [Architecture Générale](#1-architecture-générale)
2. [Flux de Déploiement](#2-flux-de-déploiement)
3. [Architecture Réseau](#3-architecture-réseau)
4. [Flux de Requête HTTP](#4-flux-de-requête-http)
5. [Structure Terraform](#5-structure-terraform)
6. [Architecture Haute Disponibilité](#6-architecture-haute-disponibilité)
7. [Sécurité Zero Trust](#7-sécurité-zero-trust)
8. [Lifecycle OpenShift UPI](#8-lifecycle-openshift-upi)

---

## 1. Architecture Générale

```mermaid
graph TB
    subgraph Internet
        Client[👤 Client/User]
    end

    subgraph "Load Balancer"
        LB[🔀 Load Balancer<br/>API: 6443<br/>MCS: 22623<br/>HTTP: 80/443]
    end

    subgraph "Cluster OpenShift UPI"
        subgraph "Bootstrap (Temporaire)"
            Bootstrap[🚀 Bootstrap Node<br/>4 vCPU / 16 GB<br/>192.168.50.10<br/>Role: Init cluster]
        end

        subgraph "Control Plane"
            Master0[⚙️ Master-0<br/>8 vCPU / 32 GB<br/>192.168.50.11]
            Master1[⚙️ Master-1<br/>8 vCPU / 32 GB<br/>192.168.50.12]
            Master2[⚙️ Master-2<br/>8 vCPU / 32 GB<br/>192.168.50.13]

            etcd[(🗄️ etcd Cluster<br/>Distributed DB<br/>Quorum: 2/3)]

            Master0 --> etcd
            Master1 --> etcd
            Master2 --> etcd
        end

        subgraph "Compute Nodes"
            Worker0[💻 Worker-0<br/>8 vCPU / 32 GB<br/>192.168.50.14]
            Worker1[💻 Worker-1<br/>8 vCPU / 32 GB<br/>192.168.50.15]
            Worker2[💻 Worker-2<br/>8 vCPU / 32 GB<br/>192.168.50.16]
        end

        subgraph "Workloads"
            Apps[📦 Application Pods]
            Ingress[🌐 Ingress Controllers]
            Monitoring[📊 Monitoring Stack]
        end
    end

    Client --> LB
    LB --> Master0
    LB --> Master1
    LB --> Master2
    LB --> Worker0
    LB --> Worker1
    LB --> Worker2

    Bootstrap -.->|Init & Delete| Master0
    Bootstrap -.->|Init & Delete| Master1
    Bootstrap -.->|Init & Delete| Master2

    Worker0 --> Apps
    Worker1 --> Apps
    Worker2 --> Apps
    Worker0 --> Ingress
    Worker1 --> Ingress
    Worker2 --> Ingress
    Worker0 --> Monitoring
    Worker1 --> Monitoring

    style Bootstrap stroke:#FF0000,stroke-width:4px,stroke-dasharray: 5 5
    style Master0 stroke:#0066CC,stroke-width:4px
    style Master1 stroke:#0066CC,stroke-width:4px
    style Master2 stroke:#0066CC,stroke-width:4px
    style Worker0 stroke:#00AA00,stroke-width:4px
    style Worker1 stroke:#00AA00,stroke-width:4px
    style Worker2 stroke:#00AA00,stroke-width:4px
    style etcd stroke:#FF8800,stroke-width:5px
    style LB stroke:#9900CC,stroke-width:4px
```

**Légende** :
- 🚀 **Bootstrap** (rouge pointillé) : Temporaire, supprimé après installation
- ⚙️ **Masters** (bleu) : Control plane + etcd
- 💻 **Workers** (vert) : Compute nodes
- 🗄️ **etcd** (orange) : Base de données distribuée
- 🔀 **Load Balancer** (violet) : Répartition de charge

---

## 2. Flux de Déploiement

```mermaid
flowchart TD
    Start([🚀 Début Déploiement]) --> TF_Init[1️⃣ Terraform Init]
    TF_Init --> TF_Plan[2️⃣ Terraform Plan<br/>Validation configuration]
    TF_Plan --> TF_Apply[3️⃣ Terraform Apply<br/>Création VMs]

    TF_Apply --> CreateBootstrap[📦 Créer Bootstrap VM<br/>IP: .10<br/>Ignition: bootstrap.ign]
    TF_Apply --> CreateMasters[📦 Créer 3 Masters<br/>IPs: .11, .12, .13<br/>Ignition: master.ign]
    TF_Apply --> CreateWorkers[📦 Créer N Workers<br/>IPs: .14, .15, ...<br/>Ignition: worker.ign]

    CreateBootstrap --> BootBootstrap[🔥 Boot Bootstrap]
    BootBootstrap --> StartMCS[⚙️ Démarrer MCS<br/>Machine Config Server<br/>Port 22623]
    StartMCS --> StartTempCP[⚙️ Control Plane Temporaire<br/>etcd + API Server]

    CreateMasters --> BootMasters[🔥 Boot Masters]
    BootMasters --> FetchIgnition[📥 Fetch master.ign<br/>depuis MCS]
    FetchIgnition --> FormEtcd[🗄️ Former cluster etcd<br/>Quorum: 2/3]
    FormEtcd --> StartAPI[⚙️ Démarrer API Server<br/>kube-controller-manager<br/>kube-scheduler]

    StartTempCP --> Transition{🔄 Transition<br/>Control Plane}
    StartAPI --> Transition

    Transition --> MigrateCPToMasters[✅ CP migré vers Masters]
    MigrateCPToMasters --> DestroyBootstrap[🗑️ Détruire Bootstrap<br/>terraform destroy -target...]

    CreateWorkers --> BootWorkers[🔥 Boot Workers]
    BootWorkers --> FetchWorkerIgnition[📥 Fetch worker.ign]
    FetchWorkerIgnition --> JoinCluster[🔗 Rejoindre cluster<br/>Enregistrement kubelet]

    DestroyBootstrap --> WaitWorkers{⏳ Workers prêts?}
    JoinCluster --> WaitWorkers

    WaitWorkers -->|Non| WaitWorkers
    WaitWorkers -->|Oui| StartSystemPods[📦 Démarrer Pods Système<br/>DNS, Ingress, Monitoring]

    StartSystemPods --> ClusterReady([✅ Cluster Opérationnel])

    ClusterReady --> Outputs[📊 Terraform Outputs<br/>IPs, DNS, LB config]

    style Start stroke:#00AA00,stroke-width:5px
    style ClusterReady stroke:#00AA00,stroke-width:5px
    style CreateBootstrap stroke:#FF0000,stroke-width:4px
    style BootBootstrap stroke:#FF0000,stroke-width:4px
    style StartMCS stroke:#FF0000,stroke-width:4px
    style DestroyBootstrap stroke:#FF0000,stroke-width:4px,stroke-dasharray: 5 5
    style CreateMasters stroke:#0066CC,stroke-width:4px
    style BootMasters stroke:#0066CC,stroke-width:4px
    style FormEtcd stroke:#FF8800,stroke-width:4px
    style CreateWorkers stroke:#00AA00,stroke-width:4px
    style BootWorkers stroke:#00AA00,stroke-width:4px
```

**Phases** :
- **Phase 1** : Terraform (provision VMs)
- **Phase 2** : Bootstrap démarre
- **Phase 3** : Masters forment le cluster
- **Phase 4** : Transition control plane
- **Phase 5** : Workers rejoignent
- **Phase 6** : Cluster opérationnel

---

## 3. Architecture Réseau

```mermaid
graph TB
    subgraph DNS["🌐 DNS Configuration"]
        API_DNS[api.ocp-cluster.example.com<br/>→ Load Balancer]
        API_INT_DNS[api-int.ocp-cluster.example.com<br/>→ Load Balancer]
        APPS_DNS[*.apps.ocp-cluster.example.com<br/>→ Load Balancer]
        ETCD_DNS[etcd-0/1/2.ocp-cluster.example.com<br/>→ Masters]
    end

    subgraph LB["🔀 Load Balancer"]
        LB_API[Port 6443<br/>Kubernetes API]
        LB_MCS[Port 22623<br/>Machine Config Server]
        LB_HTTP[Port 80<br/>HTTP Ingress]
        LB_HTTPS[Port 443<br/>HTTPS Ingress]
    end

    subgraph Network["📡 Network: 192.168.50.0/24"]
        GW[🚪 Gateway<br/>192.168.50.1]

        subgraph Bootstrap_Net["Bootstrap VLAN"]
            BS[Bootstrap<br/>192.168.50.10]
        end

        subgraph Masters_Net["Control Plane VLAN"]
            M0[Master-0<br/>192.168.50.11]
            M1[Master-1<br/>192.168.50.12]
            M2[Master-2<br/>192.168.50.13]
        end

        subgraph Workers_Net["Data Plane VLAN"]
            W0[Worker-0<br/>192.168.50.14]
            W1[Worker-1<br/>192.168.50.15]
            W2[Worker-2<br/>192.168.50.16]
        end
    end

    API_DNS --> LB_API
    API_INT_DNS --> LB_API
    APPS_DNS --> LB_HTTP
    APPS_DNS --> LB_HTTPS
    ETCD_DNS --> M0
    ETCD_DNS --> M1
    ETCD_DNS --> M2

    LB_API --> M0
    LB_API --> M1
    LB_API --> M2

    LB_MCS --> M0
    LB_MCS --> M1
    LB_MCS --> M2

    LB_HTTP --> W0
    LB_HTTP --> W1
    LB_HTTP --> W2

    LB_HTTPS --> W0
    LB_HTTPS --> W1
    LB_HTTPS --> W2

    GW --> BS
    GW --> M0
    GW --> M1
    GW --> M2
    GW --> W0
    GW --> W1
    GW --> W2

    style DNS stroke:#0066CC,stroke-width:4px
    style LB stroke:#9900CC,stroke-width:4px
    style Bootstrap_Net stroke:#FF0000,stroke-width:4px
    style Masters_Net stroke:#0066CC,stroke-width:4px
    style Workers_Net stroke:#00AA00,stroke-width:4px
```

---

## 4. Flux de Requête HTTP

```mermaid
sequenceDiagram
    actor User as 👤 User
    participant DNS as 🌐 DNS
    participant LB as 🔀 Load Balancer
    participant Worker as 💻 Worker Node
    participant Router as 🌐 Ingress Controller
    participant Service as 🔗 K8s Service
    participant Pod as 📦 Application Pod

    User->>DNS: GET https://myapp.apps.ocp-cluster.example.com
    DNS-->>User: Resolve to Load Balancer IP

    User->>LB: HTTPS Request (443)
    Note over LB: Round-robin<br/>sélection Worker

    LB->>Worker: Forward to Worker-0:443
    Worker->>Router: Traffic arrives at Router Pod

    Note over Router: 1. TLS Termination<br/>2. Route Matching<br/>3. Backend Selection

    Router->>Service: Forward to Service ClusterIP
    Note over Service: kube-proxy<br/>Load balancing<br/>(iptables/IPVS)

    Service->>Pod: Forward to healthy Pod
    Note over Pod: Process Request<br/>Generate Response

    Pod-->>Service: HTTP Response
    Service-->>Router: Response
    Router-->>Worker: Response
    Worker-->>LB: Response
    LB-->>User: HTTPS Response

    Note over User,Pod: End-to-End Encryption<br/>& Load Balancing

    rect rgb(200, 255, 200)
        Note over User,Pod: ✅ Request Successful
    end
```

---

## 5. Structure Terraform

```mermaid
graph LR
    subgraph Input["📥 Input"]
        VarFile[variables.tf<br/>📋 Définitions<br/>+ Validations]
        TFVars[terraform.tfvars<br/>⚙️ Valeurs<br/>configuration]
    end

    subgraph Execution["⚙️ Terraform Execution"]
        Locals[locals block<br/>🧮 Calculs<br/>IPs, metadata]

        Resources[Resources<br/>📦 VMs]

        Bootstrap[null_resource<br/>bootstrap_node<br/>🚀 x1]
        Masters[null_resource<br/>master_nodes<br/>⚙️ x3]
        Workers[null_resource<br/>worker_nodes<br/>💻 xN]

        Resources --> Bootstrap
        Resources --> Masters
        Resources --> Workers
    end

    subgraph Output["📤 Output"]
        OutIPs[outputs.tf<br/>📊 IPs & Names]
        OutDNS[outputs.tf<br/>🌐 DNS Config]
        OutLB[outputs.tf<br/>🔀 LB Config]
        OutAnsible[outputs.tf<br/>📝 Ansible Inventory]
        OutSummary[outputs.tf<br/>📋 Summary]
    end

    VarFile --> Locals
    TFVars --> Locals
    Locals --> Resources

    Bootstrap --> OutIPs
    Masters --> OutIPs
    Workers --> OutIPs

    Masters --> OutDNS

    Masters --> OutLB
    Workers --> OutLB

    Bootstrap --> OutAnsible
    Masters --> OutAnsible
    Workers --> OutAnsible

    Bootstrap --> OutSummary
    Masters --> OutSummary
    Workers --> OutSummary

    style VarFile stroke:#0066CC,stroke-width:4px
    style TFVars stroke:#0066CC,stroke-width:4px
    style Locals stroke:#FF8800,stroke-width:4px
    style Bootstrap stroke:#FF0000,stroke-width:4px
    style Masters stroke:#0066CC,stroke-width:4px
    style Workers stroke:#00AA00,stroke-width:4px
    style OutIPs stroke:#9900CC,stroke-width:4px
    style OutDNS stroke:#9900CC,stroke-width:4px
    style OutLB stroke:#9900CC,stroke-width:4px
    style OutAnsible stroke:#9900CC,stroke-width:4px
    style OutSummary stroke:#9900CC,stroke-width:4px
```

**Flow** :
1. Variables définies (variables.tf)
2. Valeurs fournies (terraform.tfvars)
3. Calculs dans locals (IPs, noms)
4. Création des ressources VMs
5. Outputs générés (IPs, DNS, LB, etc.)

---

## 6. Architecture Haute Disponibilité

```mermaid
graph TB
    subgraph HA["🏗️ Haute Disponibilité"]
        subgraph Masters["⚙️ Control Plane (Masters)"]
            M0[Master-0<br/>✅ Running]
            M1[Master-1<br/>✅ Running]
            M2[Master-2<br/>❌ Down]

            E0[etcd-0<br/>Leader]
            E1[etcd-1<br/>Follower]
            E2[etcd-2<br/>❌ Down]

            M0 --> E0
            M1 --> E1
            M2 -.->|Failed| E2

            E0 <--> E1
            E0 -.-|Lost| E2
            E1 -.-|Lost| E2
        end

        subgraph Quorum["🗄️ etcd Quorum"]
            Q[Quorum: 2/3 ✅<br/>Leader: E0<br/>Followers: E1<br/><br/>Cluster: HEALTHY]
        end

        subgraph Workers["💻 Compute (Workers)"]
            W0[Worker-0<br/>✅ Running<br/>Pods: 10/10]
            W1[Worker-1<br/>✅ Running<br/>Pods: 10/10]
            W2[Worker-2<br/>❌ Down<br/>Pods: Evicted]

            W0 --> Pods0[📦 Pods 0-9]
            W1 --> Pods1[📦 Pods 10-19]
            W2 -.->|Failed| Pods2[📦 Pods Rescheduled]

            Pods2 -.-> W0
            Pods2 -.-> W1
        end

        E0 --> Q
        E1 --> Q
    end

    subgraph Scenarios["📊 Scénarios de Panne"]
        S1[1 Master down<br/>✅ Cluster OK<br/>etcd quorum: 2/3]
        S2[2 Masters down<br/>❌ Cluster degraded<br/>etcd no quorum: 1/3]
        S3[1 Worker down<br/>✅ Pods rescheduled<br/>Service OK]
    end

    style M0 stroke:#00AA00,stroke-width:4px
    style M1 stroke:#00AA00,stroke-width:4px
    style M2 stroke:#FF0000,stroke-width:4px,stroke-dasharray: 5 5
    style E0 stroke:#00AA00,stroke-width:4px
    style E1 stroke:#00AA00,stroke-width:4px
    style E2 stroke:#FF0000,stroke-width:4px,stroke-dasharray: 5 5
    style Q stroke:#FF8800,stroke-width:5px
    style W0 stroke:#00AA00,stroke-width:4px
    style W1 stroke:#00AA00,stroke-width:4px
    style W2 stroke:#FF0000,stroke-width:4px,stroke-dasharray: 5 5
    style S1 stroke:#00AA00,stroke-width:4px
    style S2 stroke:#FF0000,stroke-width:4px
    style S3 stroke:#00AA00,stroke-width:4px
```

**Tolérance aux pannes** :
- ✅ **1 Master down** : Cluster OK (quorum etcd: 2/3)
- ❌ **2 Masters down** : Cluster degraded (pas de quorum)
- ✅ **1+ Worker down** : Pods reschedulés sur workers sains

---

## 7. Sécurité Zero Trust

```mermaid
graph TB
    subgraph ZeroTrust["🔒 Architecture Sécurité Zero Trust"]
        subgraph Layer1["Couche 1: Network Security"]
            VLAN1[VLAN 10<br/>Management<br/>Bootstrap + Bastion]
            VLAN2[VLAN 20<br/>Control Plane<br/>Masters + etcd]
            VLAN3[VLAN 30<br/>Data Plane<br/>Workers + Apps]

            Microseg[Nutanix Flow<br/>Microsegmentation<br/>Policy-based isolation]

            VLAN1 --> Microseg
            VLAN2 --> Microseg
            VLAN3 --> Microseg
        end

        subgraph Layer2["Couche 2: Identity & Access"]
            RBAC[OpenShift RBAC<br/>Role-Based Access Control]
            OAuth[OAuth / LDAP<br/>Identity Provider]
            PSA[Pod Security Admission<br/>restricted profile]
            NetPol[Network Policies<br/>deny-all by default]

            OAuth --> RBAC
            RBAC --> PSA
            RBAC --> NetPol
        end

        subgraph Layer3["Couche 3: Encryption"]
            AtRest[Encryption at Rest<br/>• VM Disks<br/>• etcd<br/>• Secrets]
            InTransit[Encryption in Transit<br/>• mTLS<br/>• Ingress TLS<br/>• Service Mesh]

            AtRest --> SecureBoot[Secure Boot<br/>+ vTPM]
            InTransit --> CertMgr[cert-manager<br/>Certificate Automation]
        end

        subgraph Layer4["Couche 4: Monitoring & Audit"]
            Runtime[Falco<br/>Runtime Security<br/>Anomaly Detection]
            Audit[Audit Logs<br/>→ SIEM<br/>Centralized Logging]
            Compliance[OpenSCAP<br/>CIS Benchmarks<br/>Policy Enforcement]

            Runtime --> SIEM[Splunk / Elastic SIEM]
            Audit --> SIEM
            Compliance --> OPA[OPA / Kyverno<br/>Policy as Code]
        end
    end

    style Layer1 stroke:#FF0000,stroke-width:4px
    style Layer2 stroke:#0066CC,stroke-width:4px
    style Layer3 stroke:#FF8800,stroke-width:4px
    style Layer4 stroke:#00AA00,stroke-width:4px
    style Microseg stroke:#FF0000,stroke-width:4px
    style RBAC stroke:#0066CC,stroke-width:4px
    style AtRest stroke:#FF8800,stroke-width:4px
    style InTransit stroke:#FF8800,stroke-width:4px
    style Runtime stroke:#00AA00,stroke-width:4px
    style Audit stroke:#00AA00,stroke-width:4px
```

**4 Couches de Défense** :
1. 🔴 **Network** : VLANs, microsegmentation
2. 🔵 **Identity** : RBAC, OAuth, pod security
3. 🟠 **Encryption** : At-rest, in-transit, mTLS
4. 🟢 **Monitoring** : Runtime security, audit, compliance

---

## 8. Lifecycle OpenShift UPI

```mermaid
stateDiagram-v2
    [*] --> Planning: Définir architecture

    Planning --> GenerateIgnition: openshift-install create ignition-configs

    GenerateIgnition --> TerraformInit: terraform init

    TerraformInit --> TerraformPlan: terraform plan

    TerraformPlan --> TerraformApply: terraform apply

    TerraformApply --> BootstrapPhase: Bootstrap démarre

    BootstrapPhase --> MastersPhase: Masters rejoignent

    MastersPhase --> ControlPlaneReady: Control Plane opérationnel

    ControlPlaneReady --> DestroyBootstrap: terraform destroy -target bootstrap

    DestroyBootstrap --> WorkersPhase: Workers rejoignent

    WorkersPhase --> ClusterReady: Cluster opérationnel

    ClusterReady --> Operations: Ops quotidiennes

    Operations --> Scaling: Scale workers
    Scaling --> Operations

    Operations --> Upgrade: Upgrade OpenShift
    Upgrade --> Operations

    Operations --> Monitoring: Monitoring & Audit
    Monitoring --> Operations

    Operations --> Decommission: Fin de vie

    Decommission --> TerraformDestroy: terraform destroy

    TerraformDestroy --> [*]

    note right of Planning
        Exercice: Modélisation Terraform
        Livrable: Code IaC
    end note

    note right of BootstrapPhase
        15-30 minutes
        Temporaire
    end note

    note right of ControlPlaneReady
        ✅ Bootstrap peut être supprimé
    end note

    note right of ClusterReady
        ✅ Cluster production-ready
        Outputs Terraform disponibles
    end note

    note right of Operations
        BAU: Monitoring, Scaling, Patching
    end note
```

**Phases du Lifecycle** :
1. **Planning** → Architecture design
2. **Generate Ignition** → openshift-install
3. **Terraform** → Provision infrastructure
4. **Bootstrap** → Init cluster (15-30 min)
5. **Masters** → Control plane (30-45 min)
6. **Destroy Bootstrap** → Cleanup
7. **Workers** → Compute nodes (45-60 min)
8. **Operations** → Production
9. **Decommission** → terraform destroy

---

## 📊 Utilisation pour les Présentations

### Recommandations

1. **Sur GitHub** : Les diagrammes s'affichent automatiquement
2. **Pendant la présentation** : Ouvrir ce fichier dans un navigateur
3. **Présentation** :
   - Commencer par le **Diagramme 1** (Architecture générale)
   - Expliquer le flux avec le **Diagramme 2** (Déploiement)
   - Détailler la sécurité avec le **Diagramme 7** (Zero Trust)

### Outils de Rendu

Si GitHub ne rend pas les diagrammes :

- **Mermaid Live Editor** : https://mermaid.live/
- **VS Code** : Extension "Markdown Preview Mermaid Support"
- **Chrome/Firefox** : Extension "Markdown Preview Plus"

### Export en Images

```bash
# Installer mmdc (mermaid-cli)
npm install -g @mermaid-js/mermaid-cli

# Exporter en PNG
mmdc -i DIAGRAMS_MERMAID.md -o diagrams.png
```

---

## 🎨 Légende des Couleurs

Les diagrammes utilisent une palette de couleurs **simples et très contrastées** (bordures épaisses uniquement, sans fond coloré) pour une lisibilité maximale :

| Couleur | Code Hex | Signification | Usage |
|---------|----------|---------------|-------|
| 🔴 **Rouge** | `#FF0000` | Bootstrap / Erreurs | Noeud temporaire ou composants en panne |
| 🔵 **Bleu** | `#0066CC` | Masters / Control Plane | Masters, API, composants de contrôle |
| 🟢 **Vert** | `#00AA00` | Workers / OK | Workers, noeuds compute, états sains |
| 🟠 **Orange** | `#FF8800` | etcd / Attention | Base de données distribuée, warnings |
| 🟣 **Violet** | `#9900CC` | Load Balancer / Outputs | LB, outputs Terraform |

> **Note** : Les couleurs utilisent uniquement des **bordures épaisses (4-5px)** sans fond coloré pour une meilleure lisibilité sur tous les fonds (clair/sombre).

---

**Ces diagrammes sont interactifs sur GitHub et dans la plupart des éditeurs Markdown modernes !**
