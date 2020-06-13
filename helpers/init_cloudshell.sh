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

echo "downloading terragrunt"
INSTALL_DIR=$(command -v terraform | sed s/terraform/terragrunt/g)
wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.23.25/terragrunt_linux_amd64
mv terragrunt_linux_amd64 "$INSTALL_DIR"
chmod +x "$INSTALL_DIR"
echo "terragrunt install successful!"
terragrunt -version

echo "resetting to java 8"
update-java-alternatives -s java-1.8.0-openjdk-amd64 && export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre
java -version
