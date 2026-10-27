"""Offline tests for check_notebook: sample notebooks are written to a temp directory."""

import json
import tempfile
import unittest
from pathlib import Path

import check_notebook


def notebook(cells, nbformat=4):
    return {"nbformat": nbformat, "nbformat_minor": 5, "metadata": {}, "cells": cells}


def code(source, outputs=None, execution_count=None):
    return {"cell_type": "code", "id": "c1", "metadata": {}, "source": source,
            "outputs": outputs or [], "execution_count": execution_count}


class CheckNotebookTest(unittest.TestCase):
    def check(self, data):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "n.ipynb"
            path.write_text(data if isinstance(data, str) else json.dumps(data))
            return check_notebook.check(path)

    def test_clean_notebook_has_no_problems(self):
        self.assertEqual(self.check(notebook([code("print('hello')")])), [])

    def test_invalid_json_is_reported(self):
        self.assertTrue(self.check("{not json"))

    def test_wrong_nbformat_is_reported(self):
        self.assertTrue(self.check(notebook([], nbformat=3)))

    def test_saved_outputs_are_reported_with_the_cell_number(self):
        problems = self.check(notebook([code("1", outputs=[{"output_type": "stream", "text": ["x"]}])]))
        self.assertTrue(any("cell 0" in p and "output" in p for p in problems))

    def test_execution_counts_are_reported(self):
        self.assertTrue(self.check(notebook([code("1", execution_count=3)])))

    def test_secret_looking_text_is_reported_without_echoing_it(self):
        samples = [
            'api_key = "ABCDEFGHIJKLMNOP"',
            "cluster = 'lkc-abc123'",
            "env = 'env-ab12cd'",
            "org = '11111111-2222-3333-4444-555555555555'",
            "headers = {'Authorization': 'Bearer abc'}",
        ]
        for sample in samples:
            problems = self.check(notebook([code(sample)]))
            self.assertTrue(problems, sample)
            for problem in problems:
                self.assertNotIn("ABCDEFGHIJKLMNOP", problem)
                self.assertNotIn("abc123", problem)

    def test_calls_that_write_to_the_catalog_are_reported(self):
        for call in ("catalog.create_table('x', schema)", "table.overwrite(df)",
                     "catalog.drop_table('a.b')", "catalog.create_namespace('n')"):
            problems = self.check(notebook([code(call)]))
            self.assertTrue(any("writes to the catalog" in p for p in problems), call)

    def test_read_calls_are_allowed(self):
        self.assertEqual(
            self.check(notebook([code("t = catalog.load_table('a.b')\ndf = t.scan().to_pandas()")])), [])

    def test_plain_words_that_look_like_ids_are_not_flagged(self):
        self.assertEqual(self.check(notebook([code("# reads the env-file via os.environ")])), [])


if __name__ == "__main__":
    unittest.main()
