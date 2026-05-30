output "server_ip" {
  description = "Public IPv4 address for the Minecraft server."
  value       = data.oci_core_vnic.server.public_ip_address
}

output "minecraft_address" {
  description = "Minecraft server address."
  value       = "${data.oci_core_vnic.server.public_ip_address}:25565"
}

output "ssh_command" {
  description = "SSH command for server administration."
  value       = "ssh ubuntu@${data.oci_core_vnic.server.public_ip_address}"
}

output "logs_command" {
  description = "Command to follow the ATM10 service logs."
  value       = "ssh ubuntu@${data.oci_core_vnic.server.public_ip_address} 'sudo journalctl -u atm10 -f'"
}

output "selected_image" {
  description = "Ubuntu image selected for the ARM instance."
  value       = data.oci_core_images.ubuntu.images[0].display_name
}

output "selected_availability_domain" {
  description = "Availability domain used for the instance."
  value       = local.availability_domain
}

output "fixed_capacity_quota_id" {
  description = "OCI quota policy enforcing the fixed server footprint."
  value       = try(oci_limits_quota.fixed_capacity_guardrail[0].id, null)
}

output "monthly_budget_id" {
  description = "OCI monthly budget used for soft spend alerts."
  value       = try(oci_budget_budget.monthly_server_budget[0].id, null)
}

output "cost_shutdown_dynamic_group_id" {
  description = "Dynamic group used by the server-side budget shutdown timer."
  value       = try(oci_identity_dynamic_group.cost_shutdown[0].id, null)
}

output "cost_shutdown_policy_id" {
  description = "IAM policy allowing the server to inspect the budget and stop itself."
  value       = try(oci_identity_policy.cost_shutdown[0].id, null)
}
