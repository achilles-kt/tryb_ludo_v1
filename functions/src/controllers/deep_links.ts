import * as functions from "firebase-functions";
import { db } from "../admin";
import * as crypto from "crypto";

// Configurable constants
// TODO: Move to config.ts eventually
const APP_STORE_URL = "https://play.google.com/store/apps/details?id=com.example.tryb_ludo_v1"; // Replace with real ID
const LINK_TTL_MS = 60 * 60 * 1000; // 1 Hour

/**
 * 1. HTTP Endpoint: User clicks this link on the web.
 * url: https://.../handleInviteLink?code=XYZ
 */
export const handleInviteLink = functions.https.onRequest(async (req, res) => {
    const code = req.query.code as string;

    if (!code) {
        res.redirect(APP_STORE_URL);
        return;
    }

    // Fingerprint (IP Only)
    const ip = req.headers['fastly-client-ip'] || req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown';
    const hash = crypto.createHash('sha256').update(`${ip}`).digest('hex');

    console.log(`🔗 DEEP_LINK_CLICK: Code=${code}, IP=${ip}, Hash=${hash}`);

    // Store in DB for deferred path
    const ref = db.ref(`deferred_links/${hash}`);
    await ref.set({
        code,
        ts: Date.now(),
    });

    // Landing Page HTML
    const appSchemeUrl = `tryb://join/${code}`;

    // TODO: Dynamic OpenGraph images based on user profile?
    // For now, static assets.
    const html = `<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Join me in Tryb Ludo!</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    
    <!-- Open Graph / WhatsApp Preview -->
    <meta property="og:title" content="Join my Ludo Table on Tryb!">
    <meta property="og:description" content="Click to play now. Fast, fun, and competitive.">
    <meta property="og:image" content="https://tryb-ludo-v1.web.app/preview_invite.png">
    <meta property="og:url" content="https://tryb-ludo-v1.web.app/invite?code=${code}">
    <meta property="og:type" content="website">

    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #0F1218; color: white; text-align: center; padding: 40px 20px; }
        .card { background: #1E2025; border-radius: 16px; padding: 32px; max-width: 400px; margin: 0 auto; box-shadow: 0 4px 20px rgba(0,0,0,0.5); }
        h1 { margin-bottom: 24px; font-size: 24px; }
        p { color: #A0AEC0; margin-bottom: 32px; }
        .btn { background: linear-gradient(135deg, #6C5DD3, #867AE9); color: white; padding: 14px 32px; text-decoration: none; border-radius: 50px; font-weight: bold; display: inline-block; }
    </style>
</head>
<body>
    <div class="card">
        <h1>You've been invited!</h1>
        <p>Your friend is waiting for you in Tryb Ludo.</p>
        <a href="${appSchemeUrl}" class="btn">Launch App</a>
        
        <br><br>
        <a href="${APP_STORE_URL}" style="color: #444; font-size: 12px;">Don't have the app? Install here.</a>
    </div>

    <script>
        // Attempt Direct Open
        window.location = "${appSchemeUrl}";

        // Fallback to Store if nothing happens (simple timeout approach)
        setTimeout(function() {
            // Optional: Redirect to store automatically? 
            // Better to let user click manually if simple method fails, to avoid loops.
            // window.location = "${APP_STORE_URL}";
        }, 2000);
    </script>
</body>
</html>`;

    res.status(200).send(html);
});

/**
 * 2. Callable: App calls this on startup to check for pending link.
 */
export const checkDeferredLink = functions.https.onCall(async (data, context) => {
    // We need the raw request to get IP/UA. 
    // context.rawRequest is available in v2 or v1 onCall?
    // In v1 "onCall", accessing raw headers is tricky.
    // context.rawRequest is NOT exposed in standard Firebase Functions v1 onCall.
    // 
    // Workaround: We must pass the User Agent from the client? 
    // But IP is critical.
    // 
    // Actually, `context.rawRequest` IS available in `functions.https.onCall` for Firebase Functions SDK > 3.16.0.
    // We are using `firebase-functions` (checking package.json...).
    // Assuming we have access.

    const rawReq = context.rawRequest;
    if (!rawReq) {
        console.warn("⚠️ CHECK_DEFERRED: No rawRequest available.");
        return { code: null };
    }

    const ip = rawReq.headers['fastly-client-ip'] || rawReq.headers['x-forwarded-for'] || rawReq.socket.remoteAddress || 'unknown';

    // Use matching Hash strategy (IP Only)
    const hash = crypto.createHash('sha256').update(`${ip}`).digest('hex');
    console.log(`🔗 DEEP_LINK_CHECK: IP=${ip}, Hash=${hash}`);

    const ref = db.ref(`deferred_links/${hash}`);
    const snap = await ref.get();

    if (!snap.exists()) {
        return { code: null };
    }

    const val = snap.val();
    const now = Date.now();

    // Check TTL
    if (now - val.ts > LINK_TTL_MS) {
        await ref.remove(); // Cleanup expired
        return { code: null };
    }

    // Match found!
    // Consume it (One-time use)
    await ref.remove();

    console.log(`✅ DEEP_LINK_MATCH: Code=${val.code}`);
    return { code: val.code };
});
