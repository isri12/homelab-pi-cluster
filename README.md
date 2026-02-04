# Home Lab Raspberry Pi Cluster

Welcome to the Home Lab Raspberry Pi Cluster project! This repository contains the Infrastructure as Code (IaC) to deploy and manage a Kubernetes cluster on Raspberry Pi hardware using K3s and Ansible.

Kubernetes (K3s), Ansible, Helm, Docker/containerd, Prometheus, Grafana, GitOps, Bash Scripting. 
Systems & Networking: Linux (Ubuntu), NFS Storage, TCP/IP, DNS (Pi-hole), Load Balancing (MetalLB), Kernel Configuration (cgroups).


## Documentation

Please refer to the following documents for detailed information:

*   **[Detailed Setup Guide](details.md)**
    *   Full installation instructions, hardware requirements, architecture diagrams, and service configuration.
*   **[Known Issues & Troubleshooting](Issues.md)**
    *   Solutions for common problems (e.g., cgroup errors), debugging steps, and fix logs.
*   **[Helpful Commands](helpful_commands.md)**
    *   A cheat sheet for useful system and Kubernetes commands.

## Project Overview

This project automates the deployment of a lightweight Kubernetes cluster optimized for ARM hardware. It transforms a set of Raspberry Pis into a production-ready home lab capable of running essential self-hosted services.

### Key Features
*   **Automated Deployment**: Full cluster setup using Ansible playbooks.
*   **Lightweight Kubernetes**: Uses K3s for low resource consumption.
*   **GitOps Ready**: Infrastructure defined as code.
*   **Shared Storage**: NFS provisioning for persistent data.

##  Architecture & Hardware

*   **Master Node**: Raspberry Pi 4 (4GB RAM) - Runs Control Plane & API Server.
*   **Worker Nodes**: 2x Raspberry Pi 3 Model B+ - Runs Application Workloads.
*   **Storage**: USB Drive via NFS (Future: Pi 5 NAS).

###  Network Topology

```mermaid
graph TD
    Internet((☁️ Internet)) <--> Router[🏠 Home Router]
    
    subgraph DevEnv [💻 Dev Environment]
        Laptop[Developer Laptop<br/>(Ansible/Kubectl)]
    end
    
    subgraph Cluster [🍓 Raspberry Pi Cluster]
        Master[Master Node<br/>(Pi 4)]
        Worker1[Worker 1<br/>(Pi 3B+)]
        Worker2[Worker 2<br/>(Pi 3B+)]
    end

    Router <--> Laptop
    Router <--> Master
    Router <--> Worker1
    Router <--> Worker2
    
    Laptop -.->|SSH / Ansible| Master
    Laptop -.->|SSH / Ansible| Worker1
    Laptop -.->|SSH / Ansible| Worker2
```

##  Services Running

*   **Pi-hole**: Network-wide ad blocking and DNS.
*   **Home Assistant**: Home automation hub.
*   **N8n**: Workflow automation.
*   **Monitoring Stack**: Grafana & Prometheus for cluster metrics.

##  Quick Start Summary

1.  **Flash OS**: Install Ubuntu Server (Master) and Raspberry Pi OS Lite (Workers).
2.  **Configure**: Update `ansible/inventory/hosts.yml` with your IPs.
3.  **Deploy**: Run the automated setup script:
    ```bash
    ./scripts/setup-cluster.sh
    ```
