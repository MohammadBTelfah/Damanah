const axios = require("axios");
const cheerio = require("cheerio");

// مصدر الأخبار من موقع نقابة المقاولين
const JCCA_NEWS_URL = "https://www.jcca.org.jo/NewsArchive.aspx?lang=ar";

// GET /api/public/jcca-news?limit=5
exports.getJccaNews = async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit || "5", 10), 20);

    const { data: html } = await axios.get(JCCA_NEWS_URL, {
      timeout: 15000,
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123 Safari/537.36",
      },
    });

    const $ = cheerio.load(html);
    const items = [];

    // نبحث عن كل الروابط اللي تفتح خبر
    $("a")
      .filter((_, el) => $(el).attr("href")?.includes("NewsDetails"))
      .each((_, el) => {
        const href = $(el).attr("href");
        if (!href) return;

        const link = href.startsWith("http")
          ? href
          : `https://www.jcca.org.jo/${href.replace(/^\//, "")}`;

        // 1️⃣ العنوان من الرابط نفسه
        let title = $(el).text().replace(/\s+/g, " ").trim();

        // 2️⃣ لو فاضي → من النص المحيط
        if (!title) {
          title = $(el)
            .closest("tr, li, div")
            .text()
            .replace("مشاهدة التفاصيل", "")
            .replace(/\s+/g, " ")
            .trim();
        }

        // 3️⃣ تنظيف العنوان من التواريخ
        title = title.replace(
          /\d{1,2}\/\d{1,2}\/\d{4}|\d{1,2}\/[A-Za-z]{3,}\/\d{4}/g,
          ""
        ).trim();

        // 4️⃣ عنوان افتراضي لو لسه فاضي
        if (!title) {
          title = "خبر جديد من نقابة مقاولي الإنشاءات الأردنيين";
        }

        items.push({ title, link });
      });

    // إزالة التكرار + تحديد العدد
    const unique = [];
    const seen = new Set();

    for (const it of items) {
      if (seen.has(it.link)) continue;
      seen.add(it.link);
      unique.push(it);
      if (unique.length >= limit) break;
    }

    return res.json({
      source: "JCCA",
      url: JCCA_NEWS_URL,
      items: unique,
    });
  } catch (err) {
    console.error("getJccaNews error:", err.message);
    return res.status(500).json({ message: "Failed to fetch JCCA news" });
  }
};
