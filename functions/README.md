# Halo 14-day trial backend

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
