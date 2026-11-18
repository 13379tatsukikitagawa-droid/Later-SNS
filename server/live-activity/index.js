// P40 C のひな形(未配備)。firebase-functions v2 + firebase-admin + http2 + jsonwebtoken。
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const http2 = require("http2");
const jwt = require("jsonwebtoken");

admin.initializeApp();
const BUNDLE = "com.tatsukikitagawa.laternew2";

function apnsJwt() {
  return jwt.sign({}, process.env.APNS_P8, { algorithm: "ES256", issuer: process.env.APNS_TEAM_ID, header: { alg: "ES256", kid: process.env.APNS_KEY_ID } });
}

function push(token, body) {
  return new Promise((resolve, reject) => {
    const client = http2.connect("https://api.push.apple.com");
    const req = client.request({
      ":method": "POST", ":path": `/3/device/${token}`, authorization: `bearer ${apnsJwt()}`,
      "apns-topic": `${BUNDLE}.push-type.liveactivity`, "apns-push-type": "liveactivity", "apns-priority": "10",
    });
    req.end(JSON.stringify(body));
    req.on("response", (h) => { client.close(); h[":status"] === 200 ? resolve() : reject(new Error(`APNs ${h[":status"]}`)); });
    req.on("error", reject);
  });
}

const ref = (d) => Math.floor(d.getTime() / 1000) - 978307200; // 2001-01-01 からの 秒(ActivityKit の Date)

function localParts(tz, now) {
  const f = new Intl.DateTimeFormat("en-GB", { timeZone: tz, hour: "2-digit", minute: "2-digit", hour12: false }).formatToParts(now);
  return { h: +f.find((p) => p.type === "hour").value, m: +f.find((p) => p.type === "minute").value };
}

exports.liveActivityTick = onSchedule({ schedule: "every 5 minutes", secrets: ["APNS_P8", "APNS_TEAM_ID", "APNS_KEY_ID"] }, async () => {
  const now = new Date();
  const snap = await admin.firestore().collection("liveTokens").get();
  for (const doc of snap.docs) {
    const u = doc.data();
    const { h, m } = localParts(u.tz || "Asia/Tokyo", now);
    const minutes = h * 60 + m;
    const endsNight = new Date(now.getTime() + ((24 * 60 - minutes) * 60 * 1000));
    const endsMorning = new Date(now.getTime() + ((9 * 60 - minutes) * 60 * 1000));
    const base = { shotsTaken: u.shots || 0, frameThumbs: [], friendCount: u.friends || 0, devPercent: u.dev || 0 };
    try {
      if (u.night && (u.shots || 0) < 3 && minutes >= 23 * 60 && minutes < 23 * 60 + 5 && u.startToken) {
        await push(u.startToken, { aps: { timestamp: ref(now), event: "start", "content-state": { ...base, phase: "film", endsAt: ref(endsNight) }, "attributes-type": "LattagLiveAttributes", attributes: { dayKey: u.dayKey }, alert: { title: "", body: "" } } });
      } else if (u.night && (u.shots || 0) < 3 && minutes >= 23 * 60 + 50 && minutes < 23 * 60 + 55 && u.pushToken) {
        await push(u.pushToken, { aps: { timestamp: ref(now), event: "update", "content-state": { ...base, phase: "lastCall", endsAt: ref(endsNight) } } });
      } else if (u.night && minutes < 5 && u.pushToken) {
        await push(u.pushToken, { aps: { timestamp: ref(now), event: "end", "content-state": { ...base, phase: "done", endsAt: ref(now) }, "dismissal-date": ref(new Date(now.getTime() + 3600 * 1000)) } });
      } else if (u.morning && (u.yesterdayShots || 0) >= 1 && minutes >= 8 * 60 + 30 && minutes < 8 * 60 + 35 && u.startToken) {
        await push(u.startToken, { aps: { timestamp: ref(now), event: "start", "content-state": { ...base, shotsTaken: u.yesterdayShots, phase: "opening", endsAt: ref(endsMorning) }, "attributes-type": "LattagLiveAttributes", attributes: { dayKey: u.dayKey }, alert: { title: "", body: "" } } });
      } else if (u.morning && minutes >= 9 * 60 && minutes < 9 * 60 + 5 && u.pushToken) {
        await push(u.pushToken, { aps: { timestamp: ref(now), event: "end", "content-state": { ...base, phase: "opened", endsAt: ref(now) }, "dismissal-date": ref(new Date(now.getTime() + 3600 * 1000)) } });
      }
    } catch (e) { console.warn("live push failed", doc.id, e.message); }
  }
});
