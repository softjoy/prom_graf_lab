//to print out public ip
output "prom_graf_ip" {
  value = aws_instance.prom_graf.public_ip
}

output "docker_ip" {
  value = aws_instance.docker.public_ip
}