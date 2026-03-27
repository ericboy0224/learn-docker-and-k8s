```
  _                        ___          _             __       _  _____
 | |   ___ __ _ _ _ _ _   |   \ ___  __| |_____ _ _  / _|___  | |/ ( _ )___
 | |__/ -_) _` | '_| ' \  | |) / _ \/ _| / / -_) '_| > _|_ _| | ' </ _ (_-<
 |____\___\__,_|_| |_||_| |___/\___/\__|_\_\___|_|   \_____|  |_|\_\___/__/

                 an interactive AI-driven learning game 🐳 ⎈
```

> *No web app. No video courses.*
> *Just you, your AI editor, a terminal, and mass amounts of coffee.* ☕

An open-source, interactive learning game where your AI becomes a friendly mentor
and walks you through real-world DevOps scenarios — from "what's a container?"
all the way to triaging a Kubernetes production incident at 3 AM.

---

## How It Works

```
  You                     AI Editor                  Your Terminal
  ---                     ---------                  -------------

  "let's play"  ------>   reads game files   -----> checks Docker
                          becomes Sarah ☕           is installed
                          (your mentor)
                                |
                                v
                          "Welcome to NoCappuccino!
                           Dave broke staging
                           again. Let's fix it
                           with containers..."
                                |
                                v
                          lessons --> challenges --> verify --> next chapter
```

1. Clone this repo
2. Open it in any AI editor ([Claude Code](https://claude.ai/code), [Cursor](https://cursor.com), [Windsurf](https://windsurf.com), [Copilot](https://github.com/features/copilot), [Cline](https://cline.bot), [Codex](https://openai.com/index/codex-cli), [Gemini CLI](https://github.com/google-gemini/gemini-cli), etc.)
3. Type **"let's play"**
4. Learn by doing

---

## The Cast

```
  .-----------------------------------------------------------.
  |                                                           |
  |  (^_^) Sarah       (@_@;) Dave       (-_-) Marcus         |
  |  Senior DevOps     CTO               Product Mgr          |
  |  Your mentor       "Just restart it"  "Demo is at 3"      |
  |                                                           |
  |               NoCappuccino Inc.                           |
  |            "Coffee, code, containers"                     |
  |                                                           |
  '-----------------------------------------------------------'
```

You just joined **NoCappuccino**, a fast-growing coffee subscription startup where
things are... a bit chaotic. Sarah, your senior DevOps engineer, will guide you
through the mess. Dave (the CTO) keeps breaking things. Marcus (the PM) keeps
setting deadlines. The coffee machine breaks as often as production.

---

## The Journey

```
  Ch1              Ch2              Ch3              Ch4
  .-------.       .-------.       .-------.       .-------.
  | [box] | ----> | [img] | ----> | [hdd] | ----> | [net] |
  '-------'       '-------'       '-------'       '-------'
   Containers      Images          Storage         Networks
   "It Works on    "The 2GB        "The Vanishing  "The Silent
    My Machine"     Espresso"       Beans"          Grinder"

  Ch5              Ch6              Ch7
  .-------.       .-------.       .-------.
  | [yml] | ----> | [k8s] | ----> | [!!!] |  ~ GRADUATION ~
  '-------'       '-------'       '-------'
   Compose         Kubernetes      Production
   "The Symphony   "The Giant      "The Great
    of Steam"       Roaster"       Latte Leak"
```

| Ch | Title | Scenario | You'll Learn |
|----|-------|----------|-------------|
| Ch | Title | Scenario | You'll Learn |
|----|-------|----------|-------------|
| 1 | 📦 **It Works on My Machine** | Dave's API crashes on staging | containers, images, port mapping |
| 2 | 🏋️ **The 2GB Espresso** | Image is 2GB, deploys take forever | multi-stage builds, layer caching, .dockerignore |
| 3 | 💾 **The Vanishing Beans** | Customer data gone after restart | volumes, bind mounts, persistence |
| 4 | 🔌 **The Silent Grinder** | Demo in 2 hrs, services can't talk | DNS, bridge networks, isolation |
| 5 | 🎼 **The Symphony of Steam** | New devs take 3 days to set up | Docker Compose, health checks, secrets |
| 6 | ⎈ **The Giant Roaster** | Influencer tweet melts the server | Pods, Deployments, Services, self-healing |
| 7 | 🔥 **The Great Latte Leak** | 3 things broke, CTO on a flight | rolling updates, Secrets, HPA, chaos triage |

Along the way you'll naturally pick up **Linux fundamentals** (namespaces, cgroups, filesystem mounts) and **networking concepts** (DNS, NAT, subnets, iptables) — without ever sitting through a networking lecture.

---

## Getting Started

### Prerequisites

```
  .------------------------------------------------.
  |  Required                Optional (Ch 6-7)     |
  |  --------                ------------------    |
  |  [x] Docker              [ ] kubectl           |
  |  [x] Docker Compose v2   [ ] kind              |
  |  [x] AI editor                                 |
  |      (Claude Code, Cursor,                     |
  |       Windsurf, Copilot, Cline,                |
  |       Codex CLI, Gemini CLI, etc.)             |
  '------------------------------------------------'
```

### Quick Start

```bash
git clone https://github.com/ericboy0224/learn-docker-and-k8s.git
cd learn-docker-and-k8s
```

Then open it in your AI editor and type: **"let's play"**

That's it. The AI handles everything else.

---

## Commands

```
  .------------------------------------------------.
  |                                                |
  |  /play          start or resume the game       |
  |  /env-check     verify your setup              |
  |  /progress      see how far you've come        |
  |  /hint          get a nudge (3 levels)         |
  |  /verify        check your challenge solution  |
  |  /next          move to next lesson/challenge  |
  |  /skip-to 4     jump ahead (with quiz)         |
  |  /cleanup       remove game Docker resources   |
  |                                                |
  |  ...or just talk naturally:                    |
  |  "I'm stuck"  "check my work"  "what's next"  |
  |                                                |
  '------------------------------------------------'
```

---

## What Makes This Different

```
  Traditional Course            This Project
  ------------------            ------------

  📺 Watch a video              🎮 Play a game
  📝 Follow step-by-step        🔍 Investigate & fix
  😴 Passive consumption        💪 Active problem-solving
  🏫 Classroom setting          🏢 Simulated real job
  📖 Isolated concepts          🔗 Everything connects
  🤖 Generic examples           ☕ Coffee startup story
```

- 🧠 **AI as game engine** — The prompt files ARE the game code. No server needed.
- 📖 **Story-driven** — Characters, stakes, humor. Dave will break things.
- 🖥️ **Real environments** — Actual Docker & K8s on your machine.
- 🔒 **Challenge mode** — The AI won't give answers, only progressive hints.
- 🔗 **Cross-learning** — Docker teaches you Linux & networking for free.
- 🛡️ **Safe sandbox** — All resources use `learn-` prefix. Easy cleanup. No host damage.

---

## Project Structure

```
  .
  |-- AGENTS.md                <-- AI reads this first (universal)
  |-- CLAUDE.md                <-- Claude Code entry point + skills
  |-- GEMINI.md                <-- Gemini CLI entry point
  |-- .cursorrules             <-- Cursor entry point
  |-- .clinerules              <-- Cline / Roo Code entry point
  |-- .windsurfrules           <-- Windsurf entry point
  |-- .github/
  |   '-- copilot-instructions.md  <-- GitHub Copilot entry point
  |
  |-- .claude/skills/          <-- game commands (Claude Code)
  |   |-- play/                    /play
  |   |-- hint/                    /hint
  |   |-- verify/                  /verify
  |   '-- ...                      and more
  |
  |-- engine/                  <-- game engine
  |   |-- rules.md                 teaching vs challenge mode
  |   |-- narrator.md              story, characters, tone
  |   |-- validation.md            how to verify challenges
  |   |-- environment-check.sh     pre-flight check
  |   '-- cleanup.sh               remove all learn-* resources
  |
  |-- curriculum/              <-- 7 chapters
  |   |-- ch01-containers/
  |   |   |-- README.md            chapter story + objectives
  |   |   |-- lessons/             teaching content (3 per ch)
  |   |   |-- challenges/          hands-on + verify.sh
  |   |   '-- quiz.md              skip-level assessment
  |   |-- ch02-image-optimization/
  |   |-- ch03-persistence/
  |   |-- ch04-networking/
  |   |-- ch05-compose/
  |   |-- ch06-k8s-intro/
  |   '-- ch07-k8s-production/
  |
  '-- .player/
      '-- progress.yaml        <-- your save file (AI-managed)
```

---

## Contributing

This is an open-source project. Contributions welcome!

```
  Ways to contribute:

  📝 New challenges     Add challenges to existing chapters
  📚 New chapters       Extend beyond K8s (Helm, ArgoCD, monitoring)
  🌍 Translations       Translate content (keep technical terms in English)
  🐛 Bug fixes          Fix verify.sh scripts or instructions
  🔌 Platform support   Add entry points for other AI editors
  🎨 ASCII art          Make the experience more delightful
```

---

## Author

Created by [**Eric**](https://github.com/ericboy0224) — built with curiosity, coffee, and Claude. ☕🐳

If this project helped you learn something, give it a ⭐ and share it with someone starting their DevOps journey.

## License

MIT

---

```
  _  _      ___                           _
 | \| |___ / __|__ _ _ __ _ __ _  _ __ __(_)_ _  ___
 | .` / _ \ (__/ _` | '_ \ '_ \ || / _/ _| | ' \/ _ \
 |_|\_\___/\___\__,_| .__/ .__/\_,_\__\__|_|_||_\___/
                     |_|  |_|

              Keep calm and containerize.
                  Happy learning! - Sarah
```
