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

module "composer-service-accounts" {
  source       = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account?ref=v18.0.0/"
  project_id   = var.project_id
  name         = "composer-default"
  generate_key = false
  # authoritative roles granted *on* the service accounts to other identities
  iam = {
  }
  # non-authoritative roles granted *to* the service accounts on other resources
  iam_project_roles = {
    "${var.project_id}" = [
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
      "roles/composer.ServiceAgentV2Ext",
      "roles/composer.worker",
      "roles/composer.admin",
      "roles/dataflow.admin",
      "roles/iam.serviceAccountUser",
      "roles/compute.networkUser",
    ]
  }
}

resource "google_project_iam_member" "cloudbuild_sa" {
  for_each = toset(["roles/composer.admin", "roles/composer.worker"])
  project  = var.project_id
  role     = each.key
  member   = "serviceAccount:${local.project_number}@cloudbuild.gserviceaccount.com"
}
