// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package composerdeployer

import (
	"bufio"
	"fmt"
	"log"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"source.cloud.google.com/datapipelines-ci/composer/cloudbuild/go/dagsdeployer/internal/gcshasher"
	"strings"
	"sync"
	"time"
)

// ComposerEnv is a lightweight representaataion of Cloud Composer environment
type ComposerEnv struct {
	Name                string
	Location            string
	DagBucketPrefix     string
	LocalComposerPrefix string
}

func logDagList(a map[string]bool) {
	for k := range a {
		log.Printf("\t%s", k)
	}
	return
}

type DagList map[string]bool

// ReadRunningDagsTxt reads a newline separated list of dags from a text file
func ReadRunningDagsTxt(filename string) (dagsToRun map[string]bool, err error) {
	file, err := os.Open(filename)
	if err != nil {
		return
	}
	defer file.Close()

	dagsToRun = make(map[string]bool)
	sc := bufio.NewScanner(file)

	for sc.Scan() {
		dagsToRun[sc.Text()] = true
	}
	log.Printf("Read dagsToRun from %s:", filename)
	logDagList(dagsToRun)
	return
}

// DagListIntersect finds the common keys in two map[string]bool representing a
// list of airflow DAG IDs.
func DagListIntersect(a map[string]bool, b map[string]bool) (in map[string]bool) {
	short := make(map[string]bool)
	long := make(map[string]bool)
	in = make(map[string]bool)

	if len(a) < len(b) {
		short, long = a, b
	} else {
		short, long = b, a
	}
	for k := range short {
		if long[k] {
			in[k] = true
		}
	}
	return
}

// DagListDiff finds the keys in the first map[string]bool that do no appear in
// the second.
func DagListDiff(a map[string]bool, b map[string]bool) (diff map[string]bool) {
	diff = make(map[string]bool)
	for k := range a {
		if !b[k] {
			diff[k] = true
		}
	}
	return
}

// shell out to call gsutil
func gsutil(args ...string) ([]byte, error) {
	c := exec.Command("gsutil", args...)
	return c.CombinedOutput()
}

func (c ComposerEnv) assembleComposerRunCmd(subCmd string, args ...string) (subCmdArgs []string) {
	subCmdArgs = []string{
		"composer", "environments", "run",
		c.Name,
		fmt.Sprintf("--location=%s", c.Location),
		subCmd}

	if len(args) > 0 {
		subCmdArgs = append(subCmdArgs, "--")
		subCmdArgs = append(subCmdArgs, args...)
	}
	return
}

// ComposerEnv.Run is used to run airflow cli commands
// it is a wrapper of gcloud composer environments run
func (c ComposerEnv) Run(subCmd string, args ...string) (out []byte, err error) {
	subCmdArgs := c.assembleComposerRunCmd(subCmd, args...)
	log.Printf("running gcloud  with subCmd Args: %s", subCmdArgs)
	cmd := exec.Command(
		"gcloud", subCmdArgs...)
	return cmd.CombinedOutput()
}

func parseListDagsOuput(out []byte) (runningDags map[string]bool) {
	runningDags = make(map[string]bool)
	outArr := strings.Split(string(out[:]), "\n")

	// Find the DAGs in output
	dagSep := "-------------------------------------------------------------------"
	var dagsIdx, nSep int

	for nSep < 2 {
		if outArr[dagsIdx] == dagSep {
			nSep++
		}
		dagsIdx++
		if dagsIdx >= len(outArr) {
			log.Fatalf("list_dags output did not contain expected separators: %s", out)
		}
	}

	// Ignore empty newline and airflow_monitoring dag.
	for _, dag := range outArr[dagsIdx:] {
		if dag != "" && dag != "airflow_monitoring" {
			runningDags[dag] = true
		}
	}

	return
}

// ComposerEnv.GetRunnningDags lists dags currently running in Composer Environment.
func (c ComposerEnv) GetRunningDags() (runningDags map[string]bool, err error) {
	runningDags = make(map[string]bool)
	out, err := c.Run("list_dags")
	if err != nil {
		log.Fatalf("list_dags failed: %s with %s", err, out)
	}

	runningDags = parseListDagsOuput(out)
	log.Printf("running DAGs:")
	logDagList(runningDags)
	return
}

func (c ComposerEnv) getRestartDags(sameDags map[string]bool) (dagsToRestart map[string]bool) {
	dagsToRestart = make(map[string]bool)
	for dag := range sameDags {
		local := filepath.Join(c.LocalComposerPrefix, "dags", dag+".py")
		gcs := filepath.Join(c.DagBucketPrefix, dag)

		eq, err := gcshasher.LocalFileEqGCS(local, gcs)
		if err != nil {
			log.Printf("error comparing file hashes %s, attempting to restart: %s", err, dag)
			dagsToRestart[dag] = true
		} else if !eq {
			dagsToRestart[dag] = true
		}
	}
	return

}

// ComposerEnv.GetStopAndStartDags uses set differences between dags running in the Composer
// Environment and those in the running dags text config file.
func (c ComposerEnv) GetStopAndStartDags(filename string, replace bool) (dagsToStop map[string]bool, dagsToStart map[string]bool) {
	dagsToRun, err := ReadRunningDagsTxt(filename)
	if err != nil {
		log.Fatalf("couldn't read running_dags.txt: %v", filename)
	}
	runningDags, err := c.GetRunningDags()
	if err != nil {
		log.Fatal("couldn't list dags in composer environment")
	}
	dagsToStop = DagListDiff(runningDags, dagsToRun)
	dagsToStart = DagListDiff(dagsToRun, runningDags)
	dagsSame := DagListIntersect(runningDags, dagsToRun)
	log.Printf("DAGs same:")
	logDagList(dagsSame)

	restartDags := c.getRestartDags(dagsSame)

	if replace {
		for k, v := range restartDags {
			dagsToStop[k], dagsToStart[k] = v, v
		}
	} else {
		log.Fatalf("FAILED: tried to overwite DAGs in place put replace=false the following existing dags: %#v", restartDags)
	}

	log.Printf("DAGs to Stop:")
	logDagList(dagsToStop)
	log.Printf("DAGs to Start:")
	logDagList(dagsToStart)

	return
}

// ComposerEnv.stopDag pauses the dag, removes the dag definition file from gcs
// and deletes the DAG from the airflow db.
func (c ComposerEnv) stopDag(dag string, wg *sync.WaitGroup) (err error) {
	c.Run("pause", dag)
	gsutil("rm", c.DagBucketPrefix+dag+".py")
	c.Run("delete_dag", dag)
	for i := 0; i < 5; i++ {
		if err == nil {
			break
		}
		log.Printf("Waiting 5s to retry")
		dur, _ := time.ParseDuration("5s")
		time.Sleep(dur)
		log.Printf("Retrying delete %s", dag)
		c.Run("delete_dag", dag)
	}
	if err != nil {
		return fmt.Errorf("Retried 5x, unpause still failing with: %s", err)
	}
	wg.Done()
	return
}

// ComposerEnv.StopDags deletes a list of dags in parallel go routines
func (c ComposerEnv) StopDags(dagsToStop map[string]bool) error {
	var stopWg sync.WaitGroup
	for k := range dagsToStop {
		stopWg.Add(1)
		go c.stopDag(k, &stopWg)
	}
	stopWg.Wait()
	return nil
}

func jitter(d time.Duration) time.Duration {
	const jitter = 0.10 //Jitter up to 20% of the supplied duration.
	jit := 1 + jitter*(rand.Float64()*2-1)
	return time.Duration(jit * float64(d))
}

// ComposerEnv.waitForDeploy polls a Composer environment trying to unpause
// dags. This should be called after copying a dag file to gcs when
// dag_paused_on_creation=True.
func (c ComposerEnv) waitForDeploy(dag string) (out []byte, err error) {
	out, err = c.Run("unpause", dag)
	for i := 0; i < 5; i++ {
		if err == nil {
			break
		}
		log.Printf("Waiting 60s to retry")
		dur, _ := time.ParseDuration("60s")
		time.Sleep(jitter(dur))
		log.Printf("Retrying unpause %s", dag)
		out, err = c.Run("unpause", dag)
	}
	if err != nil {
		err = fmt.Errorf("Retried 5x, unpause still failing with: %s", err)
		return
	}
	return
}

// ComposerEnv.startDag copies a DAG definition file to GCS and waits until you can
// successfully unpause.
func (c ComposerEnv) startDag(repoRoot string, dag string, wg *sync.WaitGroup) (err error) {
	gsutil("cp", filepath.Join(repoRoot, "composer", "dags", dag+".py"), c.DagBucketPrefix)
	c.waitForDeploy(dag)
	wg.Done()
	return
}

// ComposerEnv.startDags deploys a list of dags in parallel go routines
func (c ComposerEnv) StartDags(repoRoot string, dagsToStart map[string]bool) error {
	var startWg sync.WaitGroup
	for k := range dagsToStart {
		startWg.Add(1)
		go c.startDag(repoRoot, k, &startWg)
	}
	startWg.Wait()
	return nil
}
