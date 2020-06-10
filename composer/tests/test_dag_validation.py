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
"""DAG Quality tests."""

import os
from pathlib import Path
import time
import unittest

from airflow.models import DagBag


class TestDagIntegrity(unittest.TestCase):
    """Tests DAG Syntax, compatibility with environment and load time."""
    LOAD_SECOND_THRESHOLD = 2

    def setUp(self):
        """Setup dagbag for each test."""
        self.dagbag = DagBag(
            dag_folder=os.environ.get('AIRFLOW_HOME', "~/airflow/") + '/dags/',
            include_examples=False)
        with open('./config/ci_dags.txt') as running_dags_txt:
            self.running_dag_ids = running_dags_txt.read().splitlines()

    def test_no_ignore_running_dags(self):
        """
        Tests that we don't have any dags in ci_dags.txt that are
        ignored by .airflowignore
        """
        for dag_id in self.running_dag_ids:
            self.assertTrue(self.dagbag.get_dag(dag_id) is not None)

    def test_import_dags(self):
        """Tests there are no syntax issues or environment compaibility issues.
        """
        self.assertFalse(
            len(self.dagbag.import_errors),
            'DAG import failures. Errors: {}'.format(
                self.dagbag.import_errors))

    def test_non_airflow_owner(self):
        """Tests that owners are set for all dags"""
        for dag_id in self.dagbag.dag_ids:
            if dag_id != 'airflow_monitoring':
                dag = self.dagbag.get_dag(dag_id)
                self.assertIsNotNone(dag.owner)
                self.assertNotEqual(dag.owner, 'airflow')

    def test_same_file_and_dag_id_name(self):
        """Tests that filename matches dag_id"""
        for dag_id in self.dagbag.dag_ids:
            self.assertEqual(
                dag_id,
                Path(self.dagbag.get_dag(dag_id).filepath).name.rstrip(".py"))

    def test_import_time(self):
        """Test that all DAGs can be parsed under the threshold time."""
        for dag_id in self.dagbag.dag_ids:
            start = time.time()

            self.dagbag.process_file(self.dagbag.get_dag(dag_id).filepath)

            end = time.time()
            total = end - start

            self.assertLessEqual(total, self.LOAD_SECOND_THRESHOLD)


if __name__ == "__main__":
    unittest.main()
