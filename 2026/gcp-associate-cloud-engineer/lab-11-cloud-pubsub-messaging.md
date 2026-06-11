# Lab 11: Cloud Pub/Sub — Asynchronous Messaging

**Exam Domain:** 3 — Deploying event-driven architectures

---

## Overview

Cloud Pub/Sub is Google Cloud's fully managed, real-time messaging service. It decouples services so publishers and subscribers operate independently — a producer can send messages without knowing who will consume them.

### Key Concepts
- **Topic** — A named channel where publishers send messages.
- **Subscription** — A named resource representing a stream of messages from a topic. Each subscription receives a copy of every message.
- **Pull Subscription** — The subscriber explicitly requests messages (polling model).
- **Push Subscription** — Pub/Sub sends messages to an HTTPS endpoint (webhook model).
- **Acknowledgement (Ack)** — Subscriber confirms message was processed. Unacked messages are redelivered.
- **Dead Letter Topic** — Messages that fail delivery after N attempts are routed here instead of being lost.
- **Message Ordering** — Enabled via ordering keys for FIFO-like behavior within a key.

---

## 📨 Hands-on Tasks

### Task 1: Create Topics and Subscriptions

```bash
# Create a topic
gcloud pubsub topics create ace-orders-topic

# Create a pull subscription
gcloud pubsub subscriptions create ace-orders-sub \
    --topic=ace-orders-topic \
    --ack-deadline=60

# Create subscription with message ordering
gcloud pubsub subscriptions create ace-orders-ordered-sub \
    --topic=ace-orders-topic \
    --enable-message-ordering
```

### Task 2: Publish Messages

```bash
# Publish a single message
gcloud pubsub topics publish ace-orders-topic \
    --message='{"orderId": "1001", "item": "laptop", "qty": 1}'

# Publish with attributes (key-value metadata)
gcloud pubsub topics publish ace-orders-topic \
    --message='{"orderId": "1002", "item": "keyboard", "qty": 3}' \
    --attribute=priority=high,source=web

# Publish with ordering key (for ordered delivery)
gcloud pubsub topics publish ace-orders-topic \
    --message='{"orderId": "1003", "item": "mouse", "qty": 2}' \
    --ordering-key=user-123
```

### Task 3: Pull and Acknowledge Messages

```bash
# Pull messages with auto-ack (simplest)
gcloud pubsub subscriptions pull ace-orders-sub --limit=5 --auto-ack

# Pull without auto-ack to practice manual acknowledgement
gcloud pubsub subscriptions pull ace-orders-sub --limit=5
# Note the ACK_ID from output, then:
gcloud pubsub subscriptions ack ace-orders-sub --ack-ids=<ACK_ID>
```

### Task 4: Create a Push Subscription

```bash
# Push subscription sends messages to an HTTPS endpoint
# (e.g., a Cloud Run service URL)
export PUSH_ENDPOINT="https://your-cloud-run-service-url.run.app"

gcloud pubsub subscriptions create ace-orders-push-sub \
    --topic=ace-orders-topic \
    --push-endpoint=$PUSH_ENDPOINT \
    --push-auth-service-account=pubsub-push-sa@ace-lab-prod-2026.iam.gserviceaccount.com
```

### Task 5: Create a Dead Letter Topic

```bash
# Create dead letter topic
gcloud pubsub topics create ace-orders-dead-letter

# Create subscription on dead letter topic (to monitor failures)
gcloud pubsub subscriptions create ace-dead-letter-sub \
    --topic=ace-orders-dead-letter

# Update main subscription to use dead letter
gcloud pubsub subscriptions update ace-orders-sub \
    --dead-letter-topic=ace-orders-dead-letter \
    --max-delivery-attempts=5

# Grant Pub/Sub permission to publish to dead letter topic
PROJECT_NUMBER=$(gcloud projects describe ace-lab-prod-2026 --format='value(projectNumber)')
gcloud pubsub topics add-iam-policy-binding ace-orders-dead-letter \
    --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com" \
    --role="roles/pubsub.publisher"
```

---

## ✅ Verification

```bash
# List topics and subscriptions
gcloud pubsub topics list
gcloud pubsub subscriptions list

# Publish 3 messages and pull them
for i in 1 2 3; do
  gcloud pubsub topics publish ace-orders-topic --message="Test message $i"
done
gcloud pubsub subscriptions pull ace-orders-sub --limit=10 --auto-ack
```

---

## 🧹 Cleanup

```bash
gcloud pubsub subscriptions delete ace-orders-sub ace-orders-ordered-sub \
    ace-orders-push-sub ace-dead-letter-sub --quiet
gcloud pubsub topics delete ace-orders-topic ace-orders-dead-letter --quiet
```
