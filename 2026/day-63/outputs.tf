output "network_id" {
  value = google_compute_network.TerraWeek_VPC.id
}

output "subnetwork_id" {
  value = google_compute_subnetwork.TerraWeek_Public_Subnet.id
}

output "instance_id" {
  value = google_compute_instance.TerraWeek_Server.id
}

output "instance_public_ip" {
  value = google_compute_instance.TerraWeek_Server.network_interface[0].access_config[0].nat_ip
}

output "instance_self_link" {
  value = google_compute_instance.TerraWeek_Server.self_link
}

output "firewall_rule_id" {
  value = google_compute_firewall.TerraWeek_Allow_HTTP.id
}
