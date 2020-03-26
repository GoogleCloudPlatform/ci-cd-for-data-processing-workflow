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
"""Defines Plugin for XCom Operators."""

from typing import Any, List
from airflow.plugins_manager import AirflowPlugin

# Allow unittests to easily import.
try:
    from xcom_utils_plugin.operators.compare_xcom_maps import \
        CompareXComMapsOperator
except ModuleNotFoundError:
    from plugins.xcom_utils_plugin.operators.compare_xcom_maps import \
        CompareXComMapsOperator


class XComUtilsPlugin(AirflowPlugin):
    """Plugin to define operators perform common logic on XComs.
    Operators:
        CompareXComMapsOperator: An Operator that checks the equality
            of XComs.
    """
    name = "xcom_utils_plugin"
    operators = [CompareXComMapsOperator]
    hooks: List[Any] = []
    executors: List[Any] = []
    macros: List[Any] = []
    admin_views: List[Any] = []
    flask_blueprints: List[Any] = []
    menu_links: List[Any] = []
