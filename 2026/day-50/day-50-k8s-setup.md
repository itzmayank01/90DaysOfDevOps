# Day 50 – Kubernetes Architecture and Cluster Setup

## Introduction

Today I started learning Kubernetes, which is the most widely used container orchestration platform. While Docker helps run containers, managing hundreds of containers across multiple machines becomes difficult. Kubernetes solves this by automating deployment, scaling, networking, and management of containerized applications.

---

# 1. Kubernetes Story

## Why Kubernetes was created
Docker allows developers to run applications inside containers, but managing many containers across multiple servers becomes complex. Kubernetes was created to solve this problem by providing **container orchestration**. It automatically manages container deployment, scaling, load balancing, and failure recovery across clusters.

## Who created Kubernetes
Kubernetes was originally developed by **Google** and later donated to the **Cloud Native Computing Foundation (CNCF)**. It was inspired by Google's internal cluster management system called **Borg**.

## Meaning of Kubernetes
The word **Kubernetes** comes from Greek and means **“helmsman” or “ship pilot.”**  
It represents steering containers like ships across a fleet of machines.

---

# 2. Kubernetes Architecture

Kubernetes architecture is divided into two main components:

- Control Plane (Master Node)
- Worker Nodes

## Control Plane Components

### API Server
The **API Server** is the main entry point to the Kubernetes cluster. All commands from tools like `kubectl` go through the API server.

### etcd
**etcd** is a distributed key-value database used to store all cluster configuration and state information.

### Scheduler
The **Scheduler** decides which worker node should run a newly created pod based on available resources.

### Controller Manager
The **Controller Manager** continuously monitors the cluster and ensures the desired state matches the actual state.

---

## Worker Node Components

### kubelet
The **kubelet** is an agent running on each worker node that communicates with the API server and manages containers.

### kube-proxy
**kube-proxy** manages networking and ensures communication between pods and services.

### Container Runtime
The container runtime is responsible for running containers. Examples include **containerd** and **CRI-O**.

---

# 3. Kubernetes Architecture Diagram
