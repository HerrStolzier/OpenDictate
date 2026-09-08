# Accessibility permission and local code signing

OpenDictate inserts the transcript into the focused text element through the
macOS Accessibility API. macOS associates that permission with the app's code
signature. Every build enables Hardened Runtime; an ad-hoc signature still
changes on rebuild, so development builds may need the grant again.

`scripts/build-app.sh` uses the identity named `OpenDictate Self-Signed` when it
exists (override with `OPENDICTATE_SIGN_IDENTITY`) and otherwise falls back to an
ad-hoc signature. The build fails if the final bundle does not report the
Hardened Runtime flag.

Direct insertion requires the focused control to expose a settable
`AXSelectedText` attribute. When it does not, OpenDictate leaves the transcript
on the clipboard for manual paste instead of sending an automatic `Cmd+V`.

## Create a local development identity

Use the attended Keychain Access workflow so an exportable private key is never
written to a predictable temporary path:

1. Open **Keychain Access** and select the **login** keychain.
2. Choose **Keychain Access > Certificate Assistant > Create a Certificate**.
3. Name it `OpenDictate Self-Signed`, choose **Self Signed Root** as the identity
   type and **Code Signing** as the certificate type, then create it.
4. Leave the private key's access control restricted. When a build asks to use
   the key, choose **Allow** for that signature only. Do not choose **Always
   Allow**, do not authorize every application, and do not grant unattended
   access to `/usr/bin/codesign`.
5. Confirm that the identity appears among the matching identities:

   ```bash
   security find-identity -p codesigning | grep "OpenDictate Self-Signed"
   ```

The certificate is intentionally local and untrusted. It is only for stable
identity during development; it does not make an app suitable for public binary
distribution. Public binaries require a protected Developer ID identity,
notarization, stapling, and verification of the final Hardened Runtime artifact.

After creating or replacing the identity, rebuild the app and grant
Accessibility once. A stable identity is intended to preserve the grant, but
the current hardened build still needs a fresh attended insertion check. If the
app reports that Accessibility is unavailable, remove and add the current
bundle again or clear the stale grant:

```bash
tccutil reset Accessibility local.opendictate.app
```

If an identity was created with the repository's older instructions (`-A`, a
permanently trusted `codesign`, or private-key files under `/tmp/cs.*`), delete
and replace that identity and reset the old Accessibility entry. Those settings
allowed unattended same-user use of an identity carrying a TCC grant.
