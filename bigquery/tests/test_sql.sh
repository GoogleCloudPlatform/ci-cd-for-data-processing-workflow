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

set -e

# $1 is a query string to dry_run
function dry_run_query() {
  bq query \
    --use_legacy_sql=false \
    --dry_run \
    "$1"
}

while IFS= read -r query_file
do
  echo "$query_file"
  dry_run_query "$(render_jinja_if_matching_json "$query_file")"
  result="$?"
  if [ "$result" -ne 0 ]; then
    echo "Failed to dry run $query_file"
    exit "$result"
  fi
done <  <(find ./sql -path "*.sql")

