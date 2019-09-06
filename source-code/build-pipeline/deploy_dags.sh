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


DAG_LIST_FILE=../../config/running_dags.txt

# Any default flags we want when using GCP SDK
GCLOUD="gcloud -q"
GSUTIL="gsutil -q"

echo "Setting default gcloud project & composer location..."
$GCLOUD config set project "$PROJECT_ID"
$GCLOUD config set composer/location "$COMPOSER_REGION"

# Outputs the list of DAGs that need to started and stopped.
function get_stop_and_start_dags() {
  echo "Getting running dags..."

  RUNNING_DAGS=$($GCLOUD composer environments run "$COMPOSER_ENV_NAME" \
    list_dags 2>&1 | sed -e '1,/DAGS/d' | \
    tail -n +2 | sed '/^[[:space:]]*$/d' | grep -v 'airflow_monitoring' )

  echo "Got RUNNING_DAGS = ${RUNNING_DAGS}"

  echo "Deciding which dags to start/stop..."
  DAGS_TO_RUN=$(cat "$DAG_LIST_FILE")

  echo "DAGS_TO_RUN = ${DAGS_TO_RUN}"

  DAGS_TO_STOP=$(arrayDiff "${RUNNING_DAGS[@]}" "${DAGS_TO_RUN[@]}")
  DAGS_TO_START=$(arrayDiff "${DAGS_TO_RUN[@]}" "${RUNNING_DAGS[@]}")
  SAME_DAG=$(arraySame "${RUNNING_DAGS[@]}" "${DAGS_TO_RUN[@]}")


  echo "DAGS_TO_START = ${DAGS_TO_START}"

  echo "DAGS_TO_STOP = ${DAGS_TO_STOP}"

  # Checks that the local source file is the same as the existing DAG
  # on GCS. Will exit 1 if the hashes do not match.
  for dag_id in $SAME_DAG; do
    echo "Checking $dag_id hash values."
    check_files_are_same "$dag_id"
  done

}

# Get local and GCS file path and ensure, they are the same.
# $1 DAG id (string)
function check_files_are_same(){
  if [[ ! -z $1 ]]; then
      local_file_path=../dags/$1.py
      gcs_file_path="$COMPOSER_DAG_BUCKET/$1.py"

      validate_local_vs_gcs_dag_hashes "$local_file_path" "$gcs_file_path"
  fi
}

# Get hash value of a file.
# $1 Path to local or GCS file. (string)
function gcs_md5() {
  gsutil hash "$1" | grep md5 | awk 'NF>1{print $NF}'
}

# Compare the hash values of two files. 
# $1 File path (string)
# $2 File path (string)
function validate_local_vs_gcs_dag_hashes() {
  if [[ "$(gcs_md5 "$1")" != "$(gcs_md5 "$2")" ]]; then
    echo "Error: The dag definition file: $1 did not match the \
      corresponding file in GCS Dags folder: $2. \
      You should rename the new dag and remove the old DAG id \
      from running_dags.txt instead of trying to deploy over it."
    exit 1
  fi
}

# Pause DAG, delete file from GCS, and delete from Airflow UI. 
# $1 DAG id (string)
function handle_delete() {
  if [[ ! -z ${1// } ]]; then
      filename=$1.py
      echo "Pausing '$1'..."
      $GCLOUD composer environments run "$COMPOSER_ENV_NAME" pause -- "$1"

      echo "Deleting $filename file..."
      $GCLOUD composer environments storage dags delete \
        --environment="$COMPOSER_ENV_NAME" -- "$filename"
      
      wait_for_delete "$1"
  fi
}

# Add new files to GCS and unpause DAG.
# $1 DAG name (string)
function handle_new() {
  if [[ ! -z ${1// } ]]; then
      filename=$1.py

      echo "Uploading $filename file to composer dag bucket: $COMPOSER_DAG_BUCKET"
      $GSUTIL cp ../dags/$filename $COMPOSER_DAG_BUCKET
      status=$?

      if [[ status -ne 0 ]]; then 
        echo "Failed to upload DAG $filename"
        exit 1
      fi  

      deploy_start=$(date +%s)

      wait_for_deploy "$1"
      
      deploy_end=$(date +%s)
      runtime=$((deploy_end-deploy_start))

      echo "Wait for Deploy Runtime: " $runtime sec
  fi
}

# Delete DAG from Airflow UI.
# $1 DAG id (string)
function wait_for_delete() {
  local status=1
  local limit=0

  while [ $status -eq 1 ]; do
    if [ $limit -eq 3 ]; then
      echo "Abandoning delete $1 is taking longer then $limit retries."
      break
    fi

    echo "Deleting $1 from Airflow UI. Retry: $limit"
    $GCLOUD composer environments run "$COMPOSER_ENV_NAME" \
      delete_dag -- "$1" && break
    status=$?

    limit=$((limit + 1))
    sleep 3
  done
}

# Unpause the DAG. This will retry until suceesful.
# $1 DAG id (string)
function wait_for_deploy() {
  local status=1
  local limit=0

  while [[ $status -eq 1 ]]; do
    if [ $limit -eq 5 ]; then
      echo "Unpause $1 is taking longer then $limit retries."
      exit 1
    fi

    echo "Waiting for DAG deployment $1"

    $GCLOUD composer environments run "$COMPOSER_ENV_NAME" unpause -- "$1" && break
    status=$?

    echo Retry: $limit. Return status: $status
    limit=$((limit+1))
    sleep 60
  done
}

# Start all dags in DAGS_TO_START
function start_dags() {
  if [[ ${#DAGS_TO_START[@]} -gt 0 ]]
    then
      for dag_id in "${DAGS_TO_START[@]}"
      do
        handle_new $dag_id
      done
  fi
}

# Stop all dags in DAGS_TO_STOP
function stop_dags() {
  if [[ ${#DAGS_TO_START[@]} -gt 0 ]]
    then
      for dag_id in "${DAGS_TO_STOP[@]}"
      do
        handle_delete $dag_id
      done
  fi
}

function arrayDiff(){
  local result=()
  local array1=$1
  local array2=$2

  while read -r a1 ; do
    found=False

    while read -r a2 ; do
      if [[ $a1 == $a2 ]]; then
        found=True
        break
      fi
    done <<< "$array2"

    if [[ "$found" == "False" ]]; then
      result+=("$a1")
    fi
  done <<< "$array1"

  echo "${result[@]}"
}

function arraySame(){
  local result=()
  local array1=$1
  local array2=$2

  while read -r a1 ; do
    while read -r a2 ; do
      if [[ $a1 == $a2 ]]; then
        result+=("$a1")
        break
      fi
    done <<< "$array2"
  done <<< "$array1"

  echo "${result[@]}"
}
get_stop_and_start_dags
stop_dags
start_dags
