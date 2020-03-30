# Copyright 2019 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "project_id" {
  description = "Project ID for your GCP project"
  default     = "datapipelines-ci"
}

variable "project_num" {
  description = "Project num for your GCP Project"
  default     = "839839114118"
}

variable "network_name" {
  description = "The network your data pipelines should use"
  default     = "datapipelines-net"
}

variable "composer_region" {
  description = "Region for your composer environment"
  default     = "us-central1"
}

variable "composer_subnet" {
  description = "Name for composer subnetwork to create"
  default     = "composer-subnet"
}

variable "composer_env_name" {
  description = "Composer Environment name"
  default     = "datapipelines-orchestration2"
}

variable "env" {
  description = "Environment name ie. dev, test, prod"
  default     = ""
}

variable "mono_repo_name" {
  description = "Mono repo name for data pipelines source code"
  default     = "datapipelines-ci"
}

variable "mono_repo_url" {
  description = "Mono repo Cloud Source Repos url for data pipelines source code"
  default     = "datapipelines-ci"
}

