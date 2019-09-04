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

PATH=$PATH:/usr/local/airflow/google-cloud-sdk/bin
GCLOUD="gcloud -q"

function setup_local_airflow() {
  echo "AIRFLOW_HOME=$AIFLOW_HOME"
  export AIRFLOW_HOME=/usr/local/airflow
  echo "setting up local aiflow"
  echo "generating fernet key.\n"
  FERNET_KEY=$(python3.6 -c "from cryptography.fernet import Fernet; \
  print(Fernet.generate_key().decode('utf-8'))")
  export FERNET_KEY
  
  echo "initialize airflow database."
  airflow initdb
  
  # Import Airflow Variables to local Airflow.
  echo "import airflow vaiables."
  airflow variables --import config/Variables.json
  
  # Get current Cloud Composer custom connections.
  AIRFLOW_CONN_LIST=$($GCLOUD composer environments run "$COMPOSER_ENV_NAME" \
    connections -- --list 2>&1 | grep "?\s" | awk '{ FS = "?"}; {print $2}' | \
    tr -d ' ' | sed -e "s/'//g" | grep -v '_default$' | \
    grep -v 'local_mysql' | tail -n +3 | grep -v "\.\.\.")
  
  # Upload custom connetions to local Airflow.
  echo "uploading connections."
  for conn_id in $AIRFLOW_CONN_LIST; do
    echo "uploading connection: $conn_id."
    airflow connections --add --conn_id "$conn_id" --conn_type http || \
      echo "Upload $conn_id to local Airflow failed"
  done

  # Copy dags folder to AIRFLOW_HOME.
  echo "copying DAGs to local AIRFLOW_HOME."
  rsync -r dags $AIRFLOW_HOME/dags
}


# Run DAG validation tests. 
function run_tests() {
  cd ./source-code
  python3 -m unittest discover tests
}

setup_local_airflow
run_tests
