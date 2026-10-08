#!/usr/bin/env python3
"""codesign with Doclin's local identity, without exposing Keychain secrets."""
import json, pathlib, subprocess, sys
config = json.loads((pathlib.Path.home()/'Library/Application Support/Doclin/Signing/identity.json').read_text())
password = pathlib.Path(config['password_file']).read_text()
unlock = subprocess.run(['/usr/bin/security','unlock-keychain','-p',password,config['keychain']],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
if unlock.returncode:
    raise SystemExit('Could not unlock the private Doclin signing Keychain. Its credentials were not logged.')
subprocess.run(['/usr/bin/codesign','--keychain',config['keychain'],'--sign',config['identity'],*sys.argv[1:]],check=True)
