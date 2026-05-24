variable "region" {
  type    = string
  default = "asia-south1"
}

variable "zone" {
  type    = string
  default = "asia-south1-a"
}

variable "project_id" {
  type = string
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "machine_type" {
  type    = string
  default = "e2-micro"
}

variable "project_name" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "allowed_ports" {
  type    = list(number)
  default = [22, 80, 443]
}

variable "extra_labels" {
  type    = map(string)
  default = {}
}