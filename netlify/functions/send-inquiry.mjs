const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const env = (name) => globalThis.Netlify?.env?.get?.(name) || process.env[name] || "";

const clean = (value, max = 1000) => String(value || "").trim().slice(0, max);

export default async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  let payload;
  try {
    payload = await request.json();
  } catch {
    return json({ error: "Invalid request" }, 400);
  }

  if (clean(payload.botField)) return json({ ok: true });

  const apiKey = env("RESEND_API_KEY");
  const to = env("CONTACT_EMAIL") || "Admin@handsonmoving.org";
  const from = env("RESEND_FROM") || "Hands On Moving Thrift <Admin@handsonmoving.org>";
  if (!apiKey) return json({ error: "Email is not configured yet" }, 500);

  const name = clean(payload.name, 120) || "Website visitor";
  const email = clean(payload.email, 200);
  const phone = clean(payload.phone, 80);
  const requestType = clean(payload.requestType, 80) || "Availability";
  const item = clean(payload.item, 200) || "Not specified";
  const message = clean(payload.message, 3000) || "No message provided.";

  if (!email || !phone) return json({ error: "Email and phone are required" }, 400);

  const subject = `Thrift inquiry: ${requestType}${item !== "Not specified" ? ` - ${item}` : ""}`;
  const text = [
    "New Hands On Moving Thrift Store inquiry",
    "",
    `Request: ${requestType}`,
    `Item: ${item}`,
    `Name: ${name}`,
    `Email: ${email}`,
    `Phone: ${phone}`,
    "",
    "Message:",
    message,
  ].join("\n");

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      authorization: `Bearer ${apiKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      from,
      to,
      reply_to: email,
      subject,
      text,
    }),
  });

  if (!response.ok) {
    const details = await response.text();
    console.error("Resend failed", response.status, details);
    return json({ error: "Email could not be sent" }, 502);
  }

  return json({ ok: true });
};

export const config = {
  path: "/api/inquiry",
};
