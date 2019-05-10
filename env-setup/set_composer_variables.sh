#!/bin/bash
#
# This script sets the variables in Composer. The variables are needed for the
# data processing DAGs to properly execute, such as project-id, GCP region and
#zone. It also sets Cloud Storage buckets where test files are stored.
#
# Copyright 2019 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

declare -A variables
variables["gcp_project"]="${GCP_PROJECT_ID}"
variables["gcp_region"]="${COMPOSER_REGION}"
variables["gcp_zone"]="${COMPOSER_ZONE_ID}"
variables["dataflow_jar_location_test"]="${DATAFLOW_JAR_BUCKET_TEST}"
variables["dataflow_jar_file_test"]="to_be_overriden"
variables["gcs_input_bucket_test"]="${INPUT_BUCKET_TEST}"
variables["gcs_ref_bucket_test"]="${REF_BUCKET_TEST}"
variables["gcs_output_bucket_test"]="${RESULT_BUCKET_TEST}"
variables["dataflow_staging_bucket_test"]="${DATAFLOW_STAGING_BUCKET_TEST}"
variables["dataflow_jar_location_prod"]="${DATAFLOW_JAR_BUCKET_PROD}"
variables["dataflow_jar_file_prod"]="to_be_overriden"
variables["gcs_input_bucket_prod"]="${INPUT_BUCKET_PROD}"
variables["gcs_output_bucket_prod"]="${RESULT_BUCKET_PROD}"
variables["dataflow_staging_bucket_prod"]="${DATAFLOW_STAGING_BUCKET_PROD}"

for i in "${!variables[@]}"; do
  gcloud composer environments run "${COMPOSER_ENV_NAME}" \
  --location "${COMPOSER_REGION}" variables -- --set "${i}" "${variables[$i]}"
done
