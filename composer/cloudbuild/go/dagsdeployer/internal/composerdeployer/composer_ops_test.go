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
