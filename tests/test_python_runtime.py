# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import unittest
from unittest.mock import patch
from bridge.check_python_runtime import check_modules


class RuntimeChecks(unittest.TestCase):
    def test_standard_library_and_missing_package(self):
        result = check_modules(["json", "inkprof_missing_module_test"])
        self.assertEqual(result["missing"], ["inkprof_missing_module_test"])
        self.assertEqual(result["failures"], [])

    def test_installed_scipy_with_broken_compiled_submodule(self):
        def load(name):
            if name == "scipy.spatial":
                raise ImportError("__thread_bss has a zero-fill section type, but offset field is not zero")
            return object()
        with patch("bridge.check_python_runtime.importlib.import_module", side_effect=load):
            result = check_modules(["scipy"])
        self.assertEqual(result["missing"], [])
        self.assertEqual(result["failures"][0]["module"], "scipy")
        self.assertIn("__thread_bss", result["failures"][0]["message"])

    def test_missing_transitive_dependency_is_import_failure(self):
        with patch("bridge.check_python_runtime.importlib.import_module",
                   side_effect=ModuleNotFoundError("missing dependency", name="another_package")):
            result = check_modules(["scipy"])
        self.assertEqual(result["missing"], [])
        self.assertEqual(result["failures"][0]["module"], "scipy")
