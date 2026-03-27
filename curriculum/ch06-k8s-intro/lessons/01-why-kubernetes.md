# Lesson 1: Why Kubernetes

## The 3 AM Problem

You just saw what happens when a single Docker host tries to serve 50,000 concurrent users. It doesn't. It melts.

But the failure wasn't just about CPU. Even if we had a bigger machine, we still had:

- **A single point of failure.** One host dies, the entire app goes down.
- **No self-healing.** A crashed container stays down until someone notices and manually restarts it.
- **No scaling.** Traffic doubles? The only option is "buy a bigger box" (vertical scaling), and there's a ceiling on that.
- **No zero-downtime deployments.** Deploying a new version means stopping the old container and starting a new one — there's a gap.

Docker Compose is great for managing a multi-container app on *one machine*. But one machine is not a production-grade infrastructure. We need something that can manage containers across *many machines* simultaneously.

That something is Kubernetes.

---

## Cattle vs. Pets

Before we talk about K8s architecture, there's an analogy worth having in your toolkit — you'll hear it constantly in DevOps conversations.

### Pets
You give them names. You care about them individually. When a pet gets sick, you nurse it back to health. You know which server is "web-01" and you SSH into it directly when something goes wrong.

This is how most teams run servers before containers. Each machine is special. Losing one is a crisis.

### Cattle
You don't name individual cattle. You manage the herd. If one gets sick, you replace it. What matters is that the herd as a whole stays at the right size and health.

This is how Kubernetes thinks about containers. A Pod is not precious. If it crashes, Kubernetes doesn't try to fix it — it discards it and schedules a fresh one. What matters is that the *desired count* of healthy Pods stays satisfied.

The shift from pets to cattle is the mental model shift required to work with Kubernetes effectively. Your app needs to be stateless (or handle state externally) and accept that any individual instance can be killed at any time.

---

## What Kubernetes Actually Does

Kubernetes is a **container orchestrator**. It manages the full lifecycle of containerized workloads across a cluster of machines:

- **Scheduling:** Deciding which node runs which container, based on available resources
- **Self-healing:** Restarting failed containers, replacing unhealthy Pods, rescheduling when a node goes down
- **Scaling:** Adding or removing replicas based on demand (manually or automatically)
- **Rolling updates:** Deploying new versions without downtime by replacing Pods gradually
- **Service discovery:** Giving stable network names to ephemeral Pods
- **Configuration and secrets management:** Injecting config and credentials into containers without baking them into images

All of this is driven by a single principle: **declarative desired state**. You write a YAML file that says "I want 3 replicas of this app running." Kubernetes figures out how to make that true and keeps it true, forever.

---

## Kubernetes Architecture

A Kubernetes cluster has two types of machines: the **Control Plane** and **Worker Nodes**.

```
┌─────────────────────────────────────────────────────┐
│                    Control Plane                     │
│                                                     │
│  ┌──────────────┐  ┌──────┐  ┌───────────────────┐ │
│  │  API Server  │  │ etcd │  │    Scheduler      │ │
│  └──────────────┘  └──────┘  └───────────────────┘ │
│                                                     │
│  ┌─────────────────────────────────────────────────┐│
│  │           Controller Manager                    ││
│  └─────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────┘
         │               │               │
         ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  Worker Node │ │  Worker Node │ │  Worker Node │
│              │ │              │ │              │
│  ┌─────────┐ │ │  ┌─────────┐ │ │  ┌─────────┐ │
│  │ kubelet │ │ │  │ kubelet │ │ │  │ kubelet │ │
│  └─────────┘ │ │  └─────────┘ │ │  └─────────┘ │
│  ┌──────────┐│ │  ┌──────────┐│ │  ┌──────────┐│
│  │kube-proxy││ │  │kube-proxy││ │  │kube-proxy││
│  └──────────┘│ │  └──────────┘│ │  └──────────┘│
│  [Pods...]   │ │  [Pods...]   │ │  [Pods...]   │
└──────────────┘ └──────────────┘ └──────────────┘
```

### Control Plane Components

The Control Plane is the brain of the cluster. In production it runs on dedicated machines separate from workloads. In kind (local), it runs as a Docker container on your laptop.

**API Server (`kube-apiserver`)**
The single entry point for all cluster operations. Every command you run with `kubectl` is an HTTP request to the API Server. It validates requests, authenticates them, and stores the results in etcd.

Think of it as the reception desk at NoCappuccino HQ. Nothing happens without going through it.

**etcd**
A distributed key-value store that holds the entire cluster state. Every resource — every Pod definition, every Service, every config — lives in etcd.

If etcd is lost without a backup, the cluster's "memory" is gone. This is why etcd backup is a critical production concern (beyond the scope of this course — see CKA certification resources).

**Scheduler (`kube-scheduler`)**
When a new Pod needs to run, the Scheduler decides *which node* it goes to, based on available CPU, memory, affinity rules, and taints/tolerations.

It doesn't start the Pod itself — it just makes the assignment. Think of it as the barista manager deciding which barista handles which order.

**Controller Manager (`kube-controller-manager`)**
A collection of controllers running as a single process, each responsible for a specific resource type. The ReplicaSet controller watches for Pod count mismatches and creates or deletes Pods accordingly. The Node controller watches for unresponsive nodes.

Controllers are the reconciliation loop in action. They constantly ask: "Is actual state == desired state? If not, fix it."

### Worker Node Components

Worker Nodes are the machines that actually run your containerized workloads.

**kubelet**
An agent running on every worker node. It watches the API Server for Pods scheduled to its node, pulls the container images, starts the containers, and reports health status back.

The kubelet is the hands-on worker. The Control Plane tells it what to run; kubelet makes it happen.

**kube-proxy**
Maintains network rules (iptables or IPVS) on each node to implement Service routing. When traffic arrives for a Service, kube-proxy ensures it gets forwarded to the right Pod(s).

---

## Setting Up a Local Cluster with kind

**kind** (Kubernetes IN Docker) runs a full Kubernetes cluster as Docker containers on your laptop. Each node in the cluster is a Docker container. It's the fastest way to get a real K8s environment locally.

### Verify Your Prerequisites

```bash
docker --version       # Need Docker running
kind version           # Should print v0.x.x
kubectl version --client  # Should print Client Version
```

### Create Your First Cluster

```bash
kind create cluster --name learn-k8s
```

This command:
1. Pulls the kind node image (a Docker image with K8s pre-installed)
2. Starts a Docker container acting as the control plane + worker node
3. Configures kubectl to point at this cluster

You'll see output like:
```
Creating cluster "learn-k8s" ...
 ✓ Ensuring node image (kindest/node:v1.x.x) ...
 ✓ Preparing nodes ...
 ✓ Writing configuration ...
 ✓ Starting control-plane ...
 ✓ Installing CNI ...
 ✓ Installing StorageClass ...
Set kubectl context to "kind-learn-k8s"
```

### Verify the Cluster

```bash
kubectl cluster-info --context kind-learn-k8s
kubectl get nodes
```

Expected output for `kubectl get nodes`:
```
NAME                     STATUS   ROLES           AGE   VERSION
learn-k8s-control-plane  Ready    control-plane   1m    v1.x.x
```

`STATUS: Ready` means the node is healthy and ready to accept workloads.

### Understanding kubectl Contexts

kubectl uses **contexts** to know which cluster to talk to. When kind creates a cluster, it adds a context to your `~/.kube/config` file.

```bash
kubectl config get-contexts     # List all contexts
kubectl config current-context  # Show active context
```

You should see `kind-learn-k8s` as your current context. This means all kubectl commands go to your local kind cluster, not any production cluster.

### Create the Chapter Namespace

Kubernetes uses **namespaces** to isolate resources within a cluster. Think of them as folders. We'll do all our chapter work in `learn-ch06` to keep things organized and safe.

```bash
kubectl create namespace learn-ch06
kubectl get namespaces
```

You'll see the system namespaces (`kube-system`, `default`, `kube-public`) plus your new `learn-ch06`.

For the rest of this chapter, most commands will include `-n learn-ch06` to target this namespace explicitly.

---

## What We Didn't Cover (And Why)

A few things you might wonder about:

**Multi-node clusters:** kind supports multi-node clusters (you can add more worker nodes), but a single-node cluster is sufficient for learning all the concepts in this chapter. Production clusters typically have 3+ nodes for high availability.

**Managed Kubernetes (EKS, GKE, AKS):** Cloud providers run the Control Plane for you. You only manage the worker nodes. The concepts are identical — only the setup differs.

**Container Runtime:** Kubernetes no longer directly uses Docker as its container runtime (as of K8s 1.24, dockershim was removed). kind uses `containerd` under the hood. When you specify a Docker image in a K8s manifest, containerd pulls and runs it. You don't need to know this yet, but it explains why you might see `containerd` mentioned in logs.

---

## Summary

| Concept | What it is |
|---------|-----------|
| Cluster | One or more machines managed by Kubernetes together |
| Control Plane | The brain: API Server, etcd, Scheduler, Controller Manager |
| Worker Node | The muscle: runs Pods, has kubelet and kube-proxy |
| kubelet | Agent on each node that runs containers and reports health |
| kube-proxy | Maintains network rules for Service routing on each node |
| etcd | The cluster's database — stores all desired state |
| kind | Tool to run a K8s cluster as Docker containers locally |
| Namespace | A virtual partition within a cluster for isolating resources |
| Context | kubectl's way of knowing which cluster to talk to |

---

Up next: [Lesson 2 — Pods and Deployments](02-pods-and-deployments.md)

You know why we need K8s and how it's structured. Now let's put something in it.
