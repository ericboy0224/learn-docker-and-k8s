```
  ___ _   ___    ___             _         _   _
 / __| |_|__ /  | _ \_ _ ___  __| |_  _ __| |_(_)___ _ _
| (__| ' \|_ \  |  _/ '_/ _ \/ _` | || / _|  _| / _ \ ' \
 \___|_||_|___/  |_| |_| \___/\__,_|\_,_\__|\__|_\___/_||_|

 🔥 "The Great Latte Leak" -- THE FINALE 🔥

    .---------------------------------------------.
    |  INCIDENT REPORT -- 06:47 AM                |
    |                                             |
    |  [!!] API: ImagePullBackOff (typo in tag)   |
    |  [!!] Worker: OOMKilled (memory limit)      |
    |  [!!] DB creds found in public logs         |
    |                                             |
    |  Dave: on a flight (unreachable)   ✈️        |
    |  Marcus: panicking                 😱        |
    |  Sarah: "It's just you and me, kid." 💪     |
    '---------------------------------------------'
```

# Chapter 7: The Great Latte Leak

## The Story So Far

You survived Chapter 6. You built a Kubernetes cluster, deployed the NoCappuccino app with proper Deployments and Services, and watched K8s self-heal right in front of you. Dave was so impressed he sent a thumbs-up GIF. Marcus updated the roadmap to include "K8s stuff" as a Q3 priority. Everything was good.

That was yesterday.

---

## Opening: 6:47 AM

Your phone is going off. Not the "one notification" kind. The sustained, relentless, every-few-seconds kind that means something is actually, genuinely wrong.

You open Slack. Thirty-seven unread messages. The last one from Marcus, sent four minutes ago, is just: `???`

The PagerDuty alert came in at 6:31 AM. You sit up, open your laptop, and read the incident channel from the top.

**6:31 AM — Monitoring:** `api` deployment unhealthy. Pod count 0/3 Running.

**6:33 AM — Monitoring:** `worker` deployment pod restarting. OOMKilled. Restart count: 4.

**6:38 AM — Security Alert:** Database credentials detected in pod log output. Severity: HIGH.

**6:42 AM — @dave:** hey sorry just landed at SFO, got a 9hr flight to London in 20min, no wifi on this one — can someone handle it? I trust you guys

**6:44 AM — @dave:** also what happened to the API

**6:44 AM — @dave:** actually don't answer, boarding

You stare at the screen. Then you look up. Sarah is already at her desk, coffee in hand, reading the same messages.

She looks at you. "Good morning. Welcome to your first real production incident."

You notice she doesn't look panicked. Tired, maybe. But not panicked.

"Three things are broken simultaneously," she says. "Dave is over the Atlantic with no Wi-Fi. Marcus is going to start asking questions in about twenty minutes. The morning rush starts at seven."

She takes a sip of coffee.

"Here's the thing about production incidents: they look like chaos, but they're just a list of problems. You triage, you fix, you document. We've done harder things than this." She nods at your laptop. "Let's get to work."

---

## What You'll Learn

By the end of this chapter, you will be able to:

- Create and use Kubernetes Secrets and ConfigMaps correctly — and understand why base64 is not security
- Perform rolling updates with zero downtime, and roll back when something goes wrong
- Configure resource requests and limits to prevent OOMKilled pods and noisy neighbors
- Read Exit Code 137 like a K8s incident report
- Understand Quality of Service classes and how K8s decides which pod to kill first
- Set up a Horizontal Pod Autoscaler and watch it react to real load
- Triage multiple simultaneous failures without losing your mind

---

## Prerequisites

- Chapter 6 completed (you have the `learn-k8s` kind cluster running with `kubectl` configured)
- The `learn-ch07` namespace will be created as part of the challenges
- Basic comfort with `kubectl get`, `kubectl describe`, and `kubectl logs`

---

## Estimated Time

- Lessons: ~45 minutes
- Challenges: ~60–90 minutes
- Total: ~2 hours (this is the finale — give it the time it deserves)

---

## Lessons

| # | Lesson | What you'll learn |
|---|--------|-------------------|
| 01 | [Secrets and ConfigMaps](lessons/01-secrets-and-configmaps.md) | Separating config from code, why base64 isn't encryption, secret best practices |
| 02 | [Rolling Updates](lessons/02-rolling-updates.md) | Zero-downtime deployments, rollback, blue-green and canary concepts |
| 03 | [Resource Management](lessons/03-resource-management.md) | Requests, limits, OOMKilled, QoS classes, and autoscaling |

---

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Triage the Chaos](challenges/01-triage-chaos.md) | Fix three simultaneous production failures |
| 02 | [Zero-Downtime Update](challenges/02-zero-downtime-update.md) | Roll out a new image version with 0 request failures |
| 03 | [Autoscaling](challenges/03-autoscaling.md) | Configure HPA and watch it scale under load |

To verify your work: `bash curriculum/ch07-k8s-production/challenges/verify.sh`

---

## Key Concepts Reference

| Term | One-line definition |
|------|---------------------|
| **ConfigMap** | K8s object for storing non-sensitive configuration as key-value pairs |
| **Secret** | K8s object for storing sensitive data — base64-encoded, not encrypted by default |
| **Rolling update** | Replace old pods with new ones gradually, keeping the app available throughout |
| **maxSurge** | How many extra pods can exist above the desired count during an update |
| **maxUnavailable** | How many pods can be unavailable during an update |
| **Requests** | The minimum resources K8s guarantees to a pod |
| **Limits** | The maximum resources a pod is allowed to use |
| **OOMKilled** | Pod was killed because it exceeded its memory limit (Exit Code 137) |
| **QoS class** | Priority tier K8s assigns based on requests/limits (Guaranteed, Burstable, BestEffort) |
| **HPA** | Horizontal Pod Autoscaler — automatically scales replica count based on metrics |

---

## Graduation

### The Debrief

It's 8:52 AM.

You push back from your desk. The incident channel is quiet. The monitoring dashboard — the same one that was red and screaming two hours ago — is entirely green. Three deployments, all healthy. Zero OOMKilled pods. No credentials in logs. The HPA is sitting at 2 replicas, relaxed, ready for whatever the morning rush brings.

Sarah is reading through your work. She's quiet for a moment, then closes her laptop.

"That was a real incident," she says. "Not a tutorial. Not a sandbox. Three simultaneous failures, no CTO, morning rush bearing down. And you handled it."

She doesn't oversell it. That's how you know she means it.

---

At 9:14 AM, a Slack message comes in from an unknown number.

**@dave** (via Heathrow airport Wi-Fi): `landed. checking status. everything is... green?`

**@dave**: `who fixed the API`

**@dave**: `and why does the worker pod have actual memory limits now`

**@dave**: `also why are our DB creds not in the logs anymore`

**@dave**: `actually I don't need to know how. I just need to know it's fixed. good work team`

**@dave**: `going to get a coffee. they have a NoCappuccino kiosk here btw`

Sarah reads it aloud. She smiles. "See, I told you. Typical Dave."

Marcus pings at 9:31 AM: `morning rush metrics look great. what did you do differently? the API p99 is the best it's been in weeks`

You don't answer Marcus yet. You're writing up the incident post-mortem.

---

### What You Built — Seven Chapters Later

Take a moment. Look at how far you've come since Day 1.

| Chapter | What you learned | What broke |
|---------|-----------------|------------|
| 1 | Containers, images, Docker basics | Dave's API on a server that had the wrong Node version |
| 2 | Dockerfiles, layers, multi-stage builds | A 2GB image that took 10 minutes to deploy |
| 3 | Volumes, persistent storage | A database that forgot everything on restart |
| 4 | Docker networking, user-defined bridges | A frontend that couldn't find its backend |
| 5 | Docker Compose, health checks, secrets | A stack that needed 15 commands to start |
| 6 | Kubernetes, Pods, Deployments, Services | A single host that melted under traffic |
| 7 | Secrets, rolling updates, resource limits, HPA | Everything, all at once, at 6 AM |

You didn't just learn tools. You learned a way of thinking: containers as immutable units, infrastructure as code, self-healing systems, zero-downtime deployments. You learned to read logs like a detective and treat production failures like debugging puzzles.

---

### Where to Go Next

This is not the end. This is the part where the training wheels come off.

**Certifications**

- **CKA (Certified Kubernetes Administrator)** — The industry-standard Kubernetes certification. If you want to work with K8s professionally, this is the one. The exam is hands-on, not multiple choice, which makes it genuinely useful. Study time: 2–4 months depending on your pace.
- **CKAD (Certified Kubernetes Application Developer)** — More developer-focused. Covers many of the same topics as this curriculum. A good entry point if CKA feels too ops-heavy.
- **Docker Certified Associate** — Covers Docker deeply. Good if your work is more container-build than cluster-management.

**Package Management**

- **Helm** — Think of Helm as the `npm` or `pip` of Kubernetes. Instead of managing raw YAML manifests, you work with Charts — parameterized, versioned, shareable packages. The moment you need to deploy the same app to three different environments with different configs, you'll understand why Helm exists.

**GitOps and Continuous Delivery**

- **ArgoCD** — A Kubernetes-native GitOps tool. You declare the desired state in a Git repository, and ArgoCD continuously reconciles the cluster to match. No more `kubectl apply` from your laptop. Changes go through Git, get reviewed, and ArgoCD deploys them. It's the difference between "I applied it by hand" and "the cluster deploying itself."
- **Flux** — Another GitOps option, lighter-weight than ArgoCD. Worth understanding both exist.

**Observability**

- **Prometheus** — The standard metrics collection system for Kubernetes. It scrapes metrics from your pods and stores time-series data. The HPA you configured in Challenge 3 can use custom Prometheus metrics, not just CPU.
- **Grafana** — The visualization layer on top of Prometheus. Build dashboards showing request rates, error rates, latency percentiles, pod restart counts. This is what the "green dashboard" you've been watching actually is under the hood.
- **OpenTelemetry** — The emerging standard for distributed tracing. When a request touches five microservices before returning a response, tracing shows you exactly where the time went.

**Security**

- **OPA / Gatekeeper** — Policy enforcement for Kubernetes. Prevent anyone from deploying images without resource limits, or from running containers as root, or from pulling from unapproved registries. The `latest` tag incident from today's chaos? Gatekeeper can make that physically impossible.
- **External Secrets Operator** — What you learned about Secrets today is just the beginning. In real production, secrets live in HashiCorp Vault, AWS Secrets Manager, or GCP Secret Manager. The External Secrets Operator syncs them into Kubernetes Secrets automatically, without anyone touching YAML.
- **Falco** — Runtime security monitoring. Gets alerts when a process inside a container does something unexpected, like reading `/etc/passwd` or making an outbound network connection it shouldn't.

**The Honest Next Step**

Build something real. Take a project you actually care about, containerize it properly, deploy it to a real Kubernetes cluster (EKS on AWS, GKE on GCP, or AKS on Azure all have free tiers), wire up Prometheus and Grafana, set up ArgoCD, and break it on purpose. The production incident you just handled in Chapter 7 is the best learning that exists — do it deliberately, in a safe environment, until the chaos stops feeling like chaos.

---

*Sarah's parting words:*

"The thing I never told you about the Great Database Incident of 2024? I was the one who caused it. I thought I knew enough to skip the post-mortem. I didn't write down what broke or why. Three months later the same thing happened again, and I had no notes, no runbook, nothing.

Write the post-mortem. Always write the post-mortem.

Welcome to the team — for real this time."
