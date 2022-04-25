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

COMPOSER_VAR_FILE=composer_variables.json
if [ ! -f "${COMPOSER_VAR_FILE}" ]; then
    echo "Generate composer variable file ${COMPOSER_VAR_FILE}."
    envsubst < composer_variables.template > ${COMPOSER_VAR_FILE}
fi

gcloud composer environments storage data import \
--environment ${COMPOSER_ENV_NAME} \
--location ${COMPOSER_REGION} \
--source ${COMPOSER_VAR_FILE}

gcloud composer environments run \
${COMPOSER_ENV_NAME} \
--location ${COMPOSER_REGION} \
variables import -- /home/airflow/gcs/data/${COMPOSER_VAR_FILE}
