const axios = require("axios");
const cheerio = require("cheerio");

// مصدر الأخبار من موقع نقابة المقاولين
const JCCA_NEWS_URL = "https://www.jcca.org.jo/NewsArchive.aspx?lang=ar";

// ===== In-memory cache =====
let cache = {
  at: 0,
  items: [],
};
const CACHE_TTL = 10 * 60 * 1000; // 10 minutes

// GET /api/public/jcca-news?limit=5
exports.getJccaNews = async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit || "5", 10), 20);

    // ✅ cache
    if (Date.now() - cache.at < CACHE_TTL && cache.items.length > 0) {
      return res.json({
        source: "JCCA",
        url: JCCA_NEWS_URL,
        cached: true,
        fetchedAt: new Date(cache.at).toISOString(),
        items: cache.items.slice(0, limit),
      });
    }

    const { data: html } = await axios.get(JCCA_NEWS_URL, {
      timeout: 15000,
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123 Safari/537.36",
        "Accept-Language": "ar,en;q=0.9",
      },
    });

    const $ = cheerio.load(html);
    const items = [];

    $("a")
      .filter((_, el) => ($(el).attr("href") || "").includes("NewsDetails"))
      .each((_, el) => {
        const href = $(el).attr("href");
        if (!href) return;

        const link = href.startsWith("http")
          ? href
          : `https://www.jcca.org.jo/${href.replace(/^\//, "")}`;

        let title = $(el).text().replace(/\s+/g, " ").trim();

        if (!title) {
          title = $(el)
            .closest("tr, li, div")
            .text()
            .replace("مشاهدة التفاصيل", "")
            .replace(/\s+/g, " ")
            .trim();
        }

        // تنظيف التواريخ
        title = title
          .replace(
            /\d{1,2}\/\d{1,2}\/\d{4}|\d{1,2}\/[A-Za-z]{3,}\/\d{4}/g,
            ""
          )
          .trim();

        if (!title || title.length < 6) {
          title = "JCCA News";
        }

        items.push({ title, link });
      });

    // إزالة التكرار
    const unique = [];
    const seen = new Set();

    for (const it of items) {
      if (seen.has(it.link)) continue;
      seen.add(it.link);
      unique.push(it);
      if (unique.length >= 20) break;
    }

    cache = { at: Date.now(), items: unique };

    return res.json({
      source: "JCCA",
      url: JCCA_NEWS_URL,
      cached: false,
      fetchedAt: new Date(cache.at).toISOString(),
      items: unique.slice(0, limit),
    });
  } catch (err) {
    console.error("getJccaNews error:", err.message);
    return res.status(500).json({ message: "Failed to fetch JCCA news" });
  }
};
