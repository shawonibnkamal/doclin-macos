#!/usr/bin/env python3
"""Create/reuse a private local signing identity; never modify system trust."""
import json, os, pathlib, secrets, subprocess, tempfile
root = pathlib.Path.home() / 'Library/Application Support/Doclin/Signing'
root.mkdir(parents=True, exist_ok=True, mode=0o700)
os.chmod(root, 0o700)
config = root / 'identity.json'
if config.exists():
    print('Existing Doclin signing identity preserved:', config)
    raise SystemExit(0)
password = secrets.token_urlsafe(40)
keychain = root / 'doclin-signing.keychain-db'
if keychain.exists():
    raise SystemExit('An unconfigured signing keychain already exists. Preserve it and inspect before retrying.')
def run(args):
    result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result.stdout
with tempfile.TemporaryDirectory(prefix='setup-', dir=root) as scratch:
    folder = pathlib.Path(scratch)
    key, cert, p12 = (folder / name for name in ['key.pem','cert.pem','identity.p12'])
    cfg = folder / 'cert.cnf'
    cfg.write_text('[req]\ndistinguished_name=dn\nprompt=no\nx509_extensions=ext\n[dn]\nCN=Doclin Local Development\n[ext]\nbasicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=critical,codeSigning\n')
    run(['/usr/bin/openssl','req','-new','-newkey','rsa:2048','-nodes','-x509','-days','3650','-config',str(cfg),'-keyout',str(key),'-out',str(cert)])
    env = dict(os.environ, DOCLIN_P12_PASSWORD=password)
    result = subprocess.run(['/usr/bin/openssl','pkcs12','-export','-inkey',str(key),'-in',str(cert),'-out',str(p12),'-passout','env:DOCLIN_P12_PASSWORD'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    if result.returncode: raise RuntimeError(result.stderr.strip())
    run(['/usr/bin/security','create-keychain','-p',password,str(keychain)])
    run(['/usr/bin/security','unlock-keychain','-p',password,str(keychain)])
    run(['/usr/bin/security','set-keychain-settings','-lut','21600',str(keychain)])
    run(['/usr/bin/security','import',str(p12),'-k',str(keychain),'-P',password,'-T','/usr/bin/codesign'])
    run(['/usr/bin/security','set-key-partition-list','-S','apple-tool:,apple:','-s','-k',password,str(keychain)])
    fingerprint = run(['/usr/bin/openssl','x509','-in',str(cert),'-noout','-fingerprint','-sha1']).strip().split('=')[1].replace(':','')
    (root/'certificate.pem').write_bytes(cert.read_bytes())
    passwordFile = root / 'keychain-password'
    fd = os.open(passwordFile, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(fd,'w') as handle: handle.write(password)
    fd = os.open(config, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(fd,'w') as handle: json.dump({'identity':fingerprint,'keychain':str(keychain),'password_file':str(passwordFile),'local_only':True},handle)
print('Created persistent local signing identity:', fingerprint)
print('Private key stored only in dedicated Keychain:', keychain)
