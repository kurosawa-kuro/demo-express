# === 設定 ===
CLUSTER_NAME := kind
ECR_REGISTRY := 503561449641.dkr.ecr.ap-northeast-1.amazonaws.com
IMAGE_NAME := k8s-api-sample
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
	sed -i "s/\$$ECR_TOKEN/$$ECR_TOKEN/g" kind-cluster.yaml && \
	kind create cluster --config kind-cluster.yaml

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
		--selector=app.kubernetes.io/component=controller

# === アプリケーションデプロイ ===
deploy:
	kubectl apply -f k8s/deployment.yaml
	kubectl apply -f k8s/service.yaml
	kubectl apply -f k8s/ingress.yaml
	kubectl wait --for=condition=Available deployment/k8s-api-sample

delete-app:
	kubectl delete -f k8s/ingress.yaml
	kubectl delete -f k8s/service.yaml
	kubectl delete -f k8s/deployment.yaml

# === デバッグ・状態確認 ===
status:
	@echo "=== Pods ==="
	kubectl get pods
	@echo "\n=== Services ==="
	kubectl get services
	@echo "\n=== Ingress ==="
	kubectl get ingress
	@echo "\n=== Deployments ==="
	kubectl get deployments

logs:
	kubectl logs -l app=k8s-api-sample

describe:
	kubectl describe pod -l app=k8s-api-sample

# === クリーンアップ ===
clean: delete-app delete-cluster
	rm -f kind-cluster.yaml

# === ヘルプ ===
help:
	@echo "利用可能なコマンド:"
	@echo "  make build          - Dockerイメージをビルド"
	@echo "  make push          - ECRにイメージをプッシュ"
	@echo "  make create-cluster - Kindクラスタを作成"
	@echo "  make delete-cluster - Kindクラスタを削除"
	@echo "  make setup-ingress  - Ingressをセットアップ"
	@echo "  make deploy        - アプリケーションをデプロイ"
	@echo "  make delete-app    - アプリケーションを削除"
	@echo "  make status        - クラスタの状態を表示"
	@echo "  make logs          - アプリケーションのログを表示"
	@echo "  make describe      - ポッドの詳細を表示"
	@echo "  make clean         - すべてのリソースを削除"
	@echo "  make help          - このヘルプを表示"
