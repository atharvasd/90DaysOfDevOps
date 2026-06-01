###################################################################################
## Task 1
###################################################################################

## 1. Why was Kubernetes created? What problem does it solve that Docker alone cannot?

Docker solves the problem of packaging and running a single container, but it cannot manage containers at scale across multiple machines. When you have hundreds or thousands of containers spread across many servers, you need something to handle:

Scheduling containers to the right machines
Restarting containers if they crash
Scaling up/down based on load
Rolling updates with zero downtime
Load balancing traffic across container replicas
Self-healing when a node goes down
Kubernetes (k8s) is a container orchestrator — it automates all of this across a cluster of machines.

## 2. Who created Kubernetes and what was it inspired by?

Kubernetes was created by Google and open-sourced in 2014. It was inspired by Google's internal cluster management system called Borg (and later Omega), which Google had been using for over a decade to run billions of containers at scale across its data centers. The core ideas — desired state, reconciliation loops, and pod scheduling — come directly from Borg.

It is now maintained by the Cloud Native Computing Foundation (CNCF).

## 3. What does the name "Kubernetes" mean?

"Kubernetes" (κυβερνήτης) is a Greek word meaning "helmsman" or "pilot" — the person who steers a ship. The logo is a ship's steering wheel (helm), and the metaphor is that Kubernetes steers your containers to their destination. This is also why the Kubernetes package manager is called Helm.

###################################################################################
## Task 2
###################################################################################
Architecture Diagram (text-based):


┌─────────────────────────────────────────────────────┐
│                  CONTROL PLANE                       │
│                                                      │
│  ┌─────────────┐   ┌──────┐   ┌───────────────────┐ │
│  │  API Server │   │ etcd │   │ Controller Manager│ │
│  │ (front door)│   │ (DB) │   │  (reconcile loop) │ │
│  └─────────────┘   └──────┘   └───────────────────┘ │
│                                                      │
│              ┌───────────┐                           │
│              │ Scheduler │                           │
│              │(picks node│                           │
│              │  for pod) │                           │
│              └───────────┘                           │
└─────────────────────────────────────────────────────┘
          │               │               │
          ▼               ▼               ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  WORKER NODE │  │  WORKER NODE │  │  WORKER NODE │
│              │  │              │  │              │
│  kubelet     │  │  kubelet     │  │  kubelet     │
│  kube-proxy  │  │  kube-proxy  │  │  kube-proxy  │
│  containerd  │  │  containerd  │  │  containerd  │
│              │  │              │  │              │
│  [Pod][Pod]  │  │  [Pod][Pod]  │  │  [Pod]       │
└──────────────┘  └──────────────┘  └──────────────┘
What each component does:

Component	Role
API Server	The single entry point for all operations. Every kubectl command hits the API server first.
etcd	Key-value store that holds the entire cluster state — what should be running, what is running, all config.
Scheduler	Watches for new pods with no assigned node, picks the best node based on resources and constraints.
Controller Manager	Runs control loops — constantly compares desired state vs actual state and acts to fix any differences.
kubelet	Agent on every worker node. Receives instructions from the API server and ensures the right containers are running.
kube-proxy	Manages network rules on each node so pods and services can communicate inside and outside the cluster.
Container Runtime	Actually runs the containers (containerd is most common; Docker used to be used here).
Trace: What happens when you run kubectl apply -f pod.yaml?

kubectl sends the request to the API Server
API Server authenticates, validates, and saves the desired state to etcd
The Scheduler detects an unscheduled pod, picks a node, writes the assignment back to etcd via API Server
The kubelet on that node notices the new pod assignment, pulls the image, and tells containerd to start the container
kube-proxy updates networking rules so the pod is reachable
What if the API Server goes down?

You can't run any kubectl commands — no new changes can be made
But existing pods keep running — kubelet manages them locally
The cluster is effectively read-only/frozen until the API server recovers
What if a worker node goes down?

The Controller Manager detects the node is unhealthy
It marks the pods on that node as failed
The Scheduler reschedules those pods onto healthy nodes
The cluster self-heals automatically