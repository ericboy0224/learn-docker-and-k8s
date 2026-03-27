# Challenge 2: Service Discovery

## Briefing

NoCappuccino's app has a frontend and a backend. They run as separate containers. In Docker Compose, they found each other by service name on a shared network. In Kubernetes, the mechanism is different — but the idea is the same.

Pods can't rely on IPs (they change), so we use Services. A Service gives the backend a stable DNS name that the frontend can always reach, regardless of how many backend Pods are running or which IPs they have at any given moment.

Your mission: deploy both frontend and backend as Deployments, create a ClusterIP Service for the backend, and prove that the frontend can reach the backend by Service name.

---

## Objective

Deploy a frontend and backend as separate Deployments in the `learn-ch06` namespace. Create a ClusterIP Service for the backend. Verify that a frontend Pod can successfully `curl` the backend using the Service name `backend-svc`.

---

## Starting Point

These manifests give you the basic structure. Save them and fill in the gaps — you'll need to wire up the Service selector and figure out how to verify connectivity.

**`backend-deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-backend
  namespace: learn-ch06
  labels:
    app: backend
    chapter: ch06
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        chapter: ch06
    spec:
      containers:
        - name: backend
          image: hashicorp/http-echo:latest
          args:
            - "-text=Hello from NoCappuccino backend!"
            - "-listen=:5678"
          ports:
            - containerPort: 5678
          resources:
            requests:
              memory: "16Mi"
              cpu: "25m"
            limits:
              memory: "32Mi"
              cpu: "50m"
```

**`backend-service.yaml`**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: learn-ch06
  labels:
    app: backend
    chapter: ch06
spec:
  type: ClusterIP
  selector:
    # TODO: Which label should this selector match?
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5678
```

**`frontend-deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-frontend
  namespace: learn-ch06
  labels:
    app: frontend
    chapter: ch06
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        chapter: ch06
    spec:
      containers:
        - name: frontend
          image: curlimages/curl:latest
          command: ["sleep", "3600"]
          resources:
            requests:
              memory: "16Mi"
              cpu: "25m"
            limits:
              memory: "32Mi"
              cpu: "50m"
```

The frontend uses `curlimages/curl` with a `sleep` command so it stays running — giving you a container you can exec into and test connectivity from.

---

## Your Tasks

1. Fix the `backend-service.yaml` — the selector needs to match the backend Pod labels
2. Apply all three manifests to the cluster
3. Wait for all Pods to be `Running`
4. Check the Service's Endpoints to confirm it has backend Pod IPs
5. Exec into the frontend Pod and `curl` the backend using the Service name
6. You should see the response: `Hello from NoCappuccino backend!`

---

## Success Criteria

The `challenges/verify.sh` script will check:

- [ ] Deployment `learn-backend` is present with at least 1 ready replica
- [ ] Service `backend-svc` exists in `learn-ch06`
- [ ] Service `backend-svc` has at least one Endpoint (Pod IP) configured
- [ ] A curl from within the cluster to `http://backend-svc` returns a successful response

---

## Hints

<details>
<summary>Hint 1 — General direction</summary>

The Service's `selector` field tells it which Pods to route traffic to. Look at the labels defined in the backend Deployment's `spec.template.metadata.labels` — the Service selector needs to match at least one of those key-value pairs. Mismatched labels are the most common reason a Service has no Endpoints.
</details>

<details>
<summary>Hint 2 — Verifying the Service is working</summary>

Before testing with curl, check if the Service has any Endpoints. If the Endpoints list is empty (`<none>`), the labels don't match and traffic won't reach any Pod. There's a `kubectl get` subcommand for Endpoints — try it before exec-ing into the frontend Pod.
</details>

<details>
<summary>Hint 3 — Exec and curl</summary>

To run a command inside a running Pod, use `kubectl exec`. You'll need the `-it` flags for interactive mode, the Pod's name, the namespace, and `-- /bin/sh` or `-- curl http://backend-svc` as the command to run. Since all resources are in the same namespace (`learn-ch06`), the short DNS name `backend-svc` will resolve automatically.
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

**What you did:** Created two separate Deployments, then created a Service that uses a label selector to route traffic to backend Pods. The frontend connected to the backend using just the Service name — not an IP address.

**Why it works:** CoreDNS (running in `kube-system`) maintains DNS records for every Service in the cluster. When the frontend Pod resolves `backend-svc`, DNS returns the Service's ClusterIP (a virtual IP). kube-proxy's iptables rules then DNAT (destination NAT) the traffic from the ClusterIP to one of the actual backend Pod IPs. The frontend never knows which Pod it hit.

**Real-world connection:** This is exactly how microservices communicate in production Kubernetes deployments. The frontend calls `http://user-service`, `http://payment-service`, `http://catalog-service` — stable names that don't change when Pods are rescheduled, scaled, or updated.

**Interview angle:** "How does service discovery work in Kubernetes?" — The expected answer covers Services, ClusterIPs, label selectors, CoreDNS, and the search domain configuration in Pod DNS. Bonus points for mentioning Endpoints objects.

**Pro tip:** The DNS name `backend-svc` only works from the same namespace. To call across namespaces, use `backend-svc.learn-ch06` or the full FQDN `backend-svc.learn-ch06.svc.cluster.local`. This namespace scoping is also a security feature — it limits accidental cross-namespace communication.
