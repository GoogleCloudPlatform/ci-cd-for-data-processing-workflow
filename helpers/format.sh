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

# This script formats the various files in this repository based on Google open source
# style guidelines. This script is automatically called when running
# "make fmt" at the root of the repository.
#
# NOTE: The files will be formatted in place.
#
# The following languages are currently supported:
# - python (using yapf)

# temporary list of folders to exclude
EXCLUDE_FOLDERS=$(cat helpers/exclusion_list.txt)

while IFS= read -r -d '' FOLDER
do
    if  [[ ! ${EXCLUDE_FOLDERS[*]} =~ $FOLDER ]]
    then
        echo "Formatting $FOLDER"

        echo "Formatting python files (if any)"

        FILES_TO_FORMAT=$(find "$FOLDER" -type f -name "*.py")
        if [[ -n "$FILES_TO_FORMAT" ]]
        then
            # format all python files in place for python2
            

            # If python2 failed, try to format using python3 instead
            if ! python2 -m yapf -i -r --style google "$FILES_TO_FORMAT" > /dev/null 2>&1
            then
                # format all python files in place for python2
                python3 -m yapf -i -r --style google "$FILES_TO_FORMAT" > /dev/null
            fi
        else
            echo "No python files found for $FOLDER - SKIP"
        fi

        echo "Formatting go files (if any)"
        gofmt -w "$FOLDER"

        echo "Formatting terraform files (if any)"
	terraform fmt -r "$FOLDER"

        echo "Formatting java files (if any)"

        FILES_TO_FORMAT=$(find "$FOLDER" -type f -name "*.java")
        if [[ -n "$FILES_TO_FORMAT" ]]
        then
            # format all java files in place
            java -jar /usr/share/java/google-java-format-1.7-all-deps.jar -i "$FILES_TO_FORMAT"
        else
            echo "No java files found for $FOLDER - SKIP"
        fi
    fi
done  < <(find . -maxdepth 1 -mindepth 1 -type d)
