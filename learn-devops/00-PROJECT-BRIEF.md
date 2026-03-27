# Learn Docker & K8s: Interactive AI-Driven Learning Game

## Project Vision

An open-source, AI-driven interactive learning game where users learn Docker, Linux, networking, and Kubernetes through realistic work scenarios. The AI (Claude Code, Cursor, etc.) acts as the game engine — reading prompt files as "game code" and guiding users through progressive challenges.

**Key differentiator:** No web app needed. Users clone the repo, open it in their AI editor, and type "let's play" to start.

---

## Core Design Principles

### From K8sQuest & iximiuz (validated patterns)
1. **"Break-Investigate-Fix" loop** — Challenges present broken environments, not blank slates
2. **Requirement-based tasks** — Give goals, not step-by-step instructions
3. **Progressive hints** — Hint 1 (direction) → Hint 2 (specific area) → Hint 3 (near-answer)
4. **Post-mission debriefs** — Explain WHY the fix worked + real-world relevance + interview angle
5. **Safety guards** — Prevent destructive operations on host (all resources use `learn-` prefix)
6. **Automated verification** — `verify.sh` scripts check actual system state

### Teaching Philosophy
- **Teaching mode:** AI demonstrates, explains, and shows output
- **Challenge mode:** AI only gives hints, never runs commands for you
- **Skip-level quizzes:** If jumping ahead, must pass knowledge check on skipped concepts
- **Story-driven:** Every chapter has characters, stakes, and humor (NoCappuccino startup narrative)
- **Technical terms in English:** Even when AI speaks user's language, use English for Docker/K8s/Linux terminology

---

## Architecture

```
learn-docker-and-k8s/
├── CLAUDE.md                    # Entry point (loads engine rules)
├── .cursorrules                 # Cursor entry point (same core rules)
├── .player/
│   └── progress.yaml            # Player state (AI-managed)
├── engine/
│   ├── rules.md                 # Core AI behavior (teaching vs challenge mode)
│   ├── narrator.md              # Tone, characters, story continuity
│   ├── validation.md            # How to verify challenges
│   ├── environment-check.sh     # Pre-flight system check
│   └── cleanup.sh               # Remove all learn-* resources
├── curriculum/
│   ├── ch01-containers/         # "It Works on My Machine"
│   │   ├── README.md            # Chapter overview + story
│   │   ├── lessons/
│   │   │   ├── 01-what-is-docker.md
│   │   │   ├── 02-images-and-containers.md
│   │   │   └── 03-basic-commands.md
│   │   ├── challenges/
│   │   │   ├── 01-run-nginx.md
│   │   │   ├── 02-build-first-image.md
│   │   │   └── verify.sh
│   │   └── quiz.md              # Skip-level assessment
│   ├── ch02-image-optimization/ # "The 2GB Espresso"
│   ├── ch03-persistence/        # "The Vanishing Beans"
│   ├── ch04-networking/         # "The Silent Grinder"
│   ├── ch05-compose/            # "The Symphony of Steam"
│   ├── ch06-k8s-intro/          # "The Giant Roaster"
│   └── ch07-k8s-production/     # "The Great Latte Leak"
└── learn-devops/                # Research materials (this folder)
```

---

## Curriculum: The NoCappuccino Story

Players join **NoCappuccino**, a cloud-based coffee subscription startup, as a new DevOps engineer. Their mentor **Sarah** (senior dev) guides them while navigating **Dave** (anxious CTO) and **Marcus** (demanding PM).

### Chapter 1: "It Works on My Machine" (Container Basics)
**Story:** Dave's API works locally but crashes on staging due to version mismatch.
**Teaches:** What containers are, `docker run`, `docker pull`, port mapping, `docker ps/stop/rm`
**Linux tie-in:** Namespaces, process isolation
**Networking tie-in:** Port mapping = NAT
**Challenges:**
- Run Nginx and access it on localhost:8080
- Build a Node.js app image from a Dockerfile
- Debug: container starts but port is unreachable (forgot `-p`)

### Chapter 2: "The 2GB Espresso" (Image Optimization)
**Story:** The Bean-Tracker image is 2GB, deploys take 10 min, staging is out of disk.
**Teaches:** Dockerfile instructions, multi-stage builds, Alpine base, `.dockerignore`, layer caching
**Linux tie-in:** Union filesystems (OverlayFS), layer concept
**Challenges:**
- Reduce image from 2GB to <100MB using multi-stage build
- Fix stale apt-get cache bug (separate RUN lines)
- Optimize build cache by reordering COPY instructions

### Chapter 3: "The Vanishing Beans" (Persistence)
**Story:** Customer data disappears after container restart — Dave forgot containers are ephemeral.
**Teaches:** Volumes, bind mounts, tmpfs, volume lifecycle
**Linux tie-in:** Filesystem mounts, `/etc/fstab` concept
**Challenges:**
- Mount a named volume to MySQL, prove data survives `docker rm`
- Use bind mount for local dev (hot reload)
- Debug: volume permission denied (UID mismatch)

### Chapter 4: "The Silent Grinder" (Networking)
**Story:** Demo Day in 2 hours — frontend can't find backend ("Host not found" on default bridge).
**Teaches:** Bridge vs user-defined bridge, DNS resolution, port binding, network isolation
**Linux tie-in:** `ip addr`, `iptables`, virtual interfaces (veth pairs)
**Networking tie-in:** DNS, subnets, NAT, TCP/IP basics
**Challenges:**
- Fix "name not resolved" by moving to user-defined bridge
- Debug: app binds to 127.0.0.1 instead of 0.0.0.0
- Create isolated networks (frontend can reach backend, but not database directly)

### Chapter 5: "The Symphony of Steam" (Docker Compose)
**Story:** 4 services, 15 docker run commands — new devs take 3 days to set up. Need a single "on" button.
**Teaches:** docker-compose.yml, depends_on, health checks, .env files, profiles, named networks
**Linux tie-in:** YAML, environment variables, process dependencies
**Challenges:**
- Build full stack: frontend + backend + Redis + Postgres
- Fix startup race condition with health checks
- Move secrets from YAML to .env files
- Add profiles for dev vs test environments

### Chapter 6: "The Giant Roaster" (K8s Introduction)
**Story:** Coffee influencer tweet → 50K concurrent users → single Docker host OOMKilled at 3 AM.
**Teaches:** Pods, Deployments, Services, ReplicaSets, kubectl basics, kind setup
**Linux tie-in:** Process management, cgroups
**Networking tie-in:** Pod networking, ClusterIP, NodePort
**Challenges:**
- Deploy Nginx with 3 replicas, delete a Pod, watch self-healing
- Create a ClusterIP Service to connect frontend to backend
- Debug: CrashLoopBackOff (wrong image tag)

### Chapter 7: "The Great Latte Leak" (K8s Production)
**Story:** Chaos finale — wrong image tag, memory leak, leaked credentials, all at once. CTO is offline.
**Teaches:** Secrets, ConfigMaps, Rolling Updates, Resource Limits, HPA, RBAC basics
**Linux tie-in:** Base64 encoding, resource monitoring
**Networking tie-in:** Ingress, Layer 7 routing, load balancing
**Challenges:**
- Triage 3 simultaneous failures (ImagePullBackOff + OOMKilled + exposed secrets)
- Perform zero-downtime rolling update while running continuous health checks
- Set up resource limits and HPA for auto-scaling

---

## Environment & Resource Management

### Startup Check
On first launch, AI runs `environment-check.sh`:
- Docker installed & running? Version?
- Docker Compose v2 available?
- Sufficient disk space? (>5GB free)
- For K8s chapters: kind installed? kubectl available?
- Port conflicts? (80, 8080, 3000, 5432)

### Resource Naming Convention
All resources use `learn-` prefix + chapter label:
- Containers: `learn-ch01-nginx`, `learn-ch04-frontend`
- Networks: `learn-ch04-app-net`
- Volumes: `learn-ch03-db-data`
- Labels: `app=learn-docker-k8s, chapter=ch01`

### Cleanup Strategy
- Each chapter end: show cleanup command, don't auto-execute
- Session start: check for leftover resources from previous sessions
- Master cleanup: `./engine/cleanup.sh` removes all `learn-*` resources
- Display resource count so user knows what's there

### Progress File
```yaml
player:
  started_at: 2026-03-26
  language: auto  # AI detects from conversation
  environment:
    docker: "27.5.1"
    compose: "2.32.4"
    os: "darwin"
chapters:
  ch01-containers:
    status: completed
    lessons: [01, 02, 03]
    challenges: [01, 02, 03]
    completed_at: 2026-03-26
  ch02-image-optimization:
    status: in-progress
    lessons: [01]
    challenges: []
  ch04-networking:
    status: skipped  # jumped ahead
    skip_quiz_passed: true
    quiz_score: 4/5
```

---

## Reference Materials (in this folder)

| File | Content | Use For |
|------|---------|---------|
| 01-real-world-docker-scenarios.md | Scenarios easy→hard | Challenge inspiration |
| 02-challenge-design-patterns.md | Patterns from K8sQuest, iximiuz, etc. | Game engine design |
| 03-networking-cs-concepts-map.md | Docker feature → CS concept mapping | Cross-teaching design |
| 04-curriculum-outline.md | NotebookLM's curriculum suggestion | Chapter structure |
| 05-common-beginner-mistakes.md | Top mistakes with exact errors | "Spot the bug" challenges |
| 06-dockerfile-patterns-antipatterns.md | Before/after Dockerfile examples | Ch02 challenges |
| 07-essential-linux-commands.md | Linux commands by category | Linux tie-ins per chapter |
| 08-docker-compose-challenges.md | 10 progressive Compose challenges | Ch05 challenges |
| 09-mind-map.json | Concept hierarchy (JSON) | Visual overview |
| 10-study-guide.md | Comprehensive study guide | Overall reference |
| 11-quiz-questions.md | Quiz questions (medium difficulty) | Skip-level assessments |
| 12-flashcards.md | Flashcard set | Quick review between chapters |
| 13-docker-debugging-deep-dive.md | Every debugging technique detailed | Ch01/Ch07 challenges |
| 14-docker-networking-deep-dive.md | Networking concepts exhaustive | Ch04 content |
| 15-k8squest-game-design-analysis.md | K8sQuest design patterns | Engine design reference |
| 16-narrative-storyline.md | NoCappuccino story with characters | Chapter narratives |
| 17-production-scenario-bank.md | Production scenarios with exact errors | Ch07 challenges |

---

## NotebookLM Notebook

**ID:** `b1e6339d-2245-43a4-8ebd-acbc604bd8cc`
**Title:** Learn DevOps - Docker & K8s Interactive Learning Research
**Sources:** 25+ web pages, 5 YouTube videos, 1 deep research report (50 web sources synthesized)
**Artifacts:** Study guide, mind map, quiz, flashcards

Use `python3 -m notebooklm ask "..." --notebook b1e6339d-2245-43a4-8ebd-acbc604bd8cc` to query anytime.
