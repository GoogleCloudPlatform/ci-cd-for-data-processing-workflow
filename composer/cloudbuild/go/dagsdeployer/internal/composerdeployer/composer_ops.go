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
	"github.com/bmatcuk/doublestar"
	"io/ioutil"
	"log"
	"math/rand"
	"net/url"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"regexp"
	"source.cloud.google.com/datapipelines-ci/composer/cloudbuild/go/dagsdeployer/internal/gcshasher"
	"strings"
	"sync"
	"time"
)

// ComposerEnv is a lightweight representaataion of Cloud Composer environment
type ComposerEnv struct {
	Name            string
	Project         string
	Location        string
	DagBucketPrefix string
	LocalDagsPrefix string
}

func logDagList(a map[string]bool) {
	for k := range a {
		log.Printf("\t%s", k)
	}
	return
}

// DagList is a set of dags (for quick membership check)
type DagList map[string]bool

// ReadRunningDagsTxt reads a newline separated list of dags from a text file
func ReadRunningDagsTxt(filename string) (map[string]bool, error) {
  dagsToRun := make(map[string]bool)
  scrubbedLines, err := readCommentScrubbedLines(filename)
  if err != nil {
    return dagsToRun, fmt.Errorf("error reading %v: %v", filename, err)
  }
	for _, line := range scrubbedLines{
		dagsToRun[line] = true
	}
	log.Printf("Read dagsToRun from %s:", filename)
	logDagList(dagsToRun)
	return dagsToRun, err
}

// DagListIntersect finds the common keys in two map[string]bool representing a
// list of airflow DAG IDs.
func DagListIntersect(a map[string]bool, b map[string]bool) map[string]bool {
	short := make(map[string]bool)
	long := make(map[string]bool)
	in := make(map[string]bool)

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
	return in
}

// DagListDiff finds the keys in the first map[string]bool that do no appear in
// the second.
func DagListDiff(a map[string]bool, b map[string]bool) map[string]bool {
	diff := make(map[string]bool)
	for k := range a {
		if !b[k] {
			diff[k] = true
		}
	}
	return diff
}

// shell out to call gsutil
func gsutil(args ...string) ([]byte, error) {
	c := exec.Command("gsutil", args...)
	return c.CombinedOutput()
}

func (c *ComposerEnv) assembleComposerRunCmd(subCmd string, args ...string) []string {
	subCmdArgs := []string{
		"composer", "environments", "run",
		c.Name,
		fmt.Sprintf("--location=%s", c.Location),
		subCmd}

	if len(args) > 0 {
		subCmdArgs = append(subCmdArgs, "--")
		subCmdArgs = append(subCmdArgs, args...)
	}
	return subCmdArgs
}

// Run is used to run airflow cli commands
// it is a wrapper of gcloud composer environments run
func (c *ComposerEnv) Run(subCmd string, args ...string) ([]byte, error) {
	subCmdArgs := c.assembleComposerRunCmd(subCmd, args...)
	log.Printf("running gcloud  with subCmd Args: %s", subCmdArgs)
	cmd := exec.Command(
		"gcloud", subCmdArgs...)
	return cmd.CombinedOutput()
}

func parseListDagsOuput(out []byte) map[string]bool {
	runningDags := make(map[string]bool)
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

	return runningDags
}

// GetRunningDags lists dags currently running in Composer Environment.
func (c *ComposerEnv) GetRunningDags() (map[string]bool, error) {
	runningDags := make(map[string]bool)
	out, err := c.Run("list_dags")
	if err != nil {
		log.Fatalf("list_dags failed: %s with %s", err, out)
	}

	runningDags = parseListDagsOuput(out)
	log.Printf("running DAGs:")
	logDagList(runningDags)
	return runningDags, err
}

func readCommentScrubbedLines(path string) ([]string, error) {
	log.Printf("scrubbing comments in %v", path)
	commentPattern, err := regexp.Compile(`#.+`)
	if err != nil {
		return nil, fmt.Errorf("error compiling regex: %v", err)
	}
	file, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("couldn't open file %v: %v", path, err)
	}
	defer file.Close()

	lines := make([]string, 0, 1)
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		candidate := commentPattern.ReplaceAllString(scanner.Text(), "")
		if len(candidate) > 0 {
			lines = append(lines, candidate)
		}
	}
	log.Printf("scrubbed lines: %#v", lines)

	return lines, scanner.Err()
}

// FindDagFilesInLocalTree searches for Dag files in dagsRoot with names in dagNames respecting .airflowignores
func FindDagFilesInLocalTree(dagsRoot string, dagNames map[string]bool) (map[string][]string, error) {
	// temporarily set working dir to dagsRoot
	wd, err := os.Getwd()
	if err != nil {
		return nil, fmt.Errorf("error getting working dir: %v", err)
	}
	os.Chdir(dagsRoot)
	defer os.Chdir(wd)

	if len(dagNames) == 0 {
		return make(map[string][]string), nil
	}
	log.Printf("searching for these DAGs in %v:", dagsRoot)
	logDagList(dagNames)
	matches := make(map[string][]string)
	// This should map a dir to the ignore patterns in it's airflow ignore if relevant
	// this allows us to easily identify the patterns relevant to this dir and it's parents, grandparents, etc.
	airflowignoreTree := make(map[string][]string)
	filepath.Walk('.', func(path string, info os.FileInfo, err error) error {
	  fmt.Printf("%#v", info)
		dagID := strings.TrimSuffix(info.Name(), ".py")
		relPath, err := filepath.Rel(dagsRoot, path)

		// resepect .airflowignore
		if info.Name() == ".airflowignore" {
			log.Printf("found %v, adding to airflowignoreTree", path)
			patterns, err := readCommentScrubbedLines(path)
			if err != nil {
				return err
			}
			dir, err := filepath.Rel(dagsRoot, filepath.Dir(path))
			if err != nil {
				return fmt.Errorf("error making %v relative to dag root %v: %v", filepath.Dir(path), dagsRoot, err)
			}
			fullyQualifiedPatterns := make([]string, 0, len(patterns))
			for _, p := range patterns {
				fullyQualifiedPatterns = append(fullyQualifiedPatterns, filepath.Join(dir, p))
			}
			log.Printf("adding the following patterns to airflowignoreTree[%v]: %+v", dir, fullyQualifiedPatterns)
			airflowignoreTree[filepath.Dir(path)] = fullyQualifiedPatterns
			return nil
		}

		if !info.IsDir() && !dagNames[dagID] { // skip to next file if this is not relevant to dagNames
			return nil
		}

		relevantIgnores := make([]string, 0)
		p := path

		if ignores, ok := airflowignoreTree[p]; ok {
			relevantIgnores = append(relevantIgnores, ignores...)
		}

		// walk back to respect all parents' .airflowignore
		for {
			if p == filepath.Dir(dagsRoot) {
				break
			}
			parent := filepath.Dir(p)
			p = parent                                         // for next iteration.
			if patterns, ok := airflowignoreTree[parent]; ok { // parent has .airflowignore
				relevantIgnores = append(relevantIgnores, patterns...)
			}
		}

		thisMatch := make(map[string]bool)
		if err != nil {
			log.Printf("error making %v relative to %v, %v", path, dagsRoot, err)
			return fmt.Errorf("error making %v relative to %v, %v", path, dagsRoot, err)
		}

		for _, ignore := range relevantIgnores {
			absIgnore, err := filepath.Abs(filepath.Join(".", ignore))
			if err != nil {
				return err
			}
			absPath, err := filepath.Abs(filepath.Join(".", relPath))
			if err != nil {
				return err
			}
			var match bool
			if strings.Contains(absIgnore, "**") {
				match, err = doublestar.PathMatch(absIgnore, absPath)
				if err != nil {
					return err
				}
			}
			if !match && !strings.Contains(ignore, "**") {
				match, err = regexp.MatchString(ignore, relPath)
				if err != nil {
					log.Printf("ERROR: comparing %v %v: %v", relPath, ignore, err)
					return err
				}
			}

			// don't walk dirs we don't have to
			if match && info.IsDir() {
				log.Printf("ignoring dir: %v because matched %v", relPath, ignore)
				return filepath.SkipDir
			}

			// remove matches if previously added but now matches this ignore pattern
			if match && !info.IsDir() && dagNames[dagID] {
				log.Printf("ignoring path: %v because matched %v", relPath, ignore)
				if _, ok := matches[dagID]; ok {
					matches[dagID] = make([]string, 0)
					break // no other ignore patterns relevant if we now know this file should be ignored
				}
				return nil
			}

			// if we shouldn't ignore it and it is in dagNames then add it to matches if not already present
			if !match && !info.IsDir() && dagNames[dagID] {
				thisMatch[dagID] = true
			}
		}

		if thisMatch[dagID] {
			alreadyMatched := false
			for _, p := range matches[dagID] {
				if relPath == p {
					alreadyMatched = true
					break
				}
			}
			if !alreadyMatched {
				log.Printf("new match for %v: %v", dagID, relPath)
				matches[dagID] = append(matches[dagID], relPath)
			}
		}

		return nil
	})

	errs := make([]error, 0)

	// should match exactly one path in the tree.
	for dag, matches := range matches {
		if len(matches) == 0 {
			errs = append(errs, fmt.Errorf("did not find match for %v", dag))
		} else if len(matches) > 1 {
			errs = append(errs, fmt.Errorf("found multiple matches for %v: %v", dag, matches))
		}
	}

	if len(errs) > 0 {
		return matches, fmt.Errorf("Encountered errors matching files to dags: %+v", errs)
	}
	return matches, nil
}

// FindDagFilesInGcsPrefix necessary find the file path of a dag that has been deleted from VCS
func FindDagFilesInGcsPrefix(prefix string, dagFileNames map[string]bool) (map[string][]string, error) {
	dir, err := ioutil.TempDir("", "gcsDags_")
	if err != nil {
		return nil, fmt.Errorf("error creating temp dir to pull gcs dags: %v", err)
	}
	defer os.RemoveAll(dir) // clean up temp dir

	// copy gcs dags dir to local temp dir
	log.Printf("pulling down %v", prefix)
	_, err = gsutil("-m", "cp", "-r", prefix, dir)
	if err != nil {
		return nil, fmt.Errorf("error fetching dags dir from GCS: %v", err)
	}
	return FindDagFilesInLocalTree(filepath.Join(dir, "dags"), dagFileNames)
}

func (c *ComposerEnv) getRestartDags(sameDags map[string]string) map[string]bool {
	dagsToRestart := make(map[string]bool)
	for dag, relPath := range sameDags {
		// We know that the file name = dag id from the dag validation test asseting this.
		local := filepath.Join(c.LocalDagsPrefix, relPath)
		gcs, err := url.Parse(c.DagBucketPrefix)
		gcs.Path = path.Join(gcs.Path, relPath)
		eq, err := gcshasher.LocalFileEqGCS(local, gcs.String())
		if err != nil {
			log.Printf("error comparing file hashes %s, attempting to restart: %s", err, dag)
			dagsToRestart[dag] = true
		} else if !eq {
			dagsToRestart[dag] = true
		}
	}
	return dagsToRestart
}

// Dag is a type for dag containing it's path
type Dag struct {
	ID   string
	Path string
}

// GetStopAndStartDags uses set differences between dags running in the Composer
// Environment and those in the running dags text config file.
func (c *ComposerEnv) GetStopAndStartDags(filename string, replace bool) (map[string]string, map[string]string) {
	dagsToRun, err := ReadRunningDagsTxt(filename)
	if err != nil {
		log.Fatalf("couldn't read running_dags.txt: %v", filename)
	}
	runningDags, err := c.GetRunningDags()
	if err != nil {
		log.Fatalf("couldn't list dags in composer environment: %v", err)
	}
	dagsToStop := DagListDiff(runningDags, dagsToRun)
	dagsToStart := DagListDiff(dagsToRun, runningDags)
	dagsSame := DagListIntersect(runningDags, dagsToRun)
	log.Printf("DAGs same:")
	logDagList(dagsSame)

	dagPathListsSame, err := FindDagFilesInGcsPrefix(c.DagBucketPrefix, dagsToStop)
	if err != nil {
		log.Fatalf("error finding dags to stop: %v", err)
	}
	// unnest out of slice
	dagPathsSame := make(map[string]string)
	for k, v := range dagPathListsSame {
		dagPathsSame[k] = v[0]
	}
	restartDags := c.getRestartDags(dagPathsSame)

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

	dagPathListsToStop, err := FindDagFilesInGcsPrefix(c.DagBucketPrefix, dagsToStop)
	if err != nil {
		log.Fatalf("error finding dags to stop: %v", err)
	}
	dagPathsToStop := make(map[string]string)
	for k, v := range dagPathListsToStop {
		dagPathsToStop[k] = v[0]
	}
	dagPathListsToStart, err := FindDagFilesInLocalTree(c.LocalDagsPrefix, dagsToStart)
	if err != nil {
		log.Fatalf("error finding dags to start: %v", err)
	}

	dagPathsToStart := make(map[string]string)
	for k, v := range dagPathListsToStart {
		dagPathsToStart[k] = v[0]
	}
	return dagPathsToStop, dagPathsToStart
}

// ComposerEnv.stopDag pauses the dag, removes the dag definition file from gcs
// and deletes the DAG from the airflow db.
func (c *ComposerEnv) stopDag(dag string, relPath string, pauseOnly bool, wg *sync.WaitGroup) (err error) {
	defer wg.Done()
	log.Printf("pausing dag: %v with relPath: %v", dag, relPath)
	out, err := c.Run("pause", dag)
	if err != nil {
		return fmt.Errorf("error pausing dag %v: %v", dag, string(out))
	}
	log.Printf("pauseOnly: %#v", pauseOnly)
	log.Printf("!pauseOnly: %#v", !pauseOnly)
	if !pauseOnly {
		log.Printf("parsing gcs url %v", c.DagBucketPrefix)
		gcs, err := url.Parse(c.DagBucketPrefix)
		if err != nil {
			panic("error parsing dag bucket prefix")
		}

		gcs.Path = path.Join(gcs.Path, relPath)
		log.Printf("deleting %v", gcs.String())
		out, err = gsutil("rm", gcs.String())
		if err != nil {
			panic("error deleting from gcs")
		}

		_, err = c.Run("delete_dag", dag)
		if err != nil {
			panic("error deleteing dag")
		}

		for i := 0; i < 5; i++ {
			if err == nil {
				break
			}
			log.Printf("Waiting 5s to retry")
			dur, _ := time.ParseDuration("5s")
			time.Sleep(dur)
			log.Printf("Retrying delete %s", dag)
			_, err = c.Run("delete_dag", dag)
		}
		if err != nil {
			return fmt.Errorf("Retried 5x, pause still failing with: %v", string(out))
		}
	}
	return err
}

// StopDags deletes a list of dags in parallel go routines
func (c *ComposerEnv) StopDags(dagsToStop map[string]string, pauseOnly bool) error {
	var stopWg sync.WaitGroup
	for k, v := range dagsToStop {
		stopWg.Add(1)
		go c.stopDag(k, v, pauseOnly, &stopWg)
	}
	stopWg.Wait()
	return nil
}

func jitter(d time.Duration) time.Duration {
	const pct = 0.10 //Jitter up to 10% of the supplied duration.
	jit := 1 + pct*(rand.Float64()*2-1)
	return time.Duration(jit * float64(d))
}

// ComposerEnv.waitForDeploy polls a Composer environment trying to unpause
// dags. This should be called after copying a dag file to gcs when
// dag_paused_on_creation=True.
func (c *ComposerEnv) waitForDeploy(dag string) error {
	_, err := c.Run("unpause", dag)
	for i := 0; i < 5; i++ {
		if err == nil {
			break
		}
		log.Printf("Waiting 60s to retry")
		time.Sleep(jitter(time.Minute))
		log.Printf("Retrying unpause %s", dag)
		_, err = c.Run("unpause", dag)
	}
	if err != nil {
		err = fmt.Errorf("Retried 5x, unpause still failing with: %s", err)
	}
	return err
}

// ComposerEnv.startDag copies a DAG definition file to GCS and waits until you can
// successfully unpause.
func (c *ComposerEnv) startDag(dagsFolder string, dag string, relPath string, wg *sync.WaitGroup) error {
	defer wg.Done()
	loc := filepath.Join(dagsFolder, relPath)
	gcs, err := url.Parse(c.DagBucketPrefix)
	if err != nil {
		return fmt.Errorf("error parsing dags prefix %v", err)
	}
	gcs.Path = path.Join(gcs.Path, relPath)
	_, err = gsutil("cp", loc, gcs.String())
	if err != nil {
		return fmt.Errorf("error copying file %v to gcs: %v", loc, err)
	}
	c.waitForDeploy(dag)
	return err
}

// StartDags deploys a list of dags in parallel go routines
func (c *ComposerEnv) StartDags(dagsFolder string, dagsToStart map[string]string) error {
	c.Run("unpause", "airflow_monitoring")
	var startWg sync.WaitGroup
	for k, v := range dagsToStart {
		startWg.Add(1)
		go c.startDag(dagsFolder, k, v, &startWg)
	}
	startWg.Wait()
	return nil
}
