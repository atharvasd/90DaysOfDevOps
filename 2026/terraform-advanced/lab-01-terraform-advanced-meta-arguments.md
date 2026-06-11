# Lab 01: Advanced Terraform Meta-Arguments (`count`, `for_each`, `dynamic`)

**Topic:** Infrastructure as Code — Advanced configuration constructs

---

## Overview

As your Terraform configurations grow, repeating resource blocks manually becomes unmanageable. Terraform provides **meta-arguments** that change how resources and modules are evaluated, allowing you to dynamically provision multiple resources from a single block.

### Key Concepts
- **`count`** — Provisions multiple identical resources based on a whole number. Good for identical resources (like N number of identical VMs).
- **`for_each`** — Provisions multiple resources based on a map or a set of strings. Better than `count` when resources have distinct identities or configurations, because adding/removing an item from the middle of the collection doesn't recreate all subsequent resources.
- **`dynamic` blocks** — Dynamically constructs repeatable nested blocks within a resource (like multiple `ingress` rules in a security group).
- **`lifecycle`** — Customizes the lifecycle of a resource (e.g., `create_before_destroy`, `prevent_destroy`, `ignore_changes`).

---

## 🛠️ Hands-on Tasks

### Task 1: The Problem with `count`

First, let's look at `count` and its primary flaw.

```hcl
# Create 3 identical users using count
variable "user_names_count" {
  type    = list(string)
  default = ["alice", "bob", "charlie"]
}

resource "aws_iam_user" "count_users" {
  count = length(var.user_names_count)
  name  = var.user_names_count[count.index]
}
```

**The Flaw:** If you remove `"bob"` from the middle of the list `["alice", "charlie"]`, Terraform will:
1. See `count` changed from 3 to 2.
2. Destroy `count_users[2]` (charlie).
3. Rename `count_users[1]` from "bob" to "charlie".

This destroys and recreates infrastructure unnecessarily!

### Task 2: Solving it with `for_each`

`for_each` creates resources tracked by a string key, not a numeric index.

```hcl
variable "user_names_foreach" {
  type    = set(string)
  default = ["alice", "bob", "charlie"]
}

resource "aws_iam_user" "foreach_users" {
  for_each = var.user_names_foreach
  name     = each.key
}
```

Now, the state tracks `aws_iam_user.foreach_users["alice"]`. If you remove `"bob"`, Terraform *only* destroys `"bob"`. Alice and Charlie are untouched.

### Task 3: `for_each` with Maps (Complex Configurations)

You can use maps to provide different configurations to each instance.

```hcl
variable "virtual_machines" {
  type = map(object({
    instance_type = string
    environment   = string
  }))
  default = {
    "web-server" = { instance_type = "t3.micro", environment = "dev" }
    "db-server"  = { instance_type = "t3.small", environment = "prod" }
  }
}

resource "aws_instance" "servers" {
  for_each      = var.virtual_machines
  
  ami           = "ami-0c55b159cbfafe1f0" # Example AMI
  instance_type = each.value.instance_type
  
  tags = {
    Name        = each.key
    Environment = each.value.environment
  }
}
```

### Task 4: `dynamic` Blocks

Imagine a Security Group where you need to allow multiple ports. Instead of writing 10 `ingress` blocks, use a `dynamic` block.

```hcl
variable "allowed_web_ports" {
  type    = list(number)
  default = [80, 443, 8080, 8443]
}

resource "aws_security_group" "web_sg" {
  name        = "web-security-group"
  description = "Allow inbound web traffic"
  vpc_id      = "vpc-12345678"

  dynamic "ingress" {
    for_each = var.allowed_web_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### Task 5: `lifecycle` Meta-Argument

Control how Terraform manages updates and deletions.

```hcl
resource "aws_instance" "critical_db" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.medium"
  
  tags = {
    Name = "Critical-Database"
  }

  lifecycle {
    # Terraform will throw an error if you try to destroy this resource
    prevent_destroy = true
    
    # Ignore manual changes made to tags (prevents Terraform from overriding them)
    ignore_changes = [tags]
    
    # If the resource must be replaced, create the new one BEFORE destroying the old one
    # (Requires names to be unique or dynamically generated)
    create_before_destroy = true
  }
}
```

---

## ✅ Best Practices Summary

1. **Prefer `for_each` over `count`**: Unless the resources are completely identical and interchangeable (like identical worker nodes in a pool), always use `for_each`. It prevents destructive cascading updates.
2. **Use `dynamic` blocks sparingly**: While powerful, nested dynamic blocks can make code hard to read. Use them only when the number of nested blocks is variable or driven by inputs.
3. **Use `prevent_destroy` for databases/state**: Always apply this lifecycle rule to databases, storage buckets, and key vaults to prevent accidental data loss.
