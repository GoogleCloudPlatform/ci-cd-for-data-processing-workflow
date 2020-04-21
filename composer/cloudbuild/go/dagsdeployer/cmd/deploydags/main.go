// Copyright 2019 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//         http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and

package main

import (
  "flag"
  "log"
  "source.cloud.google.com/datapipelines-ci/composer/cloudbuild/go/dagsdeployer/internal/composerdeployer"
)

func main() {

  var dagsFolder, dagList, projectID, composerRegion, composerEnvName, dagBucketPrefix string
  var replace bool

  flag.StringVar(&dagList, "dagList", "./config/running_dags.txt", "path to the list of dags that should be running after the deploy")
  flag.StringVar(&dagsFolder, "dagsFolder", "./dags", "path to the dags folder in the repo.")
  flag.StringVar(&projectID, "project", "", "gcp project id")
  flag.StringVar(&composerRegion, "region", "", "project")
  flag.StringVar(&composerEnvName, "composerEnv", "", "Composer environment name")
  flag.StringVar(&dagBucketPrefix, "dagBucketPrefix", "", "Composer DAGs bucket prefix")
  flag.BoolVar(&replace, "replace", false, "Boolean flag to indicatae if source dag mismatches the object of same name in GCS delte the old version and deploy over it")

  flag.Parse()

  flags := map[string]string{
    "dagsFolder":      dagsFolder,
    "dagList":         dagList,
    "projectID":       projectID,
    "composerRegion":  composerRegion,
    "composerEnvName": composerEnvName,
    "dagBucketPrefix": dagBucketPrefix,
  }

  // Check flags are not empty.
  for k, v := range flags {
    if v == "" {
      log.Panicf("%v must not be empty.", k)
    }
  }

  c := composerdeployer.ComposerEnv{
    Name:                composerEnvName,
    Project:             projectID,
    Location:            composerRegion,
    DagBucketPrefix:     dagBucketPrefix,
    LocalDagsPrefix: "./dags"}

  dagsToStop, dagsToStart := c.GetStopAndStartDags(dagList, replace)
  c.StopDags(dagsToStop, !replace)
  c.StartDags(dagsFolder, dagsToStart)
}
