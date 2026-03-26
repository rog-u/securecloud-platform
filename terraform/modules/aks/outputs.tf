output "cluster_id" {
  value = azurerm_kubernetes_cluster.main.id
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "cluster_fqdn" {
  description = "Private FQDN of the API server — only reachable from within the VNet"
  value       = azurerm_kubernetes_cluster.main.private_fqdn
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity — used for additional role assignments (e.g. Key Vault in Phase 2b)"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL — needed for Workload Identity federation in Phase 2b"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}
