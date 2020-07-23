#!/bin/bash

# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

echo "running deploydags go tests..."
if ! (cd ./composer/cloudbuild/go/dagsdeployer/internal/ && go vet ./... && go test ./...);
then
	echo "go tests for dags deployer failed"
	exit 1
fi

echo "running dataflow java tests..."
find ./dataflow/java/ -name pom.xml -execdir mvn test \;

echo "running airflow tests"
(cd composer && ./cloudbuild/bin/run_tests.sh ../bigquery/sql ./config/AirflowVariables.json ./plugins)
