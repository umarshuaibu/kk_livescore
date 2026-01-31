import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import * as nodemailer from "nodemailer";
import cors from "cors";

admin.initializeApp();
const db = admin.firestore();
const corsHandler = cors({origin: true});

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "farouqasm1@gmail.com",
    pass: "fajtukbhzxqtfxsm", // app password
  },
});

export const sendEmailOtp = functions.https.onRequest((req, res) => {
  corsHandler(req, res, async () => {
    try {
      const {email} = req.body;
      if (!email) {
        res.status(400).send("Email required");
        return;
      }

      const ref = db.collection("email_otps").doc(email);
      const now = Date.now();

      const code = Math.floor(100000 + Math.random() * 900000).toString();
      const hash = crypto.createHash("sha256").update(code).digest("hex");

      await ref.set({
        hash,
        expiresAt: now + 5 * 60 * 1000,
        used: false,
        createdAt: now,
      });

      await transporter.sendMail({
        to: email,
        subject: "KK Livescore Admin OTP",
        html: `
          <h3>Admin Verification</h3>
          <p>Your OTP:</p>
          <h2>${code}</h2>
          <p>Expires in 5 minutes.</p>
        `,
      });

      res.status(200).send({success: true});
    } catch (e) {
      console.error(e);
      res.status(500).send("Internal server error");
    }
  });
});

export const verifyEmailOtp = functions.https.onRequest((req, res) => {
  corsHandler(req, res, async () => {
    try {
      const {email, code} = req.body;
      if (!email || !code) {
        res.status(400).send("Invalid request");
        return;
      }

      const ref = db.collection("email_otps").doc(email);
      const snap = await ref.get();

      if (!snap.exists) {
        res.status(401).send("Invalid OTP");
        return;
      }

      const data = snap.data()!;
      if (data.used || data.expiresAt < Date.now()) {
        res.status(401).send("OTP expired");
        return;
      }

      const hash = crypto.createHash("sha256").update(code).digest("hex");
      if (hash !== data.hash) {
        res.status(401).send("Wrong OTP");
        return;
      }

      await ref.update({used: true});
      res.status(200).send({verified: true});
    } catch (e) {
      console.error(e);
      res.status(500).send("Internal server error");
    }
  });
});
