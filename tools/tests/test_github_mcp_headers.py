"""Check credential encoding and the MCP helper's output boundary using dummy values."""
import contextlib
import io
import json
import unittest
from unittest.mock import patch
from tools import github_mcp_headers as helper


class GitHubMcpHeadersTest(unittest.TestCase):
    def test_windows_and_utf8_credential_encodings(self):
        for raw in [b'dummy_token', 'dummy_token\0'.encode('utf-16-le')]:
            self.assertEqual(helper.decode_token(raw), 'dummy_token')

    def test_empty_or_header_breaking_content_is_rejected(self):
        for raw in [b'', b' \r\n', b'dummy\r\nX-Other: injected', b'dummy\ttoken', b'\xff']:
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                helper.decode_token(raw)

    def test_private_protocol_has_only_the_authorization_header(self):
        output = io.StringIO()
        with patch.object(helper, 'read_windows_credential', return_value='dummy_token') as read:
            with contextlib.redirect_stdout(output):
                self.assertEqual(helper.main(['--credential-target', 'DummyTarget']), 0)
        read.assert_called_once_with('DummyTarget')
        self.assertEqual(json.loads(output.getvalue()), {'Authorization': 'Bearer dummy_token'})

    def test_failure_does_not_emit_header_or_exception_secrets(self):
        output, errors = io.StringIO(), io.StringIO()
        with patch.object(helper, 'read_windows_credential', side_effect=OSError('dummy_private_value')):
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                self.assertEqual(helper.main(['--credential-target', 'DummyTarget']), 1)
        self.assertEqual(output.getvalue(), '')
        self.assertNotIn('dummy_private_value', errors.getvalue())
        self.assertEqual(errors.getvalue().strip(), 'GitHub MCP credential unavailable or invalid.')


if __name__ == '__main__':
    unittest.main()
