# 09 — Amazon EKS Production Architecture & eksctl

Amazon Elastic Kubernetes Service (Amazon EKS) is a managed Kubernetes service that eliminates the operational burden of deploying and managing the Kubernetes control plane across multiple Availability Zones.

---

## 1. Managed Control Plane Architecture

In Amazon EKS:
- **Control Plane:** AWS provisions, scales, and backs up three master nodes running `kube-apiserver` and `etcd` across 3 AZs with a 99.95% uptime SLA.
- **Data Plane (Worker Nodes):** EC2 instances managed as **Managed Node Groups** within your custom VPC, automatically handling node drain and AMIs upgrades.
- **AWS VPC CNI (`aws-node`):** Allocates actual native VPC private IPv4 addresses directly to pods, enabling low-latency microservice communication without overlay encapsulation.

---

## 2. Declarative Cluster Configuration (`eksctl`)

Using the official `eksctl` tool, configure an entire production cluster declaratively:

### `eks-cluster.yaml`
```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: smartdoc-eks-v2
  region: us-east-1
  version: "1.31"

vpc:
  id: "vpc-07f6f57a4c7245788"
  subnets:
    public:
      us-east-1a:
        id: "subnet-03bffc09caeee371f"
      us-east-1b:
        id: "subnet-0f6ede4cc98ad48a8"
    private:
      us-east-1a:
        id: "subnet-0e7f986789fe2552c"
      us-east-1b:
        id: "subnet-0d6faf157d36f1739"

managedNodeGroups:
  - name: standard-workers
    instanceType: t3.small
    desiredCapacity: 2
    minSize: 1
    maxSize: 2
    subnets:
      - subnet-03bffc09caeee371f
      - subnet-0f6ede4cc98ad48a8
    volumeSize: 20
    ssh:
      allow: true
      publicKeyName: smartdoc-key
    iam:
      withAddonPolicies:
        imageBuilder: true
        autoScaler: true
        albIngress: true
```

---

## 3. Provisioning & Kubeconfig Synchronization

```bash
# 💻 [Local Laptop Terminal]
# 1. Provision the EKS cluster (Takes ~12-15 minutes)
eksctl create cluster -f eks-cluster.yaml

# 2. Update your local kubeconfig to connect kubectl to EKS
aws eks update-kubeconfig --region us-east-1 --name smartdoc-eks-v2

# 3. Verify worker nodes are Ready
kubectl get nodes -o wide
```

---

## 4. Deploying Metrics Server & Addons

`metrics-server` is required for Horizontal Pod Autoscaling (HPA) and `kubectl top`:

```bash
# ☸️ [Kubernetes / EKS Terminal]
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify metrics are collecting
kubectl top nodes
kubectl top pods -A
```

---

## 5. Exposing Services via AWS Elastic Load Balancer (ELB)

When a Kubernetes Service specifies `type: LoadBalancer`, the AWS cloud provider controller provisions an AWS Classic or Network Load Balancer:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: smartdoc-ai
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: 3000
```

```bash
# ☸️ [Kubernetes / EKS Terminal]
# Fetch the AWS Load Balancer DNS name
kubectl get svc frontend -n smartdoc-ai

# Output example:
# a76e9b72cb0b84e5fafe4b2ca8d8d9c2-1240961382.us-east-1.elb.amazonaws.com
```

---

## 6. Safe & Clean EKS Cluster Teardown (Cost Safety)

To avoid orphan AWS Load Balancers or lingering CloudFormation stacks billing your account, always tear down in order:

```bash
# ☸️ [Kubernetes / EKS Terminal]
# 1. FIRST: Delete the LoadBalancer service to remove the AWS ELB
kubectl delete svc frontend -n smartdoc-ai

# 2. SECOND: Delete the EKS cluster and managed nodegroups cleanly
eksctl delete cluster -f eks-cluster.yaml

echo "EKS cluster destroyed cleanly. $0 billing."
```
