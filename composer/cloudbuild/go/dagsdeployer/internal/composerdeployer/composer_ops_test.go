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
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

// test dag lists
var ab = map[string]bool{"a": true, "b": true}

var ac = map[string]bool{"a": true, "c": true}

var a = map[string]bool{"a": true}

var d = map[string]bool{"d": true}

func TestDagListIntersect(t *testing.T) {

	testTable := []struct {
		a   map[string]bool
		b   map[string]bool
		out map[string]bool
	}{
		{ab, ac, map[string]bool{"a": true}},
		{ac, ab, map[string]bool{"a": true}}, // commutative
		{ab, ab, ab},                         // identity
		{ab, a, a},
		{a, ab, a},
		{ab, d, make(map[string]bool)}}

	for _, tt := range testTable {
		t.Run(fmt.Sprintf("%+v", tt), func(t *testing.T) {
			if got := DagListIntersect(tt.a, tt.b); !reflect.DeepEqual(got, tt.out) {
				t.Errorf("DagListIntersect(%+v, %+v) = %+v, want %+v", tt.a, tt.b, got, tt.out)
			}
		})
	}
}

func TestDagListDiff(t *testing.T) {

	testTable := []struct {
		a   map[string]bool
		b   map[string]bool
		out map[string]bool
	}{
		{ab, ac, map[string]bool{"b": true}},
		{ac, ab, map[string]bool{"c": true}}, // commutative
		{ab, ab, make(map[string]bool)},
		{ab, a, map[string]bool{"b": true}},
		{a, ab, make(map[string]bool)},
		{ab, d, ab},
		{d, ab, d}}

	for _, tt := range testTable {
		t.Run(fmt.Sprintf("%+v, %+v", tt.a, tt.b), func(t *testing.T) {
			if got := DagListDiff(tt.a, tt.b); !reflect.DeepEqual(got, tt.out) {
				t.Errorf("DagListDiff(%+v, %+v) = %+v, want %+v", tt.a, tt.b, got, tt.out)
			}
		})
	}

}

func TestAssembleComposerRunCmd(t *testing.T) {
	c := ComposerEnv{
		Name:            "composerenv",
		Location:        "us-central1",
		DagBucketPrefix: "gs://composerenv-bucket/dags/",
	}
	// Test single command.
	want := []string{
		"composer", "environments", "run",
		"composerenv",
		"--location=us-central1",
		"list_dags"}

	got := c.assembleComposerRunCmd("list_dags")
	if !reflect.DeepEqual(got, want) {
		t.Errorf("ComposerEnv.assembleComposerrRunCmd(\"list_dags\") = %+v, want %+v", got, want)
	}

	// Test command w/ arguments
	want = []string{
		"composer", "environments", "run",
		"composerenv",
		"--location=us-central1",
		"variables", "--", "import", "AirflowVariables.json"}

	got = c.assembleComposerRunCmd("variables", "import", "AirflowVariables.json")
	if !reflect.DeepEqual(got, want) {
		t.Errorf("ComposerEnv.assembleComposerrRunCmd(\"variables\", \"import\", \"AirflowVariables.json\") = %+v, want %+v", got, want)
	}
}

func populateAirflowIgnore(path string, ignores []string) error {
	f, err := os.OpenFile(filepath.Join(path, ".airflowignore"), os.O_RDWR|os.O_CREATE, 0755)
	if err != nil {
		return err
	}
	defer f.Close()
	for _, ignore := range ignores {
		_, err := f.WriteString(ignore + "\n")
		if err != nil {
			panic(fmt.Sprintf("couldn't write %v to %v: %v", ignore, f, err))
		}
	}
	return nil
}

func prepareTestTempDirTree() (string, error) {
	tmpDir, err := ioutil.TempDir("", "")
	if err != nil {
		return "", fmt.Errorf("error creating temp dir: %v", err)
	}

	// create dir tree
	for _, p := range []string{
		"team1/usecase1/sql",
		"team1/helpers/utils",
		"team2/usecase1/",
		"team2/usecase2/",
		"team2/helpers/"} {
		err = os.MkdirAll(filepath.Join(tmpDir, p), 0755)
		if err != nil {
			return tmpDir, err
		}
	}

	// add some files
	for _, name := range []string{
		".airflowignore",
		"team1/.airflowignore",
		"team1/usecase1/sql/foo.sql",
		"team1/usecase1/sql/dag1.py",  // sometimes people define sql in python files as constants (should be ignored in dag finding)
		"team1/helpers/create_dag.py", // some dag generation helper utility (should be ignored in dag finding)
		"team1/usecase1/dag1.py",
		"team1/usecase1/dag2.py",
		"team2/usecase1/create_dag.py", // conflicts with utility file in team1/helpers, but should be ok as that was ignored.
		"team2/usecase2/dag2.py",       // uh-oh a real dag name conflict! (we will that this fails in second test)
		"team2/helpers/helper_dag.py",  // this should not be ignored as team2 follows a different convention.
	} {
		f, err := os.Create(filepath.Join(tmpDir, name))
		if err != nil {
			f.Close()
			return tmpDir, err
		}
	}

	// add some contents to .airflowignore files
	populateAirflowIgnore(tmpDir, []string{"./**/sql/"})                        // ignore sql/ dirs throughout the tree
	populateAirflowIgnore(filepath.Join(tmpDir, "team1"), []string{"helpers/"}) // ignore helpers/ dir under team1
	return tmpDir, nil
}

func TestFindDagFilesInLocalTree(t *testing.T) {
	tmpDir, err := prepareTestTempDirTree()
	defer os.RemoveAll(tmpDir)
	if err != nil {
		t.Errorf("couldn't initialize test dir tree: %v", err)
	}

	// look for the dags we know not to have name conflicts.
	got, err := FindDagFilesInLocalTree(tmpDir, map[string]bool{
		"helper_dag": true,
		"create_dag": true,
		"dag1":       true,
	})

	want := map[string][]string{
		"helper_dag": []string{"team2/helpers/helper_dag.py"},
		"create_dag": []string{"team2/usecase1/create_dag.py"},
		"dag1":       []string{"team1/usecase1/dag1.py"},
	}

	if !reflect.DeepEqual(got, want) {
		t.Errorf("got: %+v,\n want %+v", got, want)
	}

	// test w/ name conflict
	_, err = FindDagFilesInLocalTree(tmpDir, map[string]bool{
		"dag2": true,
	})

	if err == nil {
		t.Errorf("should error on duplicate dag names but didn't")
	}
}
