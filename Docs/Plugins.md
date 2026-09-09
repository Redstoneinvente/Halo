# Declarative plugins and extension contracts

Import Examples/Starter.haloPlugin from Settings → Plugins. A manifest declares version 1, a stable unique ID, name, permissions and up to 50 commands. The only supported permission is openURL. HTTPS and shortcuts URL schemes are accepted; files, JavaScript and shell schemes are rejected. A confirmation shows the full URL each time a command runs.

Imported manifests are stored as JSON in preferences. Reimporting the same ID replaces that manifest after confirmation. Removing a plugin removes its commands. Imported text is never treated as executable code.

HaloModule/ModuleContext describe internal views. NotchCommand, LiveActivityProvider, AutomationTrigger and AutomationAction are source-level contracts, not a public binary ABI. WeatherProvider and AIActionProvider have no default implementation. External AI must not receive clipboard or screenshot content without a dedicated explicit user action showing destination and content.

Before offering executable third-party plugins, implement a separate process/XPC host, versioned message schema, capability-based requests, time/memory limits, cancellation, code-signature policy, revocation and crash recovery. Do not replace the manifest loader with Bundle.load or arbitrary shell execution.

Offline licenses use signed payload bytes, not re-encoded claims. SignedLicense verifies the original payload's signature with an explicitly supplied Curve25519 signing public key. Private keys belong only in an external issuance workflow.
