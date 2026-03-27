---
name: progress
description: Show the player's current progress in Learn Docker & K8s. Displays completed chapters, current position, and overall stats. Use when the user asks "where am I", "what have I done", "show progress", or "status".
---

# Show Player Progress

Read `.player/progress.yaml` and present it in a clear, visual format.

## Display Format

```
=== NoCappuccino DevOps Journey ===

Chapter 1: It Works on My Machine (Containers)     [COMPLETED]
  Lessons: 3/3  |  Challenges: 3/3

Chapter 2: The 2GB Espresso (Image Optimization)    [COMPLETED]
  Lessons: 3/3  |  Challenges: 3/3

Chapter 3: The Vanishing Beans (Persistence)         [IN PROGRESS] <-- You are here
  Lessons: 2/3  |  Challenges: 1/3
  Next up: Lesson 3 - Volume Lifecycle

Chapter 4: The Silent Grinder (Networking)           [NOT STARTED]
Chapter 5: The Symphony of Steam (Docker Compose)    [NOT STARTED]
Chapter 6: The Giant Roaster (K8s Introduction)      [NOT STARTED]
Chapter 7: The Great Latte Leak (K8s Production)     [NOT STARTED]

Started: 2026-03-26  |  Environment: Docker 27.5.1 on macOS
```

## Also check for:

- Leftover Docker resources (show count if any exist)
- Skipped chapters (show quiz scores)
- How long they've been playing (from started_at)

## After showing progress:

Ask what they want to do:
- Continue where they left off
- Replay a completed chapter
- Jump to a different chapter
- Clean up resources

Keep it encouraging — celebrate what they've accomplished!
