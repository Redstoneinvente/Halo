# Halo Firestore trial claim setup

Halo keeps the 14-day countdown locally, but Firestore owns the one-time trial claim.
When a verified Firebase user presses **Start 14-Day Trial**, Halo atomically creates:

`haloTrialClaims/{firebaseUID}`

If the document already exists, the account has already claimed a trial and Halo refuses a new one.
The document is immutable from the client: Firestore rules deny update and delete.

## Deploy once

Use the same Firebase project as Halo Authentication:

```bash
npm install -g firebase-tools
firebase login
firebase use --add
firebase deploy --only firestore:rules
```

No Cloud Function is required and no LicenseSeat secret key is used for trials.
Halo obtains the Firebase project ID from the signed-in user's Firebase ID token and calls the Firestore REST API directly with that token.

## Firestore collection

The collection is created automatically on the first successful trial claim. Each claim stores the Firebase UID, Halo device fingerprint, start/expiry timestamps, source, and schema version.

Starting a trial requires internet access. Once started, the local trial can continue offline until its locally stored expiry.
