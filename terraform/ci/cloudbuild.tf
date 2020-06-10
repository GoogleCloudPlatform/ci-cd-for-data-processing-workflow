resource "google_cloudbuild_trigger" "pr-ci-trigger" {
  provider    = google-beta
  description = "Triggers Cloud Composer Integration Tests"
  project     = var.project_id

  github {
    owner = "jaketf"
    name  = "ci-cd-for-data-processing-workflow"
    pull_request {
      branch          = ".*"
      comment_control = "COMMENTS_ENABLED"
    }
  }

  substitutions = {
    _COMPOSER_ENV_NAME       = google_composer_environment.orchestration.name
    _COMPOSER_REGION         = google_composer_environment.orchestration.region
    _DATAFLOW_JAR_BUCKET     = "${var.project_id}-us-dataflow_jars"
    _DATAFLOW_STAGING_BUCKET = "${var.project_id}-us-dataflow_staging"
    _COMPOSER_DAG_BUCKET = replace(
      google_composer_environment.orchestration.config[0].dag_gcs_prefix,
      "dags",
      "",
    )
    _WORDCOUNT_INPUT_BUCKET  = "${var.project_id}-us-wordcount_input"
    _WORDCOUNT_RESULT_BUCKET = "${var.project_id}-us-wordcount_result"
    _WORDCOUNT_REF_BUCKET    = "${var.project_id}-us-wordcount_ref"
  }

  filename = "cloudbuild.yaml"
}

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

