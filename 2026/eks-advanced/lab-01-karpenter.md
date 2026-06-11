# Lab 01: Karpenter Node Autoscaling

**Topic:** Advanced Amazon EKS

---

## Overview

Historically, Kubernetes clusters on AWS used the **Cluster Autoscaler** combined with EC2 Auto Scaling Groups (ASGs). This approach is slow, inflexible (requiring multiple ASGs for different instance types), and tightly coupled to AWS legacy constructs.

**Karpenter** is an open-source, high-performance node provisioning project built for Kubernetes. It bypasses ASGs entirely, observing unschedulable pods and making direct API calls to AWS EC2 to provision exactly the right compute resources (instance type, architecture, zone) in seconds.

---

## 🛠️ Hands-on Tasks

### Task 1: Understand Karpenter Concepts

Karpenter uses two main Custom Resources (CRDs):
1. **NodePool:** Defines the constraints for node provisioning (e.g., "Only use t3 or m5 instances", "Only provision in us-east-1a", "Allow Spot instances").
2. **EC2NodeClass:** Defines AWS-specific configurations (e.g., IAM roles, AMIs, Subnets, Security Groups).

### Task 2: Define an `EC2NodeClass`

Assuming Karpenter is installed in your cluster (usually via Helm), create a NodeClass to tell Karpenter which subnets and security groups to use.

```yaml
# nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2 # Amazon Linux 2
  role: "KarpenterNodeRole-${CLUSTER_NAME}" # IAM role for the nodes
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
```

### Task 3: Define a `NodePool`

Create a NodePool that allows Karpenter to use cheap Spot instances of various sizes.

```yaml
# nodepool.yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
      nodeClassRef:
        name: default
  # Disruption controls how Karpenter terminates nodes to save money (consolidation)
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h # 30 days
```

### Task 4: Trigger Scale-Out

1. Apply the CRDs: `kubectl apply -f nodeclass.yaml -f nodepool.yaml`
2. Create a massive Deployment to trigger unschedulable pods.

```bash
kubectl create deployment inflate --image=public.ecr.aws/eks-distro/kubernetes/pause:3.2
kubectl scale deployment inflate --replicas=10
```

3. **Watch Karpenter act immediately:**
```bash
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter
```
*You will see Karpenter calculate exactly what instance type can fit those 10 pods cheapest, and request it directly from EC2. The node will join the cluster in ~30-60 seconds.*

---

## ✅ Best Practices
- **Consolidation:** Always enable `consolidationPolicy: WhenUnderutilized`. Karpenter will automatically move pods from nearly-empty nodes onto other nodes and terminate the empty nodes to save you money.
- **Spot Instances:** Let Karpenter handle Spot interruptions. It will receive the 2-minute warning from AWS, automatically cordon/drain the node, and spin up an On-Demand replacement before the Spot instance dies.
