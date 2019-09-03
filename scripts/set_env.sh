#!/bin/bash
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

#
export TEST='test'
GCP_PROJECT_ID=$(gcloud config list --format 'value(core.project)')
export GCP_PROJECT_ID
export PROJECT_ID="$GCP_PROJECT_ID"
PROJECT_NUMBER=$(gcloud projects describe "${GCP_PROJECT_ID}" --format='get(projectNumber)')
export PROJECT_NUMBER
export DATAFLOW_JAR_BUCKET="${GCP_PROJECT_ID}-composer-dataflow-source"
export INPUT_BUCKET="${GCP_PROJECT_ID}-composer-input"
export RESULT_BUCKET="${GCP_PROJECT_ID}-composer-result"
export DATAFLOW_STAGING_BUCKET="${GCP_PROJECT_ID}-dataflow-staging"
export COMPOSER_REGION='us-central1'
export RESULT_BUCKET_REGION="${COMPOSER_REGION}"
export COMPOSER_ZONE_ID='us-central1-a'

export COMPOSER_ENV_NAME='datapipelines-composer'
export SOURCE_CODE_REPO='data-pipeline-source'
export COMPOSER_DAG_NAME='wordcount_dag'
