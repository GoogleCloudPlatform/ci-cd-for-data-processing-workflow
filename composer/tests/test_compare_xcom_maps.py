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
import mock

# pylint: disable=import-error
from plugins.xcom_utils_plugin.operators.compare_xcom_maps import \
    CompareXComMapsOperator

TASK_ID = 'test_compare_task_id'
REF_TASK_ID = 'download_ref_string'
DOWNLOAD_TASK_PREFIX = 'download_result'
CONTEXT_CLASS_NAME = 'airflow.ti_deps.dep_context'
ERROR_LINE_ONE = 'The result differs from expected in the following ways:\n'


def generate_mock_function(first_value, second_value, third_value):
    """Mock dictionary for XCom."""

    def mock_function(**kwargs):
        return {
            REF_TASK_ID: 'a: 1\nb: 2\nc: 3',
            DOWNLOAD_TASK_PREFIX + '_1': first_value,
            DOWNLOAD_TASK_PREFIX + '_2': second_value,
            DOWNLOAD_TASK_PREFIX + '_3': third_value
        }[kwargs['task_ids']]

    return mock_function


def equal_mock():
    """Mocks no change."""
    return generate_mock_function('c: 3', 'b: 2', 'a: 1')


def missing_value_mock():
    """Mock missing key."""
    return generate_mock_function('b: 2', 'a: 1', 'b: 2')


def wrong_value_mock():
    """Mock wrong value."""
    return generate_mock_function('a: 1', 'b: 4', 'c: 3')


def unexpected_value_mock():
    """Mock wrong key."""
    return generate_mock_function('a: 1', 'c: 3\nd: 4', 'b: 2')


class CompareXComMapsOperatorTest(unittest.TestCase):
    """Test class for XComMapsOperator for success case and various
    error handling."""

    def setUp(self):
        """Set up test fixture."""
        super(CompareXComMapsOperatorTest, self).setUp()
        self.xcom_compare = CompareXComMapsOperator(
            task_id=TASK_ID,
            ref_task_ids=[REF_TASK_ID],
            res_task_ids=[
                DOWNLOAD_TASK_PREFIX + '_1', DOWNLOAD_TASK_PREFIX + '_2',
                DOWNLOAD_TASK_PREFIX + '_3'
            ])

    def test_init(self):
        """Test the Operator's constructor."""
        self.assertEqual(self.xcom_compare.task_id, TASK_ID)
        self.assertListEqual(self.xcom_compare.ref_task_ids, [REF_TASK_ID])
        self.assertListEqual(self.xcom_compare.res_task_ids, [
            DOWNLOAD_TASK_PREFIX + '_1', DOWNLOAD_TASK_PREFIX + '_2',
            DOWNLOAD_TASK_PREFIX + '_3'
        ])

    def assert_raises_with_message(self, error_type, msg, func, *args,
                                   **kwargs):
        """Utility method for asserting a message was produced."""
        with self.assertRaises(error_type) as context:
            func(*args, **kwargs)
        self.assertEqual(msg, str(context.exception))

    def execute_value_error(self, mock_func, error_expect_tr):
        """Utility for testing various ValueError paths."""
        with mock.patch(CONTEXT_CLASS_NAME) as context_mock:
            context_mock['ti'].xcom_pull = mock_func
            self.assert_raises_with_message(ValueError, error_expect_tr,
                                            self.xcom_compare.execute,
                                            context_mock)

    def test_equal(self):
        """Test success case."""
        with mock.patch(CONTEXT_CLASS_NAME) as context_mock:
            context_mock['ti'].xcom_pull = equal_mock()
            self.xcom_compare.execute(context_mock)

    def test_missing_value(self):
        """Test expected error message when missing key."""
        self.execute_value_error(
            missing_value_mock(), '{}{}'.format(ERROR_LINE_ONE,
                                                'missing key: c in result'))

    def test_wrong_value(self):
        """Test expected error message if xcom values don't match."""
        self.execute_value_error(
            wrong_value_mock(), '{}{}'.format(ERROR_LINE_ONE,
                                              'expected b: 2 but got b: 4'))

    def test_unexpected_value(self):
        """Test expected error message if xcom contains unexpected key."""
        self.execute_value_error(
            unexpected_value_mock(),
            '{}{}'.format(ERROR_LINE_ONE, 'unexpected key: d in result'))


SUITE = unittest.TestLoader().loadTestsFromTestCase(CompareXComMapsOperatorTest)

unittest.TextTestRunner(verbosity=2).run(SUITE)
