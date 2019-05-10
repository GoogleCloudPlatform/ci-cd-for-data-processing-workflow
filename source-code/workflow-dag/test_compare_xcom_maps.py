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
"""Unit test of the CompareXComMapsOperator.
"""
import unittest
from compare_xcom_maps import CompareXComMapsOperator
import mock

TASK_ID = 'test_compare_task_id'
REF_TASK_ID = 'download_ref_string'
DOWNLOAD_TASK_PREFIX = 'download_result'
CONTEXT_CLASS_NAME = 'airflow.ti_deps.dep_context'
ERROR_LINE_ONE = 'The result differs from the expected in the following ways:\n'


def generate_mock_function(first_value, second_value, third_value):
  def mock_function(**kwargs):
    return {
        REF_TASK_ID: 'a: 1\nb: 2\nc: 3',
        DOWNLOAD_TASK_PREFIX+'_1': first_value,
        DOWNLOAD_TASK_PREFIX+'_2': second_value,
        DOWNLOAD_TASK_PREFIX+'_3': third_value
    }[kwargs['task_ids']]
  return mock_function


def equal_mock():
  return generate_mock_function('c: 3', 'b: 2', 'a: 1')


def missing_value_mock():
  return generate_mock_function('b: 2', 'a: 1', 'b: 2')


def wrong_value_mock():
  return generate_mock_function('a: 1', 'b: 4', 'c: 3')


def unexpected_value_mock():
  return generate_mock_function('a: 1', 'c: 3\nd: 4', 'b: 2')


class CompareXComMapsOperatorTest(unittest.TestCase):

  def setUp(self):
    super(CompareXComMapsOperatorTest, self).setUp()
    self.xcom_compare = CompareXComMapsOperator(
        task_id=TASK_ID,
        ref_task_ids=[REF_TASK_ID],
        res_task_ids=[DOWNLOAD_TASK_PREFIX+'_1',
                      DOWNLOAD_TASK_PREFIX+'_2',
                      DOWNLOAD_TASK_PREFIX+'_3'])

  def test_init(self):
    self.assertEqual(self.xcom_compare.task_id, TASK_ID)
    self.assertListEqual(self.xcom_compare.ref_task_ids, [REF_TASK_ID])
    self.assertListEqual(self.xcom_compare.res_task_ids,
                         [DOWNLOAD_TASK_PREFIX+'_1',
                          DOWNLOAD_TASK_PREFIX+'_2',
                          DOWNLOAD_TASK_PREFIX+'_3'])

  def assertRaisesWithMessage(self, error_type, msg, func, *args, **kwargs):
    with self.assertRaises(error_type) as context:
      func(*args, **kwargs)
    self.assertEqual(msg, str(context.exception))

  def execute_value_error(self, mock_func, error_expect_tr):
    with mock.patch(CONTEXT_CLASS_NAME) as context_mock:
      context_mock['ti'].xcom_pull = mock_func
      self.assertRaisesWithMessage(
          ValueError,
          error_expect_tr,
          self.xcom_compare.execute, context_mock)

  def test_equal(self):
    with mock.patch(CONTEXT_CLASS_NAME) as context_mock:
      context_mock['ti'].xcom_pull = equal_mock()
      self.xcom_compare.execute(context_mock)

  def test_missing_value(self):
    self.execute_value_error(
        missing_value_mock(),
        '{}{}'.format(ERROR_LINE_ONE, 'missing key: c in result'))

  def test_wrong_value(self):
    self.execute_value_error(
        wrong_value_mock(),
        '{}{}'.format(ERROR_LINE_ONE, 'expected b: 2 but got b: 4'))

  def test_unexpected_value(self):
    self.execute_value_error(
        unexpected_value_mock(),
        '{}{}'.format(ERROR_LINE_ONE, 'unexpected key: d in result'))

suite = unittest.TestLoader().loadTestsFromTestCase(CompareXComMapsOperatorTest)
unittest.TextTestRunner(verbosity=2).run(suite)
