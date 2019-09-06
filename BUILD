#!/bin/bash
#
# Script that waits for the specified Cloud Composer DAG to deploy.
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

# We need to render environment variables in Variables.json before importing
# to Composer / Airflow. Alternatively, these values could be hard coded in 
# the json config.

source ./env-setup/set_env.sh
source ./env-setup/get_composer_properties.sh

echo "submitting build."
gcloud builds submit --config=cloudbuild.yaml --substitutions=\
REPO_NAME=$SOURCE_CODE_REPO,\
_DATAFLOW_JAR_BUCKET=$DATAFLOW_JAR_BUCKET_TEST,\
_COMPOSER_INPUT_BUCKET_TEST=$INPUT_BUCKET_TEST,\
_COMPOSER_REF_BUCKET=$REF_BUCKET_TEST,\
_COMPOSER_DAG_BUCKET=$COMPOSER_DAG_BUCKET,\
_COMPOSER_ENV_NAME=$COMPOSER_ENV_NAME,\
_COMPOSER_REGION=$COMPOSER_REGION,\
_COMPOSER_DAG_NAME_PROD=$COMPOSER_DAG_NAME_PROD,\
_COMPOSER_PLUGINS_PREFIX=$COMPOSER_PLUGINS_PREFIX,\
_COMPOSER_INPUT_BUCKET_PROD=$INPUT_BUCKET_PROD
