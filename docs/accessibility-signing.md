# Accessibility permission & stable code signing

OpenDictate pastes the transcript into the previously active app by synthesizing
Cmd+V, which requires the **Accessibility** permission (`AXIsProcessTrusted()`).

macOS ties that permission to the app's **code signature**. An ad-hoc signature
(`codesign --sign -`) gets a *new* code hash on every build, so after each rebuild
macOS treats the app as "different" and the Accessibility grant silently stops
applying — the toggle still looks ON, but `AXIsProcessTrusted()` returns `false`
and auto-paste fails (the log shows `accessibility=false`).

The fix is to sign with a **stable, self-signed code-signing identity**. The leaf
certificate stays the same across rebuilds, so the grant persists. The identity is
intentionally *untrusted* — it only needs to keep the code hash stable for TCC, not
to pass Gatekeeper.

`scripts/build-app.sh` signs with the identity named `OpenDictate Self-Signed`
(override via `OPENDICTATE_SIGN_IDENTITY`). If it is missing, the script falls back
to ad-hoc and prints a warning.

## Recreate the identity (once per machine)

```bash
# 1. Generate a self-signed cert with the codeSigning EKU
cat > /tmp/cs.cnf <<'CNF'
[ req ]
distinguished_name = dn
x509_extensions    = v3
prompt             = no
[ dn ]
CN = OpenDictate Self-Signed
[ v3 ]
basicConstraints   = critical,CA:FALSE
keyUsage           = critical,digitalSignature
extendedKeyUsage   = critical,codeSigning
CNF
openssl req -x509 -newkey rsa:2048 -keyout /tmp/cs.key -out /tmp/cs.crt \
  -days 3650 -nodes -config /tmp/cs.cnf

# 2. Bundle to PKCS#12 (legacy algos + a non-empty password — macOS `security`
#    rejects empty-password p12 with a MAC verification error)
openssl pkcs12 -export -inkey /tmp/cs.key -in /tmp/cs.crt \
  -name "OpenDictate Self-Signed" -out /tmp/cs.p12 \
  -passout pass:opendictate -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1

# 3. Import into the login keychain; -A lets codesign use the key without prompts
security import /tmp/cs.p12 -k "$HOME/Library/Keychains/login.keychain-db" \
  -P opendictate -A -T /usr/bin/codesign

# 4. Confirm (appears under "Matching identities" with CSSMERR_TP_NOT_TRUSTED —
#    that is expected and fine; it will NOT show under -v / "Valid identities")
security find-identity -p codesigning | grep "OpenDictate Self-Signed"

# 5. Clean up the private-key material on disk
rm -f /tmp/cs.key /tmp/cs.p12 /tmp/cs.crt /tmp/cs.cnf
```

Then `./scripts/build-app.sh`, reinstall to `/Applications`, and grant Accessibility
**one** more time. After that the grant survives future rebuilds.

If you ever need to clear a stale grant manually:

```bash
tccutil reset Accessibility local.opendictate.app
```
