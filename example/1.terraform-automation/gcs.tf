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

module "gcs_buckets_test" {
  source     = "terraform-google-modules/cloud-storage/google"
  project_id = var.project_id
  names = [local.dataflow_jar_bucket_test,
    local.input_bucket_test,
    local.result_bucket_test,
    local.ref_bucket_test,
    local.dataflow_staging_bucket_test
  ]
  prefix          = ""
  set_admin_roles = true
  admins          = ["${local.composer_service_account}"]
  versioning = {
    first = true
  }
}

module "gcs_buckets_prod" {
  source     = "terraform-google-modules/cloud-storage/google"
  project_id = var.project_id
  names = [local.dataflow_jar_bucket_prod,
    local.input_bucket_prod,
    local.result_bucket_prod,
    local.dataflow_staging_bucket_prod
  ]
  prefix          = ""
  set_admin_roles = true
  admins          = ["${local.composer_service_account}"]
  versioning = {
    first = true
  }
}
