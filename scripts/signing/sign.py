#!/usr/bin/env python3
"""Sign with Doclin's local identity without logging private Keychain credentials."""
import json
import fcntl
import os
import pathlib
import shlex
import subprocess
import sys

config = json.loads((pathlib.Path.home() / 'Library/Application Support/Doclin/Signing/identity.json').read_text())
password = pathlib.Path(config['password_file']).read_text()
unlock = subprocess.run(['/usr/bin/security', 'unlock-keychain', '-p', password, config['keychain']], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
if unlock.returncode:
    raise SystemExit('Could not unlock the private Doclin signing Keychain. Its credentials were not logged.')

def search_list():
    return shlex.split(subprocess.check_output(['/usr/bin/security', 'list-keychains', '-d', 'user'], text=True))

lock_path = pathlib.Path(config['keychain']).with_suffix('.signing-lock')
lock = open(lock_path, 'a')
os.chmod(lock_path, 0o600)
fcntl.flock(lock, fcntl.LOCK_EX)
original = search_list()
added = config['keychain'] not in original
expanded = original + ([config['keychain']] if added else [])
try:
    if added:
        # codesign uses the normal search list to resolve the certificate chain.
        subprocess.run(['/usr/bin/security', 'list-keychains', '-d', 'user', '-s', *expanded], check=True)
    result = subprocess.run(['/usr/bin/codesign', '--keychain', config['keychain'], '--sign', config['identity'], *sys.argv[1:]])
finally:
    # Preserve unrelated search-list changes made while signing was running.
    if added and search_list() == expanded:
        subprocess.run(['/usr/bin/security', 'list-keychains', '-d', 'user', '-s', *original], check=True)
raise SystemExit(result.returncode)
