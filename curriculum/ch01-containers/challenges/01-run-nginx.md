# Challenge 01: Run Nginx

*Sarah speaking:* Okay, enough theory. Dave's API is a Node app, but before we containerize that, let's warm up with something simpler. Nginx is a battle-tested web server and one of the most-pulled images on Docker Hub. Your first challenge is to get it running on your machine.

---

## The Situation

It's your first hour at NoCappuccino. I've shown you the basics. Now I want to see you actually do it.

Run an Nginx container so that visiting `http://localhost:8080` in your browser (or `curl http://localhost:8080` in your terminal) returns the Nginx welcome page.

---

## Requirements

Your running container **must**:

1. Use the official `nginx` image from Docker Hub
2. Be named `learn-ch01-nginx`
3. Be accessible at `http://localhost:8080` on the host
4. Be running in detached mode (not blocking your terminal)
5. Have both labels applied:
   - `--label app=learn-docker-k8s`
   - `--label chapter=ch01`

---

## Success Criteria

Run the verification script when you think you've got it:

```bash
bash curriculum/ch01-containers/challenges/verify.sh
```

Or manually verify:

```bash
curl -s http://localhost:8080 | grep "Welcome to nginx"
```

You should see the nginx welcome HTML response.

---

## Hints

Only peek if you're stuck. Try for at least 5–10 minutes first — the struggle is where the learning happens.

<details>
<summary>Hint 1 — General direction</summary>

The `docker run` command is what you need. Think about which flags control the container name, the port binding, and whether it runs in the background.

</details>

<details>
<summary>Hint 2 — Which flags to use</summary>

You'll need four flags:
- `-d` to run in detached mode
- `--name` to set the container name
- `-p` to map a host port to the container port (nginx listens on port 80 inside the container)
- `--label` (twice) for the labels

Look up the format of `-p` in Lesson 03 if you're unsure.

</details>

<details>
<summary>Hint 3 — Command structure</summary>

Your command will follow this pattern:

```
docker run [flags] [image-name]
```

The port mapping format is `-p HOST_PORT:CONTAINER_PORT`. nginx serves content on port 80 inside the container. You want it accessible on port 8080 on your host.

You're very close — try putting it together.

</details>

---

## Cleanup

Once you've completed all three challenges and run `verify.sh`, you can clean up with:

```bash
docker stop learn-ch01-nginx && docker rm learn-ch01-nginx
```

Or run the global cleanup script:
```bash
bash engine/cleanup.sh
```
