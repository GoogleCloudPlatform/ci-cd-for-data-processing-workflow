data google_project "project" {
  project_id = var.project_id
}
output "vpc" {
  value       = module.vpc
  description = "The VPC network created by this module"
}

output "composer-region" {
  value = var.composer_region
}

output "composer-env-name" {
  value       = google_composer_environment.orchestration.name
  description = "The Cloud Composer Environment created by this module"
}

output "composer-dags-bucket" {
  value       = replace(google_composer_environment.orchestration.config[0].dag_gcs_prefix, "dags", "")
  description = "The Cloud Composer Environment created by this module"
}

output "cloudbuild-sa" {
  value       = "${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
  description = "The Cloud build SA for the project created by this module"
}

output "dataflow-jars-bucket" {
  value       = module.dataflow_buckets.names_list[0]
  description = "Bucket where composer pulls Dataflow JARs from"
}

output "dataflow-staging-bucket" {
  value       = module.dataflow_buckets.names_list[1]
  description = "Staging bucket where for dataflow jobs"
}

output "project" {
  value       = data.google_project.project
  description = "The project created by this module"
}
