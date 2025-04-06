# Demo Express Application

Kubernetes上で動作するExpress.jsアプリケーションのデモプロジェクトです。

## 前提条件

- Docker
- kubectl
- kind
- AWS CLI
- make

## プロジェクト構成

```
.
├── Makefile              # ビルド・デプロイ用コマンド
├── k8s/                  # Kubernetesマニフェスト
│   ├── deployment.yaml   # デプロイメント設定
│   ├── service.yaml     # サービス設定
│   └── ingress.yaml     # Ingress設定
└── kind-cluster.yaml    # Kindクラスタ設定
```

## 環境の完全再構築

既存の環境を完全に削除して、新しく作り直す場合：

```bash
# 1. 環境の完全クリーンアップ
make clean

# 2. クラスタが完全に削除されたことを確認
kind get clusters | grep -q kind && echo "クラスタが存在します" || echo "クラスタは削除されています"

# 3. 環境変数の設定
export ECR_REGISTRY=503561449641.dkr.ecr.ap-northeast-1.amazonaws.com

# 4. kind-cluster.yamlの再作成
cat <<EOF > kind-cluster.yaml
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
    [plugins."io.containerd.grpc.v1.cri".registry.auths."${ECR_REGISTRY}"]
      username = "AWS"
      password = "$$ECR_TOKEN"
EOF

# 5. クラスタの作成
make create-cluster

# 6. ECRの認証情報を設定
kubectl create secret docker-registry regcred \
  --docker-server=https://${ECR_REGISTRY} \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region ap-northeast-1)

# 7. アプリケーションのデプロイ（Ingress以外）
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# 8. Ingressのセットアップと待機
make setup-ingress
kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# 9. Ingressの適用
kubectl apply -f k8s/ingress.yaml

# 10. 状態確認
make status

# 11. アプリケーションへのアクセス確認
curl -v http://localhost/posts
```

## セットアップ手順

1. クラスタの作成とIngressのセットアップ
```bash
# クラスタの作成
make create-cluster

# Ingressのセットアップ
make setup-ingress
```

2. アプリケーションのデプロイ
```bash
# アプリケーションのデプロイ
make deploy
```

3. 状態確認
```bash
# クラスタの状態確認
make status

# アプリケーションのログ確認
make logs

# ポッドの詳細確認
make describe
```

## 利用可能なコマンド

### アプリケーション関連
- `make build` - Dockerイメージをビルド
- `make push` - ECRにイメージをプッシュ
- `make deploy` - アプリケーションをデプロイ
- `make delete-app` - アプリケーションを削除

### クラスタ関連
- `make create-cluster` - Kindクラスタを作成
- `make delete-cluster` - Kindクラスタを削除
- `make stop-cluster` - クラスタを停止
- `make start-cluster` - クラスタを起動
- `make setup-ingress` - Ingressをセットアップ

### デバッグ・状態確認
- `make status` - クラスタの状態を表示
- `make logs` - アプリケーションのログを表示
- `make describe` - ポッドの詳細を表示

### クリーンアップ
- `make clean` - すべてのリソースを削除
- `make help` - 利用可能なコマンドの一覧を表示

## アプリケーションへのアクセス

デプロイ後、以下のURLでアプリケーションにアクセスできます：
```
http://localhost
```

## トラブルシューティング

1. イメージのプルに失敗する場合
```bash
# ECRの認証情報を再設定
kubectl create secret docker-registry regcred \
  --docker-server=https://503561449641.dkr.ecr.ap-northeast-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region ap-northeast-1)
```

2. デプロイメントが失敗する場合
```bash
# 状態確認
make status
make describe
make logs
```

## クリーンアップ

環境を完全にクリーンアップする場合：
```bash
make clean
```

## 注意事項

- AWS認証情報が正しく設定されていることを確認してください
- ECRリポジトリが事前に作成されていることを確認してください
- ポート80が利用可能であることを確認してください

## APIテスト

### 🔄 ヘルスチェック
GET http://localhost/
Accept: text/plain

### 📝 投稿一覧取得
GET http://localhost/posts
Accept: application/json

### ✏️ 新規投稿作成
POST http://localhost/posts
Content-Type: application/json
Accept: application/json

{
  "title": "テスト投稿",
  "content": "これはテスト用の投稿です"
}

### 🌍 環境変数表示
GET http://localhost/env
Accept: application/json

### ⚙️ ConfigMap確認
GET http://localhost/config
Accept: application/json

### 🔑 Secret確認
GET http://localhost/secret
Accept: application/json

### ⚠️ エラーテスト
GET http://localhost/error-test
Accept: application/json

### 🔥 CPU負荷試験（3秒）
GET http://localhost/load-test?duration=3000
Accept: application/json

### 🔥 CPU負荷試験（10秒）
GET http://localhost/load-test?duration=10000
Accept: application/json

### 💾 メモリ負荷試験（100MB, 3秒）
GET http://localhost/load-test/memory?size=100&duration=3000
Accept: application/json

### 💾 メモリ負荷試験（500MB, 5秒）
GET http://localhost/load-test/memory?size=500&duration=5000
Accept: application/json
