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
