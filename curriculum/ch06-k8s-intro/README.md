```
  ___ _      __    _  __    _                      _
 / __| |_   / /   | |/ /  _| |__  ___ _ _ _ _  ___| |_ ___ ___
| (__| ' \ / _ \  | ' < || | '_ \/ -_) '_| ' \/ -_)  _/ -_|_-<
 \___|_||_|\___/  |_|\_\_,_|_.__/\___|_| |_||_\___|\__\___/__/

 ⎈ "The Giant Roaster"

    Single Docker Host 💀      Kubernetes Cluster 🚀
    .--------------.           .-----------------------.
    | app  app  app|           | Node 1     Node 2     |
    | 100% CPU     |           | app app    app app    |
    | OUT OF MEMORY|           |                       |
    '--------------'           | Node 3     auto-heal  |
     one machine               | app app    app <- new |
     = one point               |                       |
       of failure              '-----------------------'
                                self-healing + scaling

    (@_@;) Dave at 3 AM: "WHAT DO WE DO" 🆘
    (^_^)  Sarah: "We Kubernetes." 😎
```

# Chapter 6: The Giant Roaster

## Story

It's 3:07 AM.

Your phone is going off like a fire alarm. Then your laptop. Then your watch, which you didn't even know had notifications enabled.

The screen glows in the dark: **50,000 concurrent users**. A coffee influencer with 2 million followers posted about NoCappuccino's limited-edition Nitro Cold Brew at midnight. The tweet went viral. The post is still going.

Your single Docker host is at 100% CPU. The load average looks like a phone number. The app is crawling, then timing out, then — nothing.

Dave's messages come in rapid-fire, each one more all-caps than the last:

> **Dave 3:08 AM:** THE APP IS DOWN
> **Dave 3:08 AM:** SARAH ARE YOU AWAKE
> **Dave 3:09 AM:** WHAT DO WE DO
> **Dave 3:09 AM:** CAN WE JUST RESTART THE SERVER
> **Dave 3:09 AM:** I AM RESTARTING THE SERVER

You type back before he can make it worse: *"Dave — step away from the keyboard. I've got this."*

You've been waiting for this moment. One machine was never going to be enough. You've read the docs. You've run the tutorials. You've been quietly setting up kind on your laptop for exactly this scenario.

It's time to stop running one Docker host and start running a **cluster**.

Time to meet Kubernetes.

---

## What You'll Learn

By the end of this chapter, you'll be able to:

- Explain why a single Docker host is a single point of failure and what orchestration solves
- Describe the Kubernetes architecture: Control Plane components and Worker Nodes
- Create a local Kubernetes cluster with kind
- Write Deployment and Pod YAML manifests
- Use `kubectl apply`, `kubectl get`, `kubectl describe`, and `kubectl logs`
- Understand why Services exist and how they use Labels and Selectors
- Create ClusterIP and NodePort Services
- Use `kubectl port-forward` for local testing
- Diagnose common failures like CrashLoopBackOff and ImagePullBackOff

---

## Prerequisites

- Chapter 5 completed (you understand Docker Compose, multi-container apps, and environment variables)
- Docker installed and running
- **kind** installed: https://kind.sigs.k8s.io/docs/user/quick-start/#installation
- **kubectl** installed: https://kubernetes.io/docs/tasks/tools/

Not sure if you have them? Run:

```bash
kind version
kubectl version --client
```

Both should print a version number without errors.

---

## Lessons

| # | Lesson | What you'll learn |
|---|--------|-------------------|
| 01 | [Why Kubernetes](lessons/01-why-kubernetes.md) | The limits of one host, orchestration concepts, K8s architecture, kind setup |
| 02 | [Pods and Deployments](lessons/02-pods-and-deployments.md) | Pod anatomy, Deployment YAML, ReplicaSets, core kubectl commands |
| 03 | [Services and Networking](lessons/03-services-and-networking.md) | Why Pods need Services, ClusterIP/NodePort/LoadBalancer, Labels and Selectors |

---

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Self-Healing](challenges/01-self-healing.md) | Deploy nginx with 3 replicas and watch K8s resurrect deleted Pods |
| 02 | [Service Discovery](challenges/02-service-discovery.md) | Connect a frontend to a backend using a ClusterIP Service by name |
| 03 | [Debug the ImagePullBackOff](challenges/03-debug-crashloop.md) | Diagnose and fix a Deployment stuck in ImagePullBackOff |

---

## Verification

Run `challenges/verify.sh` to check all three challenges at once:

```bash
bash curriculum/ch06-k8s-intro/challenges/verify.sh
```

---

## The Underlying Concepts

Kubernetes is built on the **reconciliation loop** — an infinite cycle where the control plane compares the *desired state* (what you declared in your YAML) against the *actual state* (what's actually running), and takes action to close the gap.

This is why Kubernetes self-heals: you don't tell it "restart this Pod." You tell it "I want 3 replicas of this app running." When a Pod dies, K8s notices the actual count (2) doesn't match the desired count (3) and creates a new one.

The same principle underlies scaling, rolling updates, and node failure recovery. It's turtles all the way down.

Under the hood, Kubernetes networking relies on:
- **iptables** rules managed by kube-proxy to route traffic to the right Pod
- **CoreDNS** for service name resolution inside the cluster
- **VXLAN or BGP** for Pod-to-Pod communication across nodes (depending on the CNI plugin)

---

## Post-Chapter Cliffhanger

Once all three challenges pass and the verify script goes green, come back here.

You kept NoCappuccino alive through the traffic spike. By 4 AM, all 3 replicas were running, self-healing was confirmed, and the influencer's followers were actually able to check out.

Dave sent a voice memo at 4:23 AM. You could hear the relief in his voice. "Sarah... you're a wizard. Also — is this kubernetes thing why the coffee machine has been running slow? Never mind. Get some sleep."

You almost close your laptop.

Then the morning Slack pings start rolling in. Three things, simultaneously:

1. Someone deployed an image with the tag `ngnix:latest` instead of `nginx:latest` — typo in the manifest. Pods are stuck in ImagePullBackOff.
2. The recommendation service is getting OOMKilled. Something is leaking memory.
3. Marcus just found database credentials in the pod logs. In plain text. Visible to anyone with kubectl access.

Dave is already on a flight to the coffee supplier conference. No Wi-Fi until tomorrow.

It's just you, the player, and a cluster on fire.

See you in Chapter 7: **The Great Latte Leak**.
