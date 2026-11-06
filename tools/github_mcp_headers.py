"""Provide a private MCP Authorization header from one named Windows credential.

Stdout is the MCP client's credential pipe and contains a secret on success.
Never invoke this helper with its stdout displayed in a chat or saved to a log.
"""
import argparse
import ctypes
import json
import os
import sys


def decode_token(raw: bytes) -> str:
    """Decode a stored UTF-8/UTF-16 token and reject header-breaking content."""
    token = raw.decode('utf-16-le' if b'\0' in raw else 'utf-8').strip('\0 \t\r\n')
    if not token or any(ord(char) < 33 or ord(char) > 126 for char in token):
        raise ValueError('Credential is not a valid single header token.')
    return token


def read_windows_credential(target: str) -> str:
    """Read only the named Generic credential and always release the native buffer."""
    if os.name != 'nt' or not target:
        raise OSError('A named Windows credential is required.')
    from ctypes import wintypes as w

    class Credential(ctypes.Structure):
        _fields_ = [('Flags', w.DWORD), ('Type', w.DWORD),
                    ('TargetName', w.LPWSTR), ('Comment', w.LPWSTR),
                    ('LastWritten', w.FILETIME), ('CredentialBlobSize', w.DWORD),
                    ('CredentialBlob', ctypes.POINTER(ctypes.c_ubyte)),
                    ('Persist', w.DWORD), ('AttributeCount', w.DWORD),
                    ('Attributes', ctypes.c_void_p), ('TargetAlias', w.LPWSTR),
                    ('UserName', w.LPWSTR)]

    api = ctypes.WinDLL('Advapi32.dll', use_last_error=True)
    api.CredReadW.argtypes = [w.LPCWSTR, w.DWORD, w.DWORD,
                             ctypes.POINTER(ctypes.POINTER(Credential))]
    api.CredReadW.restype = w.BOOL
    api.CredFree.argtypes = [ctypes.c_void_p]
    api.CredFree.restype = None
    pointer = ctypes.POINTER(Credential)()
    if not api.CredReadW(target, 1, 0, ctypes.byref(pointer)):
        raise OSError('Named Windows credential is unavailable.')
    try:
        raw = ctypes.string_at(pointer.contents.CredentialBlob,
                               pointer.contents.CredentialBlobSize)
        return decode_token(raw)
    finally:
        api.CredFree(pointer)


def main(argv=None) -> int:
    """Emit exactly one private header object, or fail without secret diagnostics."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--credential-target', required=True)
    args = parser.parse_args(argv)
    try:
        token = read_windows_credential(args.credential_target)
    except (OSError, ValueError):
        print('GitHub MCP credential unavailable or invalid.', file=sys.stderr)
        return 1
    json.dump({'Authorization': 'Bearer ' + token}, sys.stdout)
    sys.stdout.write('\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
