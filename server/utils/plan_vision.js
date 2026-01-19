// utils/plan_vision.js
const OpenAI = require("openai");

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

/**
 * تحليل مخطط الأرضية باستخدام OpenAI Vision
 * تم التحديث ليعمل بمنطق Quantity Surveyor (حاصر كميات) محترف
 * يشمل الآن حساب الفتحات المفقودة (Voids) وارتفاعات السقف والمحيط الطولي
 */
async function analyzeFloorPlanImage(imageUrl) {
  const prompt = `
You are a professional Senior Architect and Quantity Surveyor. 
Analyze this floor plan image to provide data for a precise Bill of Quantities (BOQ).

STRICT INSTRUCTIONS:
1. QUANTITY TAKEOFF: Count every visible window symbol (double lines) and door swing.
2. GEOMETRY: Look for written dimensions (e.g., 4.20x6.00). If missing, use the drawing scale (e.g., 1:112.36) to estimate.
3. PERIMETER: Calculate the total linear meters of ALL walls (external and internal).
4. AREAS: Identify specific areas for: Tiles (floor), Paint (walls + ceiling), and Waterproofing (bathrooms/roof).
5. VOIDS & OPENINGS (IMPORTANT): Identify areas labeled 'OPEN', 'VOID', or shafts. 
   - Calculate their area to subtract from flooring/slabs.
   - Calculate their perimeter to add to wall finishes/painting.

Return ONLY a JSON object with this structure:
{
  "totalArea": number|null,
  "netFlooringArea": number|null, // Area after subtracting voids
  "wallPerimeterLinear": number|null, // Total length of all walls including perimeter of voids
  "ceilingHeightDefault": number|null, // Look for section notes or typical 3.0m
  "openings": {
    "windows": { "count": number, "estimatedTotalArea": number },
    "internalDoors": { "count": number },
    "entranceDoors": { "count": number },
    "voids": { "count": number, "totalVoidArea": number, "voidPerimeter": number } // الفتحات المفقودة مثل المناور
  },
  "rooms": [
    {"name": string, "area": number|null, "type": "wet|dry"}
  ],
  "structuralElements": {
    "columnsCount": number|null,
    "hasStaircase": boolean
  },
  "confidence": number,
  "notes": string[]
}

Rules:
- If a total area is explicitly written (e.g., 314.80 m²), prioritize it.
- "type": "wet" refers to bathrooms/kitchens for plumbing calculations.
- STRICT JSON only. No extra text.
`;

  try {
    const response = await openai.chat.completions.create({
      model: "gpt-4o-mini", 
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: prompt },
            {
              type: "image_url",
              image_url: {
                url: imageUrl,
                detail: "high" // ✅ إجبار الموديل على قراءة التفاصيل الدقيقة مثل رموز الشبابيك والمناور
              },
            },
          ],
        },
      ],
      response_format: { type: "json_object" }, 
      max_tokens: 1500, // زيادة عدد التوكينات للسماح بتفصيل الغرف والفتحات
    });

    const outText = response.choices[0].message.content;
    return JSON.parse(outText);

  } catch (e) {
    console.error("Vision Analysis Error:", e);
    throw new Error("Failed to analyze plan image: " + e.message);
  }
}

module.exports = { analyzeFloorPlanImage };