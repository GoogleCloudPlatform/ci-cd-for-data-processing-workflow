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

package gcshasher

import (
    "cloud.google.com/go/storage"
    "context"
    "flag"
    "io"
    "os"
    "path/filepath"
    "testing"
)

var testBkt = flag.String("bkt", "", "The bucket to use for testing the hash comparison")

func TestLocalMD5(t *testing.T) {
    locPath := filepath.Join("testdata", "test.txt")
    _, err := localMD5(locPath)
    if err != nil {
        t.Errorf("error hashing local file: %s", err)
    }
}

func TestLocalFileEqGCS(t *testing.T) {
    if *testBkt == "" {
        t.Skip("skipping hash comparison integration test because no test bucket passed")
    }

    locPath := filepath.Join("testdata", "test.txt")
    ctx := context.Background()
    client, err := storage.NewClient(ctx)
    if err != nil {
        t.Errorf("Couldn't authenticate GCS client: %s", err)
    }

    var r io.Reader
    f, err := os.Open(locPath)
    defer f.Close()
    r = f

    obj := client.Bucket(*testBkt).Object("testdata/test.txt")
    w := obj.NewWriter(ctx)
    io.Copy(w, r)
    if err := w.Close(); err != nil {
        t.Errorf("couldn't write test object %s ", err)
    }

    eq, err := LocalFileEqGCS(locPath, "gs://"+*testBkt+"/testdata/test.txt")
    if !eq {
        t.Errorf("hashes were not equal for local test.txt vs gcs test.txt")
    }

    diffLocPath := filepath.Join("testdata", "test_diff.txt")
    eq, err = LocalFileEqGCS(diffLocPath, "gs://"+*testBkt+"/testdata/test.txt")
    if eq {
        t.Errorf("hashes were equal for local test_diff.txt vs gcs test.txt")
    }
    if err := obj.Delete(ctx); err != nil {
        t.Logf("couldn't clean up test object: %s", err)
    }
}
