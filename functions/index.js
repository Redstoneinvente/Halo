"use strict";

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
    res.set("Cache-Control", "no-store");
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
