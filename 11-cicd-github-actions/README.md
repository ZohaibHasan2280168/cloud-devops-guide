# 11 — GitHub Actions CI/CD Automation & GitOps Handoff

GitHub Actions provides automated continuous integration and continuous delivery (CI/CD) pipelines directly integrated into GitHub repositories.

---

## 1. End-to-End Pipeline Architecture

```mermaid
graph LR
    Dev([👨‍💻 Developer]) -->|1. git push to main| GitHub["GitHub Repo"]
    GitHub -->|2. Trigger Workflow| Runner["GitHub Actions Runner (ubuntu-latest)"]
    
    subgraph CI_Pipeline ["Continuous Integration (CI)"]
        Runner -->|3. Run Tests & Lints| Tests["Unit & Integration Tests"]
        Runner -->|4. Docker Multi-Stage Build| Build["Docker Build"]
        Runner -->|5. Push Image with Git SHA| ECR["Amazon ECR Registry"]
    end

    subgraph CD_Handoff ["GitOps CD Handoff"]
        Runner -->|6. Update k8s/*.yaml with new SHA| Commit["Auto-commit with [skip ci]"]
        Commit -->|7. Pushed to main| GitHub
        ArgoCD["ArgoCD Controller"] -->|8. Detects New Git Commit & Syncs| EKS["Amazon EKS Cluster"]
    end
```

---

## 2. GitHub Repository Secrets Setup

Navigate to your GitHub Repository -> **Settings** -> **Secrets and variables** -> **Actions** -> **New repository secret**:

| Secret Key | Description | Example Value |
| :--- | :--- | :--- |
| `AWS_ACCESS_KEY_ID` | IAM User Access Key for CI | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | IAM User Secret Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_REGION` | Target AWS Region | `us-east-1` |
| `AWS_ACCOUNT_ID` | 12-digit AWS Account ID | `479537131188` |

---

## 3. Production Pipeline Manifest

### `.github/workflows/deploy.yml`
```yaml
name: Production CI/CD Pipeline

on:
  push:
    branches:
      - main
    paths-ignore:
      - '**.md'
      - 'docs/**'
      - '.gitignore'

jobs:
  build-and-push:
    name: Build & Push to Amazon ECR
    runs-on: ubuntu-latest

    steps:
      - name: 1. Checkout Repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: 2. Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: 3. Log in to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: 4. Extract Git Short SHA
        id: vars
        run: echo "sha_short=$(git rev-parse --short HEAD)" >> $GITHUB_OUTPUT

      - name: 5. Build and Push Frontend Image
        env:
          REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: sha-${{ steps.vars.outputs.sha_short }}
        run: |
          docker build -t $REGISTRY/smartdoc-frontend:$IMAGE_TAG ./frontend
          docker build -t $REGISTRY/smartdoc-frontend:latest ./frontend
          docker push $REGISTRY/smartdoc-frontend:$IMAGE_TAG
          docker push $REGISTRY/smartdoc-frontend:latest

      - name: 6. Build and Push Backend Image
        env:
          REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: sha-${{ steps.vars.outputs.sha_short }}
        run: |
          docker build -t $REGISTRY/smartdoc-backend:$IMAGE_TAG ./backend
          docker build -t $REGISTRY/smartdoc-backend:latest ./backend
          docker push $REGISTRY/smartdoc-backend:$IMAGE_TAG
          docker push $REGISTRY/smartdoc-backend:latest

      - name: 7. Update Kubernetes Manifests (GitOps Handoff)
        env:
          IMAGE_TAG: sha-${{ steps.vars.outputs.sha_short }}
        run: |
          sed -i "s|smartdoc-frontend:.*|smartdoc-frontend:$IMAGE_TAG|g" k8s/frontend.yaml
          sed -i "s|smartdoc-backend:.*|smartdoc-backend:$IMAGE_TAG|g" k8s/backend.yaml

      - name: 8. Commit and Push Manifest Changes
        run: |
          git config --global user.name "github-actions[bot]"
          git config --global user.email "github-actions[bot]@users.noreply.github.com"
          git add k8s/
          git diff --quiet && git diff --staged --quiet || (git commit -m "chore(gitops): update images to sha-${{ steps.vars.outputs.sha_short }} [skip ci]" && git push origin main)
```

---

## 4. Why `[skip ci]` is Critical

Notice line 74: `[skip ci]` in the commit message. 
- **Without `[skip ci]`:** The bot commit pushing updated image tags would trigger another CI run, building images again, making another commit, causing an **infinite billing loop**.
- **With `[skip ci]`:** GitHub Actions halts the pipeline on the automated commit, allowing **ArgoCD** to pull the updated manifest safely.
