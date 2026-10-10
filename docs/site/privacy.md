# Privacy and data flow

Doclin defaults to local processing. Open source makes the implementation
inspectable; it does not make every optional mode offline.

| Feature | Default | Data sent by Doclin |
| --- | --- | --- |
| Apple on-device dictation | Local | No recording uploaded; Apple speech assets may download during setup |
| Kokoro/macOS notification voice | Local | No text uploaded |
| Agent update excerpts | Local | No session text uploaded |
| OpenAI transcription | Off | Recording, language hint and custom vocabulary to OpenAI |
| OpenAI dictation cleanup | Off | Dictation transcript to OpenAI |
| OpenAI notification summary | Off | Up to 600 characters of task context and 8,000 characters of response to OpenAI; project metadata is not included |
| OpenAI notification voice | Off | Spoken sentence to OpenAI |

Local recognition explicitly requires on-device support and does not silently
switch to Apple's servers. The Mac app uses no Doclin server, account, analytics or telemetry. Model/dependency setup downloads public files from their vendors.
Optional cloud processing uses the user's own key; provider policies and
charges apply. Responses requests set `store: false`, which is not a claim of
zero provider retention. A canceled request may already have reached OpenAI.

## Local retention and permissions

Local-mode dictation audio is not written to disk by Doclin. Dictation text
and the last 30 dictations and agent updates stay in memory until cleared or the app exits.
Cloud-mode recordings and generated speech temporarily use private audio
files. Completion/cancellation removes them; crash leftovers are cleaned at
next launch. Transient Claude hook messages use a user-private inbox and are
consumed/deleted; a crash can leave files until the next launch or hook run.
Preferences remain in Application Support; API keys remain in macOS Keychain.
Doclin does not delete the underlying Codex/Claude session histories.

Microphone access is used while dictating. Right Command passively monitors
modifier and key-down events; typed key contents are not stored. Accessibility
is used to inspect the original editable field and insert text. Secure password
fields are excluded. Clipboard-enabled insertion leaves the transcript on the
clipboard; clipboard managers may retain it under their own policies.

Connecting Claude modifies only Doclin's marked hooks and creates a private
backup of existing settings. Disconnect removes Doclin hooks. To uninstall,
disconnect Claude, disable Start at login, remove the API key in Settings → Voice → Cloud features,
quit, and remove the app. Application Support and configuration backups remain
until you remove them yourself.

[Inspect the app source](https://github.com/shawonibnkamal/doclin-macos)

## Website analytics and downloads

The doclin.dev website uses Vercel Web Analytics to count page views and
visitors and report referral sources, approximate countries, browsers and
devices. This is separate from the Mac app: no recordings, transcripts,
custom words or agent content are sent to website analytics. Query strings
and URL fragments are removed before page-view events are sent. Vercel Web
Analytics does not use tracking cookies. See [Vercel’s analytics privacy
information](https://vercel.com/docs/analytics/privacy-policy).

App downloads are hosted by GitHub, which reports aggregate release-asset
download counts. These counts are not unique users or confirmed installations.
