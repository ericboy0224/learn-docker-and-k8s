# NoCappuccino Narrative Storyline

Welcome to the team at **NoCappuccino**! I’m Sarah, your senior dev. I’ve seen enough "it works on my machine" shrugs to last a lifetime, so we’re moving everything to containers. Grab a dark roast, and let’s get this startup airborne.

### Chapter 1: The "It Works on My Machine" Curse
**The Story:** Our anxious CTO, Dave, is sweating through his "I ❤️ Java" shirt. The "Aroma-Discovery" API works for him, but when we tried to move it to staging, it crashed because the server had the wrong version of Node. Dave’s solution? "Just install the library on the server!" No, Dave. We use Docker now.
**The Stakes:** If the API isn't up by lunch, our first 500 coffee subscribers get a 404 instead of their caffeine fix.
**The Challenge:** Your first mission is to wrap that "broken" app in a container. You need to pull a base image, run it, and make sure it’s accessible on your laptop.
**The Lessons:** 
*   **Basics:** Using `docker pull` to grab images and `docker run -p 8080:80` to bridge that gap between the container’s isolated world and our host.
*   **Linux:** Understanding **Namespaces**—the invisible walls that keep Dave’s messy local environment from ruining our production server.

### Chapter 2: The 2GB Espresso (Image Optimization)
**The Story:** We containerized the app! But Marcus, our PM, is furious because the "Bean-Tracker" image is 2GB. Deploys take 10 minutes, and our cloud bill looks like we’re buying a gold-plated espresso machine every week.
**The Stakes:** The staging server is out of disk space. One more "bloated" deploy and the whole site goes dark.
**The Challenge:** You need to refactor the Dockerfile. Get rid of the build tools and use a slim base like **Alpine**.
**The Lessons:**
*   **Best Practices:** **Multi-stage builds** to leave the heavy compilers behind and **.dockerignore** to stop sending your 1GB `node_modules` to the Docker daemon.
*   **Linux:** **Union Filesystems**—understanding that every line in your Dockerfile is a new layer, and if you aren't careful, those layers stack up faster than empty coffee cups.

### Chapter 3: The Vanishing Beans (Persistence)
**The Story:** We finally have a fast app, but a customer support ticket just came in: "I added a new specialty roast to my favorites, but when the server restarted, it was gone!" Dave forgot that containers are **ephemeral**.
**The Stakes:** If we lose customer data one more time, Marcus says he's switching to a tea subscription startup.
**The Challenge:** You need to fix the database container so the data survives a restart. It's time to learn about **Volumes**.
**The Lessons:**
*   **Persistence:** Using **Named Volumes** for production data and **Bind Mounts** for local development so your code changes show up instantly.
*   **Mistake to Avoid:** Never store database records in the container’s writable layer—that’s a one-way ticket to a "Sad Server".

### Chapter 4: The Silent Grinder (Networking)
**The Story:** Demo Day is in two hours! The frontend is running, and the database is persisting, but they can't see each other. The frontend keeps throwing a "Host not found" error because it's trying to talk to the database on the **default bridge**.
**The Stakes:** If the demo fails, our lead investor (who only drinks decaf) will pull the funding.
**The Challenge:** Bridge the gap. You need to move these containers into a **User-Defined Bridge** so they can find each other by name.
**The Lessons:**
*   **Networking:** Internal **DNS Resolution** and the "magic" of `docker network create`. You’ll also learn why you should bind to `0.0.0.0` instead of `127.0.0.1` inside a container.
*   **Troubleshooting:** Using `docker network inspect` to see who's actually on the network and `curl` to test connectivity from the inside.

### Chapter 5: The Symphony of Steam (Docker Compose)
**The Story:** NoCappuccino is growing. We now have a Frontend, a Backend, a Redis cache, and a Mail-Service. Sarah is tired of typing 15 `docker run` commands in the right order. Dave wants a single "on" button for the whole it infrastructure.
**The Stakes:** Every time a new dev joins, it takes them three days just to set up their environment. We need a "Docker Big Bang" command.
**The Challenge:** Create a `docker-compose.yml` that handles the whole stack, secrets, and startup order.
**The Lessons:**
*   **Orchestration:** Using `depends_on` and **Health Checks** to solve the "Startup Race" where the app crashes because the DB isn't ready yet.
*   **Security:** Moving our DB passwords out of the YAML and into `.env` files or Docker Secrets.

### Chapter 6: The Giant Roaster (Scaling with K8s)
**The Story:** A massive coffee influencer just tweeted about us. Our single Docker host just hit 100% CPU and was **OOMKilled**. It’s time to call in the "Helmsman"—Kubernetes.
**The Stakes:** We have 50,000 people trying to buy "Nitro-Cold-Brew" at once. If we don't scale, the app will melt into a puddle of digital sludge.
**The Challenge:** Take our Docker Compose logic and translate it into Kubernetes **Deployments** and **Services**.
**The Lessons:**
*   **K8s Intro:** The difference between a **Node** (the machine) and a **Pod** (the whale pod). You’ll watch K8s "self-heal" by deleting a Pod and seeing a new one take its place.
*   **Traffic:** Setting up a **LoadBalancer** or **Ingress** so the whole world can reach us without typing in raw IP addresses.

### Chapter 7: The Great Latte Leak (Production Chaos)
**The Story:** It’s the "Chaos Finale". Everything is going wrong at once: someone pushed an image with the `latest` tag and it broke the API, a rogue process is eating all the memory, and our database credentials were found in a public Docker log.
**The Stakes:** The site is down, the CTO is on a flight with no Wi-Fi, and it’s up to you to save NoCappuccino before the morning rush.
**The Challenge:** Triage the disaster. Use `kubectl logs`, `describe`, and `exec` to find the mismatched labels, fix the **ImagePullBackOff**, and set **Resource Limits** to stop the memory leak.
**The Lessons:**
*   **Advanced Ops:** **Rolling Updates** for zero-downtime fixes, **RBAC** to lock down the cluster, and interpreting **Exit Code 137** to realize you need more RAM.
*   **Hardening:** Realizing that "the more you break Docker in testing, the less it'll break you in production".