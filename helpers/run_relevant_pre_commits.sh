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

################################################################################
# Construct and submit  a dynamic cloudbuild yaml file to run the nested       #
# cloud builds for directories containing changes according to git diff master.#
################################################################################

COMMIT_SHA=$(git rev-parse HEAD)

# list of changed files.
DIFF=$(git diff --name-only master)

# Temporary file to define a dynamic cloud build based on changed files.
PRE_COMMIT_BUILD=relevant-pre-commits-for-${COMMIT_SHA}.yaml

# get a list of dirs containin cloud builds and the list of passed files.
# $1 - a  list of files containing changes
function find_relevant_cloud_build_dirs(){
  DIRS_WITH_COULD_BUILD_PATTERN="(^$(find . -type f -path './*/cloudbuild.yaml' -printf '%h|' | sed s#\\./##g | sed s/\|$//g))"
  echo "$1" | grep -oP "$DIRS_WITH_COULD_BUILD_PATTERN" | sort | uniq
}
# utility for adding a line to the working build file
function append_to_build(){
  echo "$1" >> "$PRE_COMMIT_BUILD"
}
# initializes a cloud build file
function init_build() {
  touch "$PRE_COMMIT_BUILD"
  append_to_build "steps:"
}
# loop through the diff and add a step to run each relevant nested cloud build.
function construct_build(){
  for DIR in $DIRS_WITH_DIFF_AND_BUILD
  do
    append_to_build "- id: $DIR"
    append_to_build '  name: google/cloud-sdk'
    append_to_build "  args: ['gcloud', 'builds', 'submit', '$DIR', '--config=$DIR/cloudbuild.yaml']"
    append_to_build "  waitFor: ['-']"  # run nested builds in parallel
  done
  # beef up resources for parallelizaiton
  append_to_build "options:"
  append_to_build "  machineType: 'N1_HIGHCPU_8'"
}
# run the cloud build created in this script
function run() {
  echo "running relevant pre-commits for $COMMIT_SHA"
  cat "$PRE_COMMIT_BUILD"
  gcloud builds submit . --config="$PRE_COMMIT_BUILD"
  BUILD_STATUS=$?
  # clean up
  rm "$PRE_COMMIT_BUILD"
  exit $BUILD_STATUS
}

function main(){
  DIRS_WITH_DIFF_AND_BUILD=$(find_relevant_cloud_build_dirs "$DIFF")
  init_build
  construct_build
  run
}
main