# Accessibility permission and local code signing

OpenDictate uses the macOS Accessibility API to identify and recheck the focused
target, then submits text through AXSelectedText or Unicode events. macOS
associates the required Accessibility permission with the app's code
signature. Every build enables Hardened Runtime; an ad-hoc signature still
changes on rebuild, so development builds may need the grant again.

`scripts/build-app.sh` uses the identity named `OpenDictate Self-Signed` when it
exists (override with `OPENDICTATE_SIGN_IDENTITY`) and otherwise falls back to an
ad-hoc signature. Every signature includes `Assets/OpenDictate.entitlements`
with microphone input enabled. The build fails if the final signed bundle
does not report Hardened Runtime or the required boolean audio-input entitlement.
Hardened Runtime without that entitlement prevents macOS from granting microphone
access. This capability does not replace the user's microphone permission.
Existing microphone and Accessibility grants can refer to an older ad-hoc
code hash; verify the current candidate through the normal macOS permission UI.

Ordinary editor targets must expose a settable `AXSelectedText` attribute,
including editors whose delivery path uses Unicode events. Missing support
normally leaves the transcript on the clipboard for manual paste; OpenDictate
does not send an automatic `Cmd+V`.

The narrow exception is **Apple Terminal** (`com.apple.Terminal`): a focused
`AXTextArea` without a captured `AXWebArea` ancestor may receive Unicode events
without settable `AXSelectedText`. The control must not report disabled or
secure-text status, its display-selection range must be absent or empty, and
Secure Input must be off. This path never writes Terminal's `AXSelectedText`,
even when it reports writable, and does not replace selected scrollback text.
Accessibility permission and the original app/window/field checks still apply.
Before sending any chunk, the insertion text is rejected if it contains line
breaks, control characters or AppKit function-key scalars. Focus, eligibility,
permission and Secure Input are rechecked for every chunk.

This does not identify the shell or program running inside Terminal; ordinary
characters can still have effects in an interactive program. The exception does
not establish support for iTerm2 or terminals inside editors. The actual Terminal
AX structure and acceptance of these events still need an attended check on the
identified candidate; offline tests do not prove native insertion. See the
[Terminal checks](../CHECKS.md#apple-terminal) and
[compatibility scope](compatibility-matrix.md#apple-terminal).

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
