output "vpc_name" {
  value = module.vpc.vpc_name
}

output "subnet_name" {
  value = module.vpc.subnet_name
}

output "gke_cluster_name" {
  value = module.gke.cluster_name
}

output "cloudsql_private_ip" {
  value     = module.cloudsql.private_ip
  sensitive = true
}

output "redis_host" {
  value     = module.redis.host
  sensitive = true
}
