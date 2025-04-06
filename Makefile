# === 設定 ===
CLUSTER_NAME := kind
ECR_REGISTRY := 503561449641.dkr.ecr.ap-northeast-1.amazonaws.com
IMAGE_NAME := demo-express
ECR_IMAGE := 503561449641.dkr.ecr.ap-northeast-1.amazonaws.com/k8s-api-sample:latest
AWS_REGION := ap-northeast-1

# === Express アプリ ===
build:
	docker build -t $(IMAGE_NAME):latest .

push:
	docker tag $(IMAGE_NAME):latest $(ECR_IMAGE)
	aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin $(ECR_REGISTRY)
	docker push $(ECR_IMAGE)

# === kind クラスタ ===
create-cluster:
	@echo "Creating kind cluster..."
	ECR_TOKEN=$$(aws ecr get-login-password --region $(AWS_REGION)) && \
	cat <<EOF > kind-cluster.yaml && \
kind create cluster --config kind-cluster.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.auths."$(ECR_REGISTRY)"]
        username = "AWS"
        password = "$$ECR_TOKEN"
EOF

delete-cluster:
	kind delete cluster --name $(CLUSTER_NAME)

stop-cluster:
	docker stop $(CLUSTER_NAME)-control-plane

start-cluster:
	docker start $(CLUSTER_NAME)-control-plane

# === Ingress + K8s マニフェスト適用 ===
setup-ingress:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.5/deploy/static/provider/kind/deploy.yaml
	kubectl label node $(CLUSTER_NAME)-control-plane ingress-ready=true
	kubectl wait --namespace ingress-nginx \
		--for=condition=Ready pod \
		--selector=app.kubernetes
