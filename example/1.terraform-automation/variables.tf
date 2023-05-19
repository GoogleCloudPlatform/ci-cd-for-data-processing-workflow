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

variable "project_id" {
  description = "Project ID where Cloud Composer Environment is created."
  type        = string
}

variable "region" {
  description = "Region where the Cloud Composer Environment is created."
  default     = "us-central1"
  type        = string
}

variable "composer_env_name" {
  description = "Name of Cloud Composer Environment"
  default     = "composer-dev-env"
  type        = string
}

variable "composer_zone_id" {
  description = "Zone value which is passed to the Airflow envt"
  default     = "us-central1-a"
  type        = string
}

variable "network" {
  type        = string
  default     = "default"
  description = "The VPC network to host the composer cluster."
}

variable "subnetwork" {
  type        = string
  default     = "default"
  description = "The subnetwork to host the composer cluster."
}

variable "pubsub_topic" {
  type        = string
  default     = "integration-test-complete-topic"
  description = "Name of the pub sub topic."
}

variable "datapipeline_csr_name" {
  type        = string
  default     = "data-pipeline-source"
  description = "The CSR repo name to be used for storing the datapipeline source code."

}

variable "terraform_deployment_csr_name" {
  type        = string
  default     = "terraform-automation-source"
  description = "The CSR repo name to be used for storing the terraform code."

}

variable "composer_dag_name_prod" {
  type        = string
  default     = "prod_word_count"
  description = "The Composer DAG name(for prod) to be passed as environment variable."
}


variable "composer_dag_name_test" {
  type        = string
  default     = "test_word_count"
  description = "The Composer DAG name(for test) to be passed as environment variable."

}

variable "image_version" {
  type        = string
  description = "The version of the airflow running in the cloud composer environment."
  default     = "composer-2.0.32-airflow-2.3.4"
}
