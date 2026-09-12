from pathlib import Path
import json

root = Path('.')

def replace_once(path: Path, old: str, new: str, label: str):
    text = path.read_text()
    if old not in text:
        raise SystemExit(f'{label}: expected source block not found in {path}')
    path.write_text(text.replace(old, new, 1))

# ---- App commercial services -------------------------------------------------
appstore = root / 'Halo/Core/AppStore.swift'
text = appstore.read_text()
old = '''    static var firebaseAPIKey: String { value("HaloFirebaseAPIKey") }
    static var licenseSeatPublishableKey: String { value("HaloLicenseSeatPublishableKey") }
    static var licenseSeatProductSlug: String { value("HaloLicenseSeatProductSlug") }
    static var firebaseConfigured: Bool { !firebaseAPIKey.isEmpty }
    static var licenseSeatConfigured: Bool {
        !licenseSeatPublishableKey.isEmpty && !licenseSeatProductSlug.isEmpty
    }
'''
new = '''    static var firebaseAPIKey: String { value("HaloFirebaseAPIKey") }
    static var licenseSeatPublishableKey: String { value("HaloLicenseSeatPublishableKey") }
    static var licenseSeatProductSlug: String { value("HaloLicenseSeatProductSlug") }
    static var trialEndpoint: String { value("HaloTrialEndpoint") }
    static var firebaseConfigured: Bool { !firebaseAPIKey.isEmpty }
    static var licenseSeatConfigured: Bool {
        !licenseSeatPublishableKey.isEmpty && !licenseSeatProductSlug.isEmpty
    }
    static var trialConfigured: Bool { !trialEndpoint.isEmpty }
'''
if old not in text:
    raise SystemExit('commercial configuration block not found')
text = text.replace(old, new, 1)

old = '''    @Published private(set) var state: HaloLicenseState = .inactive
    @Published private(set) var licenseHint = ""
    @Published private(set) var details: HaloLicenseDetails = .empty
    @Published private(set) var isBusy = false
'''
new = '''    @Published private(set) var state: HaloLicenseState = .inactive
    @Published private(set) var licenseHint = ""
    @Published private(set) var details: HaloLicenseDetails = .empty
    @Published private(set) var isBusy = false
    @Published private(set) var isStartingTrial = false
'''
if old not in text:
    raise SystemExit('license published properties block not found')
text = text.replace(old, new, 1)

old = '''    var isConfigured: Bool { HaloCommercialConfiguration.licenseSeatConfigured }

    func restoreAndValidate() async {
'''
new = '''    var isConfigured: Bool { HaloCommercialConfiguration.licenseSeatConfigured }
    var trialConfigured: Bool { HaloCommercialConfiguration.trialConfigured }

    func restoreAndValidate() async {
'''
if old not in text:
    raise SystemExit('license configuration property block not found')
text = text.replace(old, new, 1)

marker = '    func activate(_ key: String) async {'
if marker not in text:
    raise SystemExit('license activate method marker not found')
trial_method = r'''    func startTrial() async {
        guard trialConfigured else {
            errorMessage = "Halo trials are not configured on this build yet."
            return
        }
        guard HaloAccountManager.shared.isSignedIn else {
            errorMessage = "Sign in to your Halo account before starting a trial."
            return
        }
        guard HaloAccountManager.shared.emailVerified else {
            errorMessage = "Verify your email before starting the free trial."
            return
        }
        guard let url = URL(string: HaloCommercialConfiguration.trialEndpoint),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || (scheme == "http" && ["localhost", "127.0.0.1"].contains(url.host ?? "")) else {
            errorMessage = "The Halo trial service URL is invalid."
            return
        }

        isStartingTrial = true
        errorMessage = nil
        notice = nil
        defer { isStartingTrial = false }

        do {
            let token = try await HaloAccountManager.shared.validIDToken()
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "platform": "macOS",
                "device_name": Host.current().localizedName ?? "Mac"
            ])

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw HaloCommercialError.message("No response from the Halo trial service.")
            }
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            guard (200..<300).contains(http.statusCode) else {
                let message = ((root?["error"] as? [String: Any])?["message"] as? String)
                    ?? (root?["message"] as? String)
                    ?? "Unable to start the Halo trial (\(http.statusCode))."
                throw HaloCommercialError.message(message)
            }
            guard let key = (root?["license_key"] as? String) ?? (root?["licenseKey"] as? String),
                  !key.isEmpty else {
                throw HaloCommercialError.message("The trial service did not return a license.")
            }

            await activate(key)
            if state.isValid {
                notice = "Your 14-day Halo trial is active."
            }
        } catch {
            errorMessage = readable(error)
        }
    }

'''
text = text.replace(marker, trial_method + marker, 1)
appstore.write_text(text)

# ---- Locked notch UI ---------------------------------------------------------
router = root / 'Halo/Core/ExtensionContracts.swift'
text = router.read_text()
locked_start = text.index('private struct HaloLockedAccessSurface')
start = text.index('    private var licenseStep: some View {', locked_start)
end = text.index('    @ViewBuilder\n    private func commercialMessages', start)
new_license_step = r'''    private var licenseStep: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.email.isEmpty ? "Signed in" : account.email)
                        .font(.system(size: 11, weight: .semibold))
                    Text(account.emailVerified ? "Email verified" : "Email not verified")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.52))
                }
                Spacer()
                if !account.emailVerified {
                    Button("Verify Email") { Task { await account.sendVerificationEmail() } }
                        .controlSize(.small)
                    Button("Refresh") { Task { await account.refreshVerificationStatus() } }
                        .controlSize(.small)
                }
                Button("Sign Out") { account.signOut() }
                    .controlSize(.small)
            }

            Divider().overlay(Color.white.opacity(0.15))

            VStack(spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Try Halo free for 14 days")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Full Halo · 1 Mac · no payment required")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.52))
                    }
                    Spacer()
                    Button("Start 14-Day Trial") {
                        Task { await license.startTrial() }
                    }
                    .disabled(!account.emailVerified || !license.trialConfigured || license.isBusy || license.isStartingTrial)
                }

                if !account.emailVerified {
                    Text("Verify your email above to start a free trial.")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.52))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if !license.trialConfigured {
                    Text("Trial service is not configured on this build yet.")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack(spacing: 8) {
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                Text("OR USE A LICENSE")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.38))
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            }

            HStack {
                Image(systemName: "key.horizontal")
                    .foregroundStyle(.white.opacity(0.65))
                Text("License")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(license.state.title)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.52))
            }

            SecureField("License key", text: $licenseKey)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Activate License") {
                    Task {
                        await license.activate(licenseKey)
                        if license.state.isValid { licenseKey = "" }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(license.isBusy || license.isStartingTrial || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !license.licenseHint.isEmpty {
                    Button("Validate Existing") { Task { await license.validate() } }
                        .disabled(license.isBusy || license.isStartingTrial)
                    Button("Clear", role: .destructive) { license.clearLocalLicense() }
                        .disabled(license.isBusy || license.isStartingTrial)
                }

                if license.isBusy || license.isStartingTrial { ProgressView().controlSize(.small) }
            }

            commercialMessages(license.notice, license.errorMessage)
        }
        .frame(maxWidth: 450)
    }

'''
text = text[:start] + new_license_step + text[end:]
router.write_text(text)

# ---- Settings UI trial CTA ---------------------------------------------------
settings = root / 'Halo/Views/WorkspaceSettingsView.swift'
text = settings.read_text()
old = '''                } else {
                    SecureField("License key", text: $licenseKey)
                    HStack {
                        Button("Activate License") {
                            Task {
                                await license.activate(licenseKey)
                                if license.state.isValid { licenseKey = "" }
                            }
                        }
                        .disabled(license.isBusy || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if !license.licenseHint.isEmpty {
                            Button("Clear Local License", role: .destructive) { license.clearLocalLicense() }
                                .disabled(license.isBusy)
                        }
                    }
                }
'''
new = '''                } else {
                    if account.isSignedIn {
                        HStack {
                            Button("Start 14-Day Free Trial") { Task { await license.startTrial() } }
                                .disabled(!account.emailVerified || !license.trialConfigured || license.isBusy || license.isStartingTrial)
                            if !account.emailVerified {
                                Text("Verify your email to start a trial.")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else if !license.trialConfigured {
                                Text("Trial service not configured.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if license.isStartingTrial { ProgressView().controlSize(.small) }
                        }
                    }
                    SecureField("License key", text: $licenseKey)
                    HStack {
                        Button("Activate License") {
                            Task {
                                await license.activate(licenseKey)
                                if license.state.isValid { licenseKey = "" }
                            }
                        }
                        .disabled(license.isBusy || license.isStartingTrial || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if !license.licenseHint.isEmpty {
                            Button("Clear Local License", role: .destructive) { license.clearLocalLicense() }
                                .disabled(license.isBusy || license.isStartingTrial)
                        }
                    }
                }
'''
if old not in text:
    raise SystemExit('settings invalid-license branch not found')
settings.write_text(text.replace(old, new, 1))

# ---- Build configuration -----------------------------------------------------
plist = root / 'Halo/Info.plist'
text = plist.read_text()
if '<key>HaloTrialEndpoint</key>' not in text:
    text = text.replace('\t<key>HaloLicenseSeatPublishableKey</key>\n\t<string>$(HALO_LICENSESEAT_PUBLISHABLE_KEY)</string>\n',
                        '\t<key>HaloLicenseSeatPublishableKey</key>\n\t<string>$(HALO_LICENSESEAT_PUBLISHABLE_KEY)</string>\n\t<key>HaloTrialEndpoint</key>\n\t<string>$(HALO_TRIAL_ENDPOINT)</string>\n', 1)
plist.write_text(text)

base = root / 'Halo/Config/Base.xcconfig'
text = base.read_text()
if 'HALO_TRIAL_ENDPOINT' not in text:
    text = text.replace('HALO_LICENSESEAT_PRODUCT_SLUG = halo-macos-notch-utility\n',
                        'HALO_LICENSESEAT_PRODUCT_SLUG = halo-macos-notch-utility\nHALO_TRIAL_ENDPOINT =\n', 1)
base.write_text(text)

example = root / 'Halo/Config/Secrets.xcconfig.example'
text = example.read_text()
if 'HALO_TRIAL_ENDPOINT' not in text:
    text += 'HALO_TRIAL_ENDPOINT = https:/$()/europe-west1-YOUR_FIREBASE_PROJECT_ID.cloudfunctions.net/startHaloTrial\n'
example.write_text(text)

ignore = root / '.gitignore'
text = ignore.read_text()
block = '''\n# Firebase local/deploy state\nfunctions/node_modules/\n.firebase/\nfirebase-debug.log\nfirestore-debug.log\n'''
if 'functions/node_modules/' not in text:
    text += block
ignore.write_text(text)

# ---- Firebase backend --------------------------------------------------------
(root / 'functions').mkdir(exist_ok=True)
(root / 'functions/package.json').write_text(json.dumps({
    'name': 'halo-firebase-functions',
    'private': True,
    'main': 'index.js',
    'engines': {'node': '20'},
    'dependencies': {
        'firebase-admin': '^13.4.0',
        'firebase-functions': '^6.4.0'
    }
}, indent=2) + '\n')

(root / 'firebase.json').write_text(json.dumps({
    'functions': {
        'source': 'functions',
        'runtime': 'nodejs20',
        'ignore': ['node_modules', '.git', 'firebase-debug.log', 'firebase-debug.*.log']
    },
    'firestore': {'rules': 'firestore.rules'}
}, indent=2) + '\n')

(root / 'firestore.rules').write_text('''rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Trial claims are server-only. Firebase Admin in the Cloud Function bypasses these rules.
    match /haloTrialClaims/{uid} {
      allow read, write: if false;
    }
    match /haloTrialEmails/{emailHash} {
      allow read, write: if false;
    }
  }
}
''')

(root / 'functions/index.js').write_text(r'''"use strict";

const crypto = require("node:crypto");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret, defineString } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp();

const LICENSESEAT_SECRET_KEY = defineSecret("LICENSESEAT_SECRET_KEY");
const LICENSESEAT_PRODUCT_SLUG = defineString("LICENSESEAT_PRODUCT_SLUG", {
  default: "halo-macos-notch-utility",
});
const LICENSESEAT_TRIAL_PLAN_KEY = defineString("LICENSESEAT_TRIAL_PLAN_KEY", {
  default: "demo-14d",
});

class TrialHttpError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function errorPayload(code, message) {
  return { error: { code, message } };
}

function verifiedEmailHash(decoded) {
  const email = typeof decoded.email === "string" ? decoded.email.trim().toLowerCase() : "";
  if (!decoded.email_verified || !email) {
    throw new TrialHttpError(403, "EMAIL_NOT_VERIFIED", "Verify your Halo account email before starting a trial.");
  }
  return crypto.createHash("sha256").update(email).digest("hex");
}

async function reserveTrial(db, uid, emailHash) {
  const claimRef = db.collection("haloTrialClaims").doc(uid);
  const emailRef = db.collection("haloTrialEmails").doc(emailHash);

  const result = await db.runTransaction(async (tx) => {
    const claimSnap = await tx.get(claimRef);
    if (claimSnap.exists) {
      const claim = claimSnap.data();
      if (claim.status === "active" && claim.licenseKey) {
        return { claimRef, emailRef, existing: claim };
      }
      if (claim.status === "creating") {
        throw new TrialHttpError(409, "TRIAL_IN_PROGRESS", "Your trial is already being prepared. Try again in a moment.");
      }
      if (claim.status === "active") {
        throw new TrialHttpError(409, "TRIAL_ALREADY_USED", "This Halo account has already used its free trial.");
      }
    }

    const emailSnap = await tx.get(emailRef);
    if (emailSnap.exists) {
      const emailClaim = emailSnap.data();
      if (emailClaim.uid !== uid || emailClaim.status === "active") {
        throw new TrialHttpError(409, "TRIAL_ALREADY_USED", "A Halo trial has already been used for this verified email.");
      }
      if (emailClaim.status === "creating") {
        throw new TrialHttpError(409, "TRIAL_IN_PROGRESS", "Your trial is already being prepared. Try again in a moment.");
      }
    }

    const reservation = {
      uid,
      emailHash,
      status: "creating",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    tx.set(claimRef, reservation, { merge: true });
    tx.set(emailRef, { uid, status: "creating", updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    return { claimRef, emailRef, existing: null };
  });

  return result;
}

async function releaseReservation(db, claimRef, emailRef, uid) {
  await db.runTransaction(async (tx) => {
    const claimSnap = await tx.get(claimRef);
    const emailSnap = await tx.get(emailRef);
    if (claimSnap.exists) {
      const claim = claimSnap.data();
      if (claim.uid === uid && claim.status === "creating") tx.delete(claimRef);
    }
    if (emailSnap.exists) {
      const emailClaim = emailSnap.data();
      if (emailClaim.uid === uid && emailClaim.status === "creating") tx.delete(emailRef);
    }
  });
}

async function createLicenseSeatTrial(uid, emailHash) {
  const slug = encodeURIComponent(LICENSESEAT_PRODUCT_SLUG.value());
  const planKey = LICENSESEAT_TRIAL_PLAN_KEY.value();
  const response = await fetch(`https://licenseseat.com/api/v1/products/${slug}/licenses`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${LICENSESEAT_SECRET_KEY.value()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      plan_key: planKey,
      metadata: {
        source: "halo-trial",
        firebase_uid: uid,
        firebase_email_hash: emailHash,
      },
    }),
  });

  let payload = null;
  try { payload = await response.json(); } catch (_) { /* handled below */ }
  if (!response.ok) {
    const message = payload?.error?.message || payload?.message || `LicenseSeat rejected the trial request (${response.status}).`;
    throw new TrialHttpError(502, "LICENSESEAT_ERROR", message);
  }
  if (!payload || typeof payload.key !== "string" || !payload.key) {
    throw new TrialHttpError(502, "LICENSESEAT_INVALID_RESPONSE", "LicenseSeat did not return a trial license key.");
  }
  return payload;
}

exports.startHaloTrial = onRequest(
  {
    region: "europe-west1",
    cors: false,
    secrets: [LICENSESEAT_SECRET_KEY],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.set("Allow", "POST");
      res.status(405).json(errorPayload("METHOD_NOT_ALLOWED", "Use POST to start a Halo trial."));
      return;
    }

    let reservation = null;
    let uid = null;
    try {
      const authHeader = req.get("Authorization") || "";
      const match = authHeader.match(/^Bearer\s+(.+)$/i);
      if (!match) throw new TrialHttpError(401, "UNAUTHENTICATED", "Sign in to Halo before starting a trial.");

      const decoded = await getAuth().verifyIdToken(match[1], true);
      uid = decoded.uid;
      const emailHash = verifiedEmailHash(decoded);
      const db = getFirestore();
      reservation = await reserveTrial(db, uid, emailHash);

      if (reservation.existing) {
        res.status(200).json({
          license_key: reservation.existing.licenseKey,
          expires_at: reservation.existing.expiresAt || null,
          plan_key: reservation.existing.planKey || LICENSESEAT_TRIAL_PLAN_KEY.value(),
          reused: true,
        });
        return;
      }

      let license;
      try {
        license = await createLicenseSeatTrial(uid, emailHash);
      } catch (error) {
        await releaseReservation(db, reservation.claimRef, reservation.emailRef, uid);
        throw error;
      }

      const expiresAt = license.expires_at || license.ends_at || null;
      const planKey = license.plan_key || LICENSESEAT_TRIAL_PLAN_KEY.value();
      await db.runTransaction(async (tx) => {
        tx.set(reservation.claimRef, {
          uid,
          emailHash,
          status: "active",
          licenseKey: license.key,
          licenseId: license.id || null,
          planKey,
          expiresAt,
          startedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        tx.set(reservation.emailRef, {
          uid,
          status: "active",
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      });

      res.status(201).json({
        license_key: license.key,
        expires_at: expiresAt,
        plan_key: planKey,
        reused: false,
      });
    } catch (error) {
      if (error instanceof TrialHttpError) {
        res.status(error.status).json(errorPayload(error.code, error.message));
        return;
      }
      console.error("startHaloTrial failed", error);
      res.status(500).json(errorPayload("INTERNAL", "Halo could not start the trial right now. Please try again."));
    }
  }
);
''')

(root / 'functions/README.md').write_text(r'''# Halo 14-day trial backend

Halo's trial issuer runs server-side because LicenseSeat license creation requires a secret `sk_` API key. Never put that key in the macOS app or in `Secrets.xcconfig`.

## 1. Create the LicenseSeat trial plan

In the Halo product in LicenseSeat, create a plan with:

- Plan key: `demo-14d`
- Duration: 14 days
- Seat limit: 1
- Entitlements: the full Halo feature set you want trial users to receive

The function only sends `plan_key`; LicenseSeat's plan supplies the duration, seat count, and entitlements.

## 2. Prepare Firebase

Enable Email/Password Authentication and create a Firestore database for the same Firebase project used by Halo.

From the repository root:

```bash
npm install -g firebase-tools
firebase login
firebase use --add
cd functions
npm install
cd ..
```

Store the LicenseSeat **secret** API key in Firebase Secret Manager:

```bash
firebase functions:secrets:set LICENSESEAT_SECRET_KEY
```

Paste the `sk_...` key that has the `licenses:create` scope.

The source defaults to:

- LicenseSeat product slug: `halo-macos-notch-utility`
- Trial plan key: `demo-14d`
- Function region: `europe-west1`

Change the defaults in `functions/index.js` before deployment if your LicenseSeat values differ.

## 3. Deploy

```bash
firebase deploy --only functions:startHaloTrial,firestore:rules
```

The endpoint is normally:

```text
https://europe-west1-YOUR_FIREBASE_PROJECT_ID.cloudfunctions.net/startHaloTrial
```

Add it only to your local `Halo/Config/Secrets.xcconfig`:

```xcconfig
HALO_TRIAL_ENDPOINT = https:/$()/europe-west1-YOUR_FIREBASE_PROJECT_ID.cloudfunctions.net/startHaloTrial
```

The `/$()/` form is intentional: it prevents `//` from being parsed as an xcconfig comment while still expanding to a normal `https://` URL.

## Enforcement

The endpoint verifies the Firebase ID token, requires a verified email, and reserves trial claims in server-only Firestore collections. A successful trial is bound to both the Firebase UID and a SHA-256 hash of the verified email, and LicenseSeat's `demo-14d` plan limits activation to one Mac.

The macOS app never receives the LicenseSeat secret key. It receives only the generated trial license key and activates it through Halo's existing publishable-key LicenseSeat flow.
''')

print('Halo trial client + Firebase backend migration applied')
