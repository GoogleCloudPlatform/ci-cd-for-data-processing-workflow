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

locals {
  composer_dag_bucket            = module.composer.gcs_bucket
  composer_service_account       = module.composer-service-accounts.iam_email
  composer_service_account_email = module.composer-service-accounts.email
  #test buckets
  dataflow_jar_bucket_test     = "${var.project_id}-composer-dataflow-source-test-tf"
  input_bucket_test            = "${var.project_id}-composer-input-test-tf"
  ref_bucket_test              = "${var.project_id}-composer-ref-test-tf"
  result_bucket_test           = "${var.project_id}-composer-result-test-tf"
  dataflow_staging_bucket_test = "${var.project_id}-dataflow-staging-test-tf"
  #prod buckets
  dataflow_jar_bucket_prod     = "${var.project_id}-composer-dataflow-source-prod-tf"
  input_bucket_prod            = "${var.project_id}-composer-input-prod-tf"
  result_bucket_prod           = "${var.project_id}-composer-result-prod-tf"
  dataflow_staging_bucket_prod = "${var.project_id}-dataflow-staging-prod-tf"
  project_number               = data.google_project.project.number
}

data "google_project" "project" {
  project_id = var.project_id
}

module "project-services" {
  source                      = "terraform-google-modules/project-factory/google//modules/project_services"
  project_id                  = var.project_id
  enable_apis                 = true
  disable_services_on_destroy = true
  activate_apis = [
    "sourcerepo.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "pubsub.googleapis.com",
    "composer.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "bigquery.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
  ]
}

