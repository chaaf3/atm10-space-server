output "server_ip" {
  description = "Public IPv4 address for the Minecraft server."
  value       = aws_eip.server.public_ip
}

output "minecraft_address" {
  description = "Minecraft server address."
  value       = "${aws_eip.server.public_ip}:25565"
}

output "ssh_command" {
  description = "SSH command for server administration."
  value       = "ssh ubuntu@${aws_eip.server.public_ip}"
}

output "logs_command" {
  description = "Command to follow the ATM10 service logs."
  value       = "ssh ubuntu@${aws_eip.server.public_ip} 'sudo journalctl -u atm10 -f'"
}
