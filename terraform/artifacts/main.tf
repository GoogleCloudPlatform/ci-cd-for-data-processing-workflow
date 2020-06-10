# Copyright 2019 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "7.1.0"

  project_id = var.project_id

  activate_apis = [
    "compute.googleapis.com",
    "cloudbuild.googleapis.com",
    "sourcerepo.googleapis.com",
    "artifactregistry.googleapis.com",
    "containerregistry.googleapis.com",
    "containerscanning.googleapis.com",
    "storage-component.googleapis.com",
    "storage-api.googleapis.com",
    "pubsub.googleapis.com",
    "stackdriver.googleapis.com",
  ]
}

module "artifacts-buckets" {
  source          = "terraform-google-modules/cloud-storage/google"
  version         = "~> 1.6"
  project_id      = var.project_id
  location        = "US"
  names           = ["dataflow"]
  prefix          = var.project_id
  set_admin_roles = true
  admins          = [""]
  versioning = {
    first = true
  }
}

resource "google_cloudbuild_trigger" "ci-pre-commit-trigger" {
  provider    = google-beta
  description = "Triggers automated style and unit tests in cloud build"
  project     = var.ci_project

  github {
    owner = "jaketf"
    name  = "ci-cd-for-data-processing-workflow"
    pull_request {
      branch = ".*"
    }
  }

  filename = "precommit_cloudbuild.yaml"
}

resource "google_cloudbuild_trigger" "ci-post-commit-trigger" {
  provider    = google-beta
  description = "Triggers Cloud Composer Integration Tests"
  project     = var.ci_project

  github {
    owner = "jaketf"
    name  = "ci-cd-for-data-processing-workflow"
    pull_request {
      branch          = ".*"
      comment_control = "COMMENTS_ENABLED"
    }
  }

  substitutions = {
    _COMPOSER_ENV_NAME       = var.ci_composer_env
    _COMPOSER_REGION         = var.ci_composer_region
    _DATAFLOW_JAR_BUCKET     = "${var.ci_project}-us-dataflow_jars"
    _DATAFLOW_STAGING_BUCKET = "${var.ci_project}-us-dataflow_staging"
    _COMPOSER_DAG_BUCKET = var.ci_composer_dags_bucket
    _WORDCOUNT_INPUT_BUCKET    = "${var.ci_project}-us-wordcount_input"
    _WORDCOUNT_RESULT_BUCKET   = "${var.ci_project}-us-wordcount_result"
    _WORDCOUNT_REF_BUCKET      = "${var.ci_project}-us-wordcount_ref"
    _ARTIFACTS_PROJECT_ID      = var.project_id
    _DATAFLOW_ARTIFACTS_BUCKET = module.artifacts-buckets.names_list[0]
  }

  filename = "cloudbuild.yaml"
}

resource "google_project_iam_member" "ci-cloudbuild-composer-user" {
  project = var.ci_project
  role    = "roles/composer.user"
  member  = "serviceAccount:${data.google_project.ci.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "ci-cloudbuild-containers-developer" {
  project = var.ci_project
  role    = "roles/container.admin"
  member  = "serviceAccount:${data.google_project.ci.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "ci-cloudbuild-artifact-admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${var.push_sa}"
}

resource "google_project_iam_member" "cloudbuild-artifact-reader" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${data.google_project.ci.number}@cloudbuild.gserviceaccount.com"
}

data google_project "ci" {
  project_id = var.ci_project
}

data google_project "artifacts" {
  project_id = var.project_id
}

data google_project "prod" {
  project_id = var.project_id
}

