// utils/plan_vision.js
const fs = require("fs");
const path = require("path");
const OpenAI = require("openai");

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

function guessMime(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === ".png") return "image/png";
  if (ext === ".webp") return "image/webp";
  return "image/jpeg"; // jpg/jpeg default
}

async function analyzeFloorPlanImage(filePath) {
  const mime = guessMime(filePath);
  const b64 = fs.readFileSync(filePath, { encoding: "base64" });
  const dataUrl = `data:${mime};base64,${b64}`;

  const prompt = `
You are a professional architectural floor plan analyzer.
Extract information from the floor plan image and return STRICT JSON only.

Return this JSON shape:
{
  "totalArea": number|null,
  "floorLabel": string|null,
  "scaleText": string|null,
  "bedrooms": number|null,
  "bathrooms": number|null,
  "kitchens": number|null,
  "majlis": number|null,
  "rooms": [
    {"name": string, "width": number|null, "length": number|null, "area": number|null}
  ],
  "notes": string[],
  "confidence": number
}

Rules:
- If total area is written explicitly, trust it.
- If dimensions exist, prefer them.
- confidence 0..1 (estimate your certainty).
- JSON only. No markdown. No extra text.
`;

  // الصور كـ input: إما URL أو Base64 data URL :contentReference[oaicite:1]{index=1}
  const resp = await openai.responses.create({
    model: "gpt-4o-mini", // سريع ورخيص ويدعم صور :contentReference[oaicite:2]{index=2}
    input: [
      {
        role: "user",
        content: [
          { type: "input_text", text: prompt },
          { type: "input_image", image_url: dataUrl },
        ],
      },
    ],
  });

  // استخراج النص النهائي
  const outText =
    resp.output_text ||
    (resp.output?.[0]?.content || [])
      .map((c) => c.text)
      .filter(Boolean)
      .join("\n");

  let json;
  try {
    json = JSON.parse(outText);
  } catch (e) {
    // إذا طلع نص مش JSON (نادر) رجّع خطأ واضح
    throw new Error("Vision returned non-JSON output. Raw: " + outText);
  }

  return json;
}

module.exports = { analyzeFloorPlanImage };
