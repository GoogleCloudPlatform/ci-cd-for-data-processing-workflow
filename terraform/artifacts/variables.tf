variable "project_id" {
  description = "Project ID for your GCP project to store artifacts"
}

variable "ci_project" {
  description = "Continuous Integration Project which pushes artifacts"
}

variable "ci_composer_env" {
  description = "CI Cloud Composer environment"
}

variable "ci_composer_region" {
  description = "CI compute region for Cloud Composer"
}

variable "ci_composer_dags_bucket" {
  description = "CI Cloud Composer environment"
}

variable "push_sa" {
  description = "service account responsible for pushing artifacts. this is typically the cloud build SA in the CI project."
}
