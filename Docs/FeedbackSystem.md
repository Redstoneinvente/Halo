# Halo Feedback System

Halo's in-app feedback flow deliberately separates public issue data from private support diagnostics.

## Public collection: `feedbackIssues`

This collection is safe for the public issues website to read directly.

Each document ID is the public issue ID. Current fields:

- `schemaVersion`: currently `1`
- `type`: `bug`, `feature`, `crash`, or `other`
- `title`: user-facing issue title
- `description`: user-facing issue description
- `category`: product area selected in Halo
- `status`: initially `received`
- `createdAt`: server timestamp
- `updatedAt`: server timestamp
- `appVersion`: Halo version that submitted the issue
- `appBuild`: Halo build that submitted the issue
- `platform`: currently `macOS`
- `crashRelated`: present and `true` for crash feedback

The Mac client can create these documents but cannot edit or delete them. Status/moderation changes are intended to be made by a trusted website/backend using Firebase Admin credentials.

Suggested public status lifecycle:

`received -> reviewing -> planned -> in_progress -> resolved`

The website should never need access to `feedbackReports`.

## Private collection: `feedbackReports`

The companion document uses the same document ID as the public issue.

It can contain:

- Firebase UID
- account email
- private reproduction/context text
- whether the user chose to include diagnostics
- safe technical diagnostics
- a random local installation identifier when automatic crash diagnostics are enabled
- whether Halo detected a crash in the previous execution

Firestore rules deny public reads for this collection.

Do not expose this collection from client-side website code. Any support/admin UI that needs it should read it from a trusted backend using Firebase Admin credentials.

## Diagnostics policy

Halo's automatic Crashlytics reporting can be disabled in **Settings -> Feedback & Support**.

Safe diagnostics are intentionally limited to:

- Halo version/build
- macOS version
- CPU architecture
- display count
- notched-display count
- distribution channel

Halo must not place clipboard contents, file names/contents, notes, calendar data, screenshots, license keys, browser URLs, or third-party integration payloads into automatic diagnostics.

## Website query

A first version of the public website can query `feedbackIssues`, order by `createdAt` descending, and filter client-side by `type`, `category`, or `status`.

If the website later adds voting, comments, or authenticated issue ownership, use separate collections and dedicated rules rather than adding private fields to `feedbackIssues`.

## Firebase configuration

The app expects a bundled `GoogleService-Info.plist` whose registered bundle identifier exactly matches Halo's Xcode bundle identifier.

Crashlytics dSYM uploading should be enabled once that matching plist is in the target. Use Firebase's Swift Package Manager Crashlytics run script as the final Xcode build phase.
