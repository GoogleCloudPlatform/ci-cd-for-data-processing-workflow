# Copyright 2022 Google LLC
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

module "composer" {
  source                           = "terraform-google-modules/composer/google//modules/create_environment_v2"
  project_id                       = var.project_id
  region                           = var.region
  composer_env_name                = var.composer_env_name
  network                          = module.vpc.name
  subnetwork                       = var.subnetwork
  enable_private_endpoint          = false
  composer_service_account         = local.composer_service_account_email
  image_version                    = var.image_version
  pod_ip_allocation_range_name     = "pods"
  service_ip_allocation_range_name = "services"
  env_variables = {
    "AIRFLOW_VAR_GCP_PROJECT"                  = "${var.project_id}",
    "AIRFLOW_VAR_GCP_REGION"                   = "${var.region}",
    "AIRFLOW_VAR_GCP_ZONE"                     = "${var.composer_zone_id}",
    "AIRFLOW_VAR_GCP_NETWORK"                  = "${var.network}",
    "AIRFLOW_VAR_GCP_SUBNETWORK"               = "regions/${var.region}/subnetworks/${var.subnetwork}",
    "AIRFLOW_VAR_DATAFLOW_JAR_LOCATION_TEST"   = "${local.dataflow_jar_bucket_test}",
    "DATAFLOW_JAR_FILE_TEST"                   = "to_be_overriden",
    "AIRFLOW_VAR_GCS_INPUT_BUCKET_TEST"        = "${local.input_bucket_test}",
    "AIRFLOW_VAR_GCS_REF_BUCKET_TEST"          = "${local.ref_bucket_test}",
    "AIRFLOW_VAR_GCS_OUTPUT_BUCKET_TEST"       = "${local.result_bucket_test}",
    "AIRFLOW_VAR_DATAFLOW_STAGING_BUCKET_TEST" = "${local.dataflow_staging_bucket_test}",
    "AIRFLOW_VAR_PUBSUB_TOPIC"                 = "${var.pubsub_topic}",
    "AIRFLOW_VAR_DATAFLOW_JAR_LOCATION_PROD"   = "${local.dataflow_jar_bucket_prod}",
    "DATAFLOW_JAR_FILE_PROD"                   = "to_be_overriden",
    "AIRFLOW_VAR_GCS_INPUT_BUCKET_PROD"        = "${local.input_bucket_prod}",
    "AIRFLOW_VAR_GCS_OUTPUT_BUCKET_PROD"       = "${local.result_bucket_prod}",
    "AIRFLOW_VAR_DATAFLOW_STAGING_BUCKET_PROD" = "${local.dataflow_staging_bucket_prod}",
  }
  airflow_config_overrides = {
  }

  depends_on = [
    module.vpc,
    module.project-services,
  ]
}
