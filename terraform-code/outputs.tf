output "controller_public_ip" {
  value       = aws_instance.controller.public_ip
  description = "Connect here via: ssh ec2-user@<IP>"
}

output "raw_private_key" {
  value     = tls_private_key.lab_key.private_key_pem
  sensitive = true
}
