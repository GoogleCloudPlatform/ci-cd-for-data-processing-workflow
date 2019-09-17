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
"""Data processing production workflow definition.
"""
import datetime
import os

from airflow import models
from airflow.contrib.operators.bigquery_operator import BigQueryOperator
from airflow.contrib.operators.dataflow_operator import DataFlowJavaOperator

def get_sql_prefix():
    """Gets the appropriate SQL prefix.

    Returns:
        str: If this is a Cloud Composer deployment it will return
        the local sql path synced from GCS.
        If this is running else where it will assume the sql
        is in $AIRFLOW_HOME/gcs/data/sql (this will be the case
        when run_tests.sh runs).
    """
    dags_path = '/home/airflow/gcs/dags/'
    if not os.path.exists(dags_path):
        dags_path = os.path.join(
                   os.environ.get('AIRFLOW_HOME','~/airflow'), 'dags')

    sql_path = os.path.join(dags_path, 'sql')
    if not os.path.exists(sql_path):
        raise EnvironmentError("Could not find SQL path: %s" % sql_path)
    return sql_path

def read_sql(filename):
    """read a sql file as a string
    Args:
        filename: (str) name of sql file.
    Returns:
        (str) : sql string.
    """
    with open(os.path.join(get_sql_prefix(), filename), 'r') as f:
        return f.read()

SHAKESPEARE_SQL = read_sql('shakespeare_top_25.sql')

DATAFLOW_STAGING_BUCKET = 'gs://%s/staging' % (
    models.Variable.get('dataflow_staging_bucket_prod'))

DATAFLOW_JAR_LOCATION = 'gs://%s/%s' % (
    models.Variable.get('dataflow_jar_location_test'),
    models.Variable.get('dataflow_jar_file_test'))

PROJECT = models.Variable.get('gcp_project')
REGION = models.Variable.get('gcp_region')
ZONE = models.Variable.get('gcp_zone')
INPUT_BUCKET = 'gs://' + models.Variable.get('gcs_input_bucket_prod')
OUTPUT_BUCKET_NAME = models.Variable.get('gcs_output_bucket_prod')
OUTPUT_BUCKET = 'gs://' + OUTPUT_BUCKET_NAME
OUTPUT_PREFIX = 'output'
DOWNLOAD_TASK_PREFIX = 'download_result'

YESTERDAY = datetime.datetime.combine(
    datetime.datetime.today() - datetime.timedelta(1),
    datetime.datetime.min.time())

DEFAULT_ARGS = {
    'dataflow_default_options': {
        'project': PROJECT,
        'zone': ZONE,
        'region': REGION,
        'stagingLocation': DATAFLOW_STAGING_BUCKET
    }
}

with models.DAG(
        'prod_word_count',
        schedule_interval=None,
        start_date=YESTERDAY,
        default_args=DEFAULT_ARGS) as dag:

    DATAFLOW_EXECUTION = DataFlowJavaOperator(
        task_id='wordcount-run',
        jar=DATAFLOW_JAR_LOCATION,
        options={
            'autoscalingAlgorithm': 'THROUGHPUT_BASED',
            'maxNumWorkers': '3',
            'inputFile': '{}/input.txt'.format(INPUT_BUCKET),
            'output': '{}/{}'.format(OUTPUT_BUCKET, OUTPUT_PREFIX)
        }
    )

    RUN_QUERY = BigQueryOperator(
        task_id='run-sql',
        sql=SHAKESPEARE_SQL,
        use_legacy_sql=False,
        dag=dag
    )

    RUN_QUERY >> DATAFLOW_EXECUTION
