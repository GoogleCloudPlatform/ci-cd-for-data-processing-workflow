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
"""Data processing test workflow definition.
"""

import datetime
import os
from airflow import models
from airflow.contrib.operators.bigquery_operator import BigQueryOperator
from airflow.contrib.operators.dataflow_operator import DataFlowJavaOperator
from airflow.contrib.operators.gcs_download_operator import \
    GoogleCloudStorageDownloadOperator
# pylint: disable=import-error
from airflow.operators.xcom_utils_plugin import CompareXComMapsOperator

DATAFLOW_STAGING_BUCKET = 'gs://{{ var.value.dataflow_staging_bucket }}/staging'

DATAFLOW_JAR_LOCATION = ('gs://{{ var.value.dataflow_jar_location }}'
                         '/{{ var.dataflow_word_count_jar }}')

PROJECT = models.Variable.get('gcp_project')
REGION = models.Variable.get('gcp_region')
INPUT_BUCKET = 'gs://' + models.Variable.get('gcs_input_bucket')
OUTPUT_BUCKET_NAME = models.Variable.get('gcs_output_bucket')
OUTPUT_BUCKET = 'gs://' + OUTPUT_BUCKET_NAME
REF_BUCKET = models.Variable.get('gcs_ref_bucket')
OUTPUT_PREFIX = 'output'
DOWNLOAD_TASK_PREFIX = 'download_result'

# Dynamic prefix gives us flexibility for running airflow in a ci container or
# on composer.
SQL_PREFIX = os.path.join(os.environ.get('AIRFLOW_HOME', '/home/airflow'),
                          'gcs', 'data', 'sql')

SHAKESPEARE_SQL = os.path.join(SQL_PREFIX, 'shakespeare_top_25.sql')

YESTERDAY = datetime.datetime.combine(
    datetime.datetime.today() - datetime.timedelta(1),
    datetime.datetime.min.time())

DEFAULT_ARGS = {
    'owner': 'jferriero@google.com',
    'dataflow_default_options': {
        'project': PROJECT,
        'region': REGION,
        'stagingLocation': DATAFLOW_STAGING_BUCKET
    }
}

with models.DAG('wordcount_dag',
                start_date=YESTERDAY,
                schedule_interval=None,
                default_args=DEFAULT_ARGS) as dag:

    DATAFLOW_EXECUTION = DataFlowJavaOperator(
        task_id='wordcount-run',
        jar=DATAFLOW_JAR_LOCATION,
        options={
            'autoscalingAlgorithm': 'THROUGHPUT_BASED',
            'maxNumWorkers': '3',
            'inputFile': f'{INPUT_BUCKET}/input.txt',
            'output': f'{OUTPUT_BUCKET}/{OUTPUT_PREFIX}'
        })

    DOWNLOAD_EXPECTED = GoogleCloudStorageDownloadOperator(
        task_id='download_ref_string',
        bucket=REF_BUCKET,
        object='ref.txt',
        store_to_xcom_key='ref_str',
    )

    DOWNLOAD_RESULT_ONE = GoogleCloudStorageDownloadOperator(
        task_id=DOWNLOAD_TASK_PREFIX + '_1',
        bucket=OUTPUT_BUCKET_NAME,
        object=OUTPUT_PREFIX + '-00000-of-00003',
        store_to_xcom_key='res_str_1',
    )

    DOWNLOAD_RESULT_TWO = GoogleCloudStorageDownloadOperator(
        task_id=DOWNLOAD_TASK_PREFIX + '_2',
        bucket=OUTPUT_BUCKET_NAME,
        object=OUTPUT_PREFIX + '-00001-of-00003',
        store_to_xcom_key='res_str_2',
    )

    DOWNLOAD_RESULT_THREE = GoogleCloudStorageDownloadOperator(
        task_id=DOWNLOAD_TASK_PREFIX + '_3',
        bucket=OUTPUT_BUCKET_NAME,
        object=OUTPUT_PREFIX + '-00002-of-00003',
        store_to_xcom_key='res_str_3',
    )

    COMPARE_RESULT = CompareXComMapsOperator(
        task_id='do_comparison',
        ref_task_ids=['download_ref_string'],
        res_task_ids=[
            DOWNLOAD_TASK_PREFIX + '_1', DOWNLOAD_TASK_PREFIX + '_2',
            DOWNLOAD_TASK_PREFIX + '_3'
        ],
    )
    RUN_QUERY = BigQueryOperator(task_id='run_sql', sql=SHAKESPEARE_SQL)

    RUN_QUERY >> DATAFLOW_EXECUTION  # pylint: disable=pointless-statement
    DATAFLOW_EXECUTION.set_downstream(
        [DOWNLOAD_RESULT_ONE, DOWNLOAD_RESULT_TWO, DOWNLOAD_RESULT_THREE])

    COMPARE_RESULT.set_upstream([
        DOWNLOAD_EXPECTED, DOWNLOAD_RESULT_ONE, DOWNLOAD_RESULT_TWO,
        DOWNLOAD_RESULT_THREE
    ])
