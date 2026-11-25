"""Contract tests for emulator-only provisioning and source-event routing."""

from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import runpy
import unittest
from unittest.mock import patch
import urllib.error

SCRIPT = Path(__file__).resolve().parents[1] / "pubsub_init.py"


class PubSubBootstrapTests(unittest.TestCase):
    def test_requires_explicit_emulator_without_contacting_cloud(self):
        with patch.dict(os.environ, {}, clear=True), patch(
            "urllib.request.urlopen"
        ) as request:
            with self.assertRaisesRegex(SystemExit, "refusing real cloud access"):
                runpy.run_path(str(SCRIPT))
            request.assert_not_called()

    def test_source_subscription_routes_to_monitoring_and_bootstrap_is_repeatable(self):
        resources = {}
        pushes = {}

        def respond(request, timeout):
            self.assertTrue(request.full_url.startswith("http://127.0.0.1:8681/"))
            body = json.loads(request.data)
            if request.method == "PUT":
                if request.full_url in resources:
                    raise urllib.error.HTTPError(
                        request.full_url, 409, "Already exists", {}, None
                    )
                resources[request.full_url] = body
            else:
                self.assertTrue(request.full_url.endswith(":modifyPushConfig"))
                pushes[request.full_url] = body
            response = io.BytesIO(b"{}")
            response.status = 200
            return response

        with patch.dict(
            os.environ,
            {
                "PUBSUB_EMULATOR_HOST": "127.0.0.1:8681",
                "PUBSUB_PROJECT_ID": "coldtrace-local",
                "MONITORING_PUSH_URL": "http://monitoring:8080/internal/pubsub/events",
            },
            clear=True,
        ), patch("urllib.request.urlopen", side_effect=respond), redirect_stdout(
            io.StringIO()
        ):
            runpy.run_path(str(SCRIPT))
            initial = dict(resources)
            runpy.run_path(str(SCRIPT))
        self.assertEqual(initial, resources)
        base = "http://127.0.0.1:8681/v1/projects/coldtrace-local"
        self.assertIn(base + "/topics/source.configuration-changed", resources)
        subscription = (
            base + "/subscriptions/monitoring-service.source-configuration-changed"
        )
        self.assertEqual(
            "projects/coldtrace-local/topics/source.configuration-changed",
            resources[subscription]["topic"],
        )
        self.assertEqual(
            {"pushEndpoint": "http://monitoring:8080/internal/pubsub/events"},
            pushes[subscription + ":modifyPushConfig"]["pushConfig"],
        )


if __name__ == "__main__":
    unittest.main()
