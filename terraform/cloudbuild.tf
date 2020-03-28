resource "google_cloudbuild_trigger" "master-ci-trigger" {
  description = "Triggers Cloud Composer Integration Tests"
  project     = "${var.project_id}"

  trigger_template {
    project_id  = "${var.project_id}"
    branch_name = "master"
    repo_name   = "${var.mono_repo_name}"
  }

  substitutions {
    _REPO_NAME               = "${var.mono_repo_name}"
    _COMPOSER_ENV_NAME       = "${google_composer_environment.composer_env.name}"
    _COMPOSER_REGION         = "${google_composer_environment.composer_env.region}"
    _DATAFLOW_JAR_BUCKET     = "${var.project_id}-dataflow_jars"
    _DATAFLOW_STAGING_BUCKET = "${var.project_id}-dataflow_staging"
    _COMPOSER_DAG_BUCKET     = "${replace(google_composer_environment.composer_env.config.0.dag_gcs_prefix, "dags", "")}"
    _WORDCOUNT_INPUT_BUCKET  = "${var.project_id}-wordcount_input"
    _WORDCOUNT_RESULT_BUCKET = "${var.project_id}-wordcount_result"
    _WORDCOUNT_REF_BUCKET    = "${var.project_id}-wordcount_ref"
  }

  filename = "cloudbuild.yaml"
}
data "google_project" "project" {
  project_id = "${var.project_id}"
}

resource "google_project_iam_member" "cloudbuild-composer-user" {
  project = "${var.project_id}"
  role    = "roles/composer.user"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild-containers-developer" {
  project = "${var.project_id}"
  role    = "roles/container.admin"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

