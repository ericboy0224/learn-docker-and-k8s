# Challenge 3: Autoscaling

> **Sarah:** "The morning rush just started. We fixed the broken pods, we deployed cleanly. Now I want to show you the last piece: what happens when traffic actually spikes. We're going to configure the Horizontal Pod Autoscaler, then throw load at it and watch Kubernetes do the thing Dave always wanted to do manually — scale up."

---

## The Situation

The `learn-frontend` Deployment is running at 2 replicas after the update in Challenge 2. Right now traffic is quiet. But Marcus just forwarded a notification: the NoCappuccino kiosk at Heathrow airport (where Dave got his coffee) went viral on social media. Traffic is about to spike.

You need to configure autoscaling so that Kubernetes handles the spike automatically, without anyone having to SSH into anything or change a replica count by hand.

---

## Prerequisites

This challenge requires the Kubernetes Metrics Server to be installed in your cluster. Check if it is running:

```bash
kubectl get deployment metrics-server -n kube-system
```

If it is not found, install it for kind clusters:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# kind clusters need this additional flag to skip TLS verification
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Wait for it to be ready
kubectl rollout status deployment/metrics-server -n kube-system
```

Verify it is working:

```bash
kubectl top nodes
kubectl top pods -n learn-ch07
```

If `kubectl top` returns data, Metrics Server is working. If it returns `error: Metrics API not available`, wait 60 seconds and try again — it takes a moment to collect its first samples.

---

## Setup

Ensure your `learn-frontend` Deployment has CPU requests set (required for HPA to function) and is running 2 replicas:

```bash
kubectl get deployment learn-frontend -n learn-ch07 -o yaml | grep -A 6 resources
```

You should see `requests.cpu` defined. If the Deployment from Challenge 2 is still running, it already has this. If you need to reset:

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-frontend
  namespace: learn-ch07
spec:
  replicas: 2
  selector:
    matchLabels:
      app: learn-frontend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: learn-frontend
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
EOF
```

---

## Your Mission

**Part 1: Configure the HPA**

Create a Horizontal Pod Autoscaler for the `learn-frontend` Deployment with these requirements:

- Minimum replicas: `2`
- Maximum replicas: `10`
- Scale up when average CPU utilization exceeds `50%`

After creating it, verify it is attached and working:

```bash
kubectl get hpa -n learn-ch07
```

The `TARGETS` column should show a percentage (e.g., `5%/50%`). If it shows `<unknown>/50%`, wait 30–60 seconds for the Metrics Server to gather its first reading.

---

**Part 2: Simulate Load and Watch it Scale**

Run a load generator that floods the frontend with requests. Open a second terminal:

```bash
# Start a port-forward to the frontend service
kubectl port-forward service/learn-frontend 8089:80 -n learn-ch07 &

# Run the load generator — this sends continuous requests for 3 minutes
echo "Generating load for 3 minutes..."
end=$((SECONDS + 180))
while [ $SECONDS -lt $end ]; do
  curl -s -o /dev/null http://localhost:8089 &
done
wait
echo "Load test complete."
```

While the load generator is running, in your primary terminal watch what happens:

```bash
# Watch HPA decisions in real time
kubectl get hpa learn-frontend-hpa -n learn-ch07 -w

# Watch pods scale up
kubectl get pods -n learn-ch07 -w
```

You should see:
1. CPU utilization in the HPA climb above 50%
2. The HPA `REPLICAS` column increase (2 → 4 → more, depending on load)
3. New pods appear in `kubectl get pods` and reach `Running` state
4. After the load generator stops, utilization drop
5. After the scale-down delay (~5 minutes), replica count decrease back toward the minimum

---

**Part 3: Read the Scaling Events**

After the HPA has made at least one scaling decision:

```bash
kubectl describe hpa learn-frontend-hpa -n learn-ch07
```

Look at the `Events` section at the bottom. You will see entries like:

```
Normal  SuccessfulRescale  2m    horizontal-pod-autoscaler
        New size: 5; reason: cpu resource utilization (percentage of request)
        above target
```

This is the HPA's audit log. Every scale-up and scale-down decision is recorded here with the reason.

---

## Hints

<details>
<summary>Hint 1: Creating the HPA</summary>

The fastest way is with `kubectl autoscale`:

```bash
kubectl autoscale deployment learn-frontend \
  --min=2 \
  --max=10 \
  --cpu-percent=50 \
  -n learn-ch07
```

This creates an HPA object named `learn-frontend` (same name as the Deployment by default). Verify it exists:

```bash
kubectl get hpa -n learn-ch07
```

If you prefer YAML, the equivalent object uses `apiVersion: autoscaling/v2`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: learn-frontend-hpa
  namespace: learn-ch07
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: learn-frontend
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

</details>

<details>
<summary>Hint 2: The HPA shows unknown targets or isn't scaling</summary>

Two common causes:

**Metrics Server not ready:** Run `kubectl top pods -n learn-ch07`. If it errors, the Metrics Server is not ready yet. Wait 60 seconds and check again. The Metrics Server takes a moment after installation to start collecting data.

**CPU requests not set:** The HPA calculates utilization as a percentage of the pod's `requests.cpu`. If `requests.cpu` is not set on the container, the HPA cannot compute a percentage and shows `<unknown>` for targets. Confirm your Deployment spec includes `resources.requests.cpu`.

If both of the above look fine and the HPA still shows `<unknown>` after 2 minutes, delete and recreate it:

```bash
kubectl delete hpa learn-frontend-hpa -n learn-ch07
kubectl autoscale deployment learn-frontend --min=2 --max=10 --cpu-percent=50 -n learn-ch07
```

</details>

<details>
<summary>Hint 3: The load generator isn't triggering scaling</summary>

A few things to check:

**Is the load reaching the pods?** Confirm the port-forward is active and the service is reachable: `curl -v http://localhost:8089`. You should get an nginx response.

**Is CPU actually going up?** Watch `kubectl top pods -n learn-ch07` while the load generator runs. The CPU column should be non-zero. If it stays at `0m`, nginx is handling the requests very efficiently and 50% of `50m` (which is 25 millicores) may not be reached.

If the load is not sufficient to trigger scaling, you can temporarily lower the HPA target to 20% and re-test:

```bash
kubectl patch hpa learn-frontend-hpa -n learn-ch07 \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/metrics/0/resource/target/averageUtilization","value":20}]'
```

Or run the load generator more aggressively — add more concurrent loops:

```bash
for i in $(seq 1 10); do
  while true; do curl -s -o /dev/null http://localhost:8089; done &
done
```

Stop them with `kill %1 %2 %3 %4 %5 %6 %7 %8 %9 %10` when done.

</details>

---

## Success Criteria

- An HPA named `learn-frontend-hpa` (or `learn-frontend`) exists in `learn-ch07`
- `minReplicas: 2`, `maxReplicas: 10`, target CPU: `50%`
- `kubectl describe hpa` shows at least one `SuccessfulRescale` event in the Events section
- At the peak of load, replica count was higher than the minimum of 2

---

## Verification

```bash
bash curriculum/ch07-k8s-production/challenges/verify.sh
```

Or manually:

```bash
# HPA exists and targets are known
kubectl get hpa -n learn-ch07

# HPA describes scaling events
kubectl describe hpa -n learn-ch07

# Confirm resource limits are set on the Deployment
kubectl get deployment learn-frontend -n learn-ch07 -o yaml | grep -A 8 resources
```

---

> **Sarah:** "You just watched Kubernetes scale a deployment from 2 to however many it needed, automatically, based on real traffic. No humans involved. No SSH, no `kubectl scale` by hand. This is what we mean when we talk about self-managing infrastructure.
>
> When Dave lands, all he'll see is a green dashboard and an HPA sitting quietly at the minimum replica count, waiting for the next spike.
>
> That's the job. You're ready for it."

**Final step:** Run the chapter verify script, then read the [Graduation section in the README](../README.md#graduation).
