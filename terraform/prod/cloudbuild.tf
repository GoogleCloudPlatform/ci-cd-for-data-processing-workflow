data "google_project" "project" {
  project_id = var.project_id
}

resource "google_project_iam_member" "cloudbuild-composer-user" {
  project = var.project_id
  role    = "roles/composer.user"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild-containers-developer" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

