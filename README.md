Simple end-to-end example: tiny Go API, Vue 3 frontend, Docker images, Helm chart (with CRD) ready for a local Kubernetes (kind/minikube).

## Structure
- `api/`: Go HTTP server (`/api/greet`, `/healthz`) + Dockerfile.
- `web/`: Vue 3 + Vite frontend that calls `/api/greet` + Dockerfile.
- `deploy/`: Helm chart for API + frontend + ingress + CRD and sample resource.

## Build locally
1. API image
   ```bash
   cd api
   docker build -t k8s-example-api:dev .
   ```
2. Frontend image
   ```bash
   cd web
   npm install
   npm run build
   docker build -t k8s-example-web:dev .
   ```

## Create a local cluster
Example with kind:
```bash
kind create cluster --name k8s-example
kubectl cluster-info --context kind-k8s-example
```

Load the images into the cluster (kind):
```bash
kind load docker-image k8s-example-api:dev --name k8s-example
kind load docker-image k8s-example-web:dev --name k8s-example
```

## Install with Helm
1. Ensure an ingress controller (e.g. nginx-ingress) is installed.
2. Install the chart:
   ```bash
   helm install k8s-example ./deploy \
     --set api.image=k8s-example-api:dev \
     --set web.image=k8s-example-web:dev \
     --set ingress.enabled=true \
     --set ingress.className=nginx
   ```
3. Port-forward the ingress controller service (swap `8080` with any free local port):
   ```bash
   kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8080:80
   ```
   Then browse http://localhost:8080 (or 127.0.0.1). `/api/greet` should respond from the Go API and the Vue page should render. You only need to set `ingress.host` if you want to force matching a specific Host header.

## CRD
The chart ships a simple CRD `Greeting` (group `example.com`). A sample custom resource is templated so you can verify CRDs are installed:
```bash
kubectl get crd
kubectl get greetings.example.com
```

## Local dev without Kubernetes
- API: `cd api && go run main.go` (serves on :8080)
- Frontend: `cd web && npm install && npm run dev` (Vite proxies `/api` to `http://localhost:8080`).

## Cleanup
```bash
helm uninstall k8s-example
kind delete cluster --name k8s-example
```
