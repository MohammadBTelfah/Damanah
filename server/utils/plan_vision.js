// utils/plan_vision.js
const OpenAI = require("openai");

// تأكد أن OPENAI_API_KEY موجود في Environment Variables على Render
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

/**
 * تحليل مخطط الأرضية باستخدام OpenAI Vision
 * @param {string} imageUrl - رابط الصورة القادم من Cloudinary أو Base64
 */
async function analyzeFloorPlanImage(imageUrl) {
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

  try {
    const response = await openai.chat.completions.create({
      model: "gpt-4o-mini", // يدعم تحليل الصور بكفاءة عالية وتكلفة منخفضة
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: prompt },
            {
              type: "image_url",
              image_url: {
                url: imageUrl, // نمرر الرابط القادم من Cloudinary مباشرة
              },
            },
          ],
        },
      ],
      response_format: { type: "json_object" }, // نضمن أن النتيجة JSON دائماً
      max_tokens: 1000,
    });

    const outText = response.choices[0].message.content;
    return JSON.parse(outText);

  } catch (e) {
    console.error("Vision Analysis Error:", e);
    throw new Error("Failed to analyze plan image: " + e.message);
  }
}

module.exports = { analyzeFloorPlanImage };