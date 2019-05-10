#!/bin/bash
#
# This script sets the environment variables for project environment specific
# information such as project_id, region and zone choice. And also name of
# buckets that are used by the build pipeline and the data processing workflow.
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
export TEST='test'
export GCP_PROJECT_ID=$(gcloud config list --format 'value(core.project)')
export PROJECT_NUMBER=$(gcloud projects describe "${GCP_PROJECT_ID}" --format='get(projectNumber)')
export DATAFLOW_JAR_BUCKET_TEST="${GCP_PROJECT_ID}-composer-dataflow-source-${TEST}"
export INPUT_BUCKET_TEST="${GCP_PROJECT_ID}-composer-input-${TEST}"
export RESULT_BUCKET_TEST="${GCP_PROJECT_ID}-composer-result-${TEST}"
export REF_BUCKET_TEST="${GCP_PROJECT_ID}-composer-ref-${TEST}"
export DATAFLOW_STAGING_BUCKET_TEST="${GCP_PROJECT_ID}-dataflow-staging-${TEST}"
export PROD='prod'
export DATAFLOW_JAR_BUCKET_PROD="${GCP_PROJECT_ID}-composer-dataflow-source-${PROD}"
export INPUT_BUCKET_PROD="${GCP_PROJECT_ID}-composer-input-${PROD}"
export RESULT_BUCKET_PROD="${GCP_PROJECT_ID}-composer-result-${PROD}"
export DATAFLOW_STAGING_BUCKET_PROD="${GCP_PROJECT_ID}-dataflow-staging-${PROD}"
export COMPOSER_REGION='us-central1'
export RESULT_BUCKET_REGION="${COMPOSER_REGION}"
export COMPOSER_ZONE_ID='us-central1-a'

export COMPOSER_ENV_NAME='data-pipeline-composer'
export SOURCE_CODE_REPO='data-pipeline-source'
export COMPOSER_DAG_NAME_TEST='test_word_count'
export COMPOSER_DAG_NAME_PROD='prod_word_count'
