# Challenge 3: Debug the ImagePullBackOff

## Briefing

Dave did it again.

At 5 AM, still riding the adrenaline of surviving the traffic spike, he decided to "help" by updating the NoCappuccino deployment manifest himself. He typed fast, committed without reviewing, and now the Pods are stuck in `ImagePullBackOff`.

Dave's message came in at 5:12 AM: "Sarah I think I may have broken something small."

It is not small.

Your job: use `kubectl describe` to diagnose what's wrong, find the bug in the manifest, and fix it.

---

## Objective

A Deployment is stuck in `ImagePullBackOff`. Diagnose the root cause using only `kubectl` commands, then fix the manifest and redeploy successfully. Pods should reach `Running` status.

---

## The Broken Manifest

Save this as `broken-deployment.yaml` and apply it:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-cloudbrew
  namespace: learn-ch06
  labels:
    app: cloudbrew
    chapter: ch06
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cloudbrew
  template:
    metadata:
      labels:
        app: cloudbrew
        chapter: ch06
    spec:
      containers:
        - name: cloudbrew-web
          image: ngnix:latest
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
```

Apply it:

```bash
kubectl apply -f broken-deployment.yaml
```

---

## Your Tasks

1. Apply the broken manifest
2. Watch the Pods come up — notice they don't reach `Running`
3. Use `kubectl describe` to identify the problem
4. Fix the manifest
5. Re-apply the fixed manifest
6. Verify all Pods reach `Running` status

You are **not** allowed to look at the manifest's broken line directly — diagnose through kubectl first. (Okay, you might have already spotted it. But practice the diagnostic workflow anyway — you'll need it in production when the bug isn't this obvious.)

---

## Success Criteria

The `challenges/verify.sh` script will check:

- [ ] The Deployment `learn-cloudbrew` exists in `learn-ch06`
- [ ] No Pods in `learn-ch06` are in `CrashLoopBackOff`, `ImagePullBackOff`, or `ErrImagePull` status
- [ ] At least 2 Pods from `learn-cloudbrew` are in `Running` status

---

## Hints

<details>
<summary>Hint 1 — General direction</summary>

The first thing to check when Pods won't start is their status and events. `CrashLoopBackOff` and `ImagePullBackOff` are different symptoms with different causes. Check what status the Pods actually show — the status column tells you where in the startup process things are failing.
</details>

<details>
<summary>Hint 2 — Reading the events</summary>

`kubectl describe pod <pod-name> -n learn-ch06` gives you a detailed view including an Events section at the bottom. The Events section is like a log of everything that happened to the Pod: image pulls, scheduling decisions, probe failures. Look at the most recent events. The error message there usually tells you exactly what went wrong, often including the specific image reference that failed.
</details>

<details>
<summary>Hint 3 — Finding the fix</summary>

The error involves an image reference. Image names in Kubernetes manifests follow the exact same format as Docker: `registry/repository:tag`. If the image name itself is misspelled (not just the tag), Kubernetes will never be able to pull it. Look very carefully at the image field in the container spec — the repository name `ngnix` is not a valid Docker Hub repository. Compare it to the official nginx image name on Docker Hub.
</details>

---

## After You Finish

Run the verification script:

```bash
bash curriculum/ch06-k8s-intro/challenges/verify.sh
```

---

## Post-Mission Debrief

*(Read this after you've solved the challenge.)*

**What you did:** Applied a Deployment with a typo in the image name (`ngnix` instead of `nginx`). Pods couldn't start because kubelet couldn't pull a non-existent image. You diagnosed the failure through `kubectl describe` events, identified the bad image reference, fixed the manifest, and reapplied.

**Why it works (the fix):** The image name `ngnix:latest` doesn't exist on Docker Hub. When kubelet tries to pull it, the registry returns a 404. Kubernetes retries with exponential backoff and reports `ImagePullBackOff`. Fixing the image name to `nginx:latest` resolves the pull error and lets the container start.

**Real-world connection:** ImagePullBackOff is one of the most common issues in production K8s deployments. It happens with: typos (like this one), private registries without pull secrets, images that were deleted from the registry, and rate limiting on Docker Hub. The diagnostic workflow is always the same: `kubectl describe pod` → look at Events → read the image pull error.

**Interview angle:** "Walk me through debugging a Pod stuck in ImagePullBackOff." — The answer covers: `kubectl get pods` to see the status, `kubectl describe pod` to read the Events, identifying the bad image reference, checking if the image exists in the registry, and ensuring registry credentials are configured if it's a private registry.

**Pro tip:** In production, avoid using the `latest` tag. It makes rollbacks harder (you can't tell which version is running) and bypasses caching (kubelet re-pulls `latest` each time). Pin to a specific version like `nginx:1.25.3`. This is one of the reasons the Great Latte Leak (Chapter 7) starts the way it does.
