output "ssh_private_key" {
  value = module.cluster.ssh_private_key
  sensitive  = true
}

output "public_dns" {
  value = module.cluster.public_dns[0]
}

output "public_ip" {
  value = module.cluster.public_ip[0]
}

output "kubeconfig" {
  value = module.cluster.kubeconfig
}
