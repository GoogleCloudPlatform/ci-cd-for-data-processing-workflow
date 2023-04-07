# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

resource "google_cloudbuild_trigger" "trigger-build-in-test-environment" {
  location = "global"
  project  = var.project_id
  name     = "datapipeline-trigger-build-test-environment"
  trigger_template {
    branch_name = "master"
    project_id  = var.project_id
    repo_name   = google_sourcerepo_repository.my-repo.name
  }

  substitutions = {
    REPO_NAME               = google_sourcerepo_repository.my-repo.name
    _COMPOSER_DAG_BUCKET    = local.composer_dag_bucket
    _COMPOSER_DAG_NAME_TEST = var.composer_dag_name_test
    _COMPOSER_ENV_NAME      = var.composer_env_name
    _COMPOSER_INPUT_BUCKET  = local.input_bucket_test
    _COMPOSER_REF_BUCKET    = local.ref_bucket_test
    _COMPOSER_REGION        = var.region
    _DATAFLOW_JAR_BUCKET    = local.dataflow_jar_bucket_test
  }

  filename = "build-pipeline/build_deploy_test.yaml"
  depends_on = [
    google_sourcerepo_repository.my-repo
  ]
}

resource "google_cloudbuild_trigger" "trigger-build-in-prod-environment" {
  location = "global"
  project  = var.project_id
  name     = "datapipeline-trigger-build-prod-environment"

  source_to_build {
    uri       = google_sourcerepo_repository.my-repo.url
    ref       = "refs/heads/master"
    repo_type = "CLOUD_SOURCE_REPOSITORIES"
  }

  pubsub_config {
    topic = module.pubsub.id
  }

  substitutions = {
    REPO_NAME                 = google_sourcerepo_repository.my-repo.name
    _COMPOSER_DAG_BUCKET      = local.composer_dag_bucket
    _COMPOSER_DAG_NAME_PROD   = var.composer_dag_name_prod
    _COMPOSER_ENV_NAME        = var.composer_env_name
    _COMPOSER_INPUT_BUCKET    = local.input_bucket_prod
    _COMPOSER_REF_BUCKET      = local.ref_bucket_test
    _COMPOSER_REGION          = var.region
    _DATAFLOW_JAR_BUCKET_PROD = local.dataflow_jar_bucket_prod
    _DATAFLOW_JAR_FILE_LATEST = "$(body.message.data)"
    _DATAFLOW_JAR_BUCKET_TEST = local.dataflow_jar_bucket_test
  }
  approval_config {
    approval_required = true
  }

  filename = "build-pipeline/deploy_prod.yaml"
}

resource "google_sourcerepo_repository" "my-repo" {
  name    = var.datapipeline_csr_name
  project = var.project_id
}

resource "google_sourcerepo_repository" "tf-source-repo" {
  name    = var.terraform_deployment_csr_name
  project = var.project_id
}
