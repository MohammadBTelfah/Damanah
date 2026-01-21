const axios = require("axios");
const cheerio = require("cheerio");

const JCCA_NEWS_URL = "https://www.jcca.org.jo/NewsArchive.aspx";
const BASE = "https://www.jcca.org.jo";

// GET /api/public/jcca-news?limit=5
exports.getJccaNews = async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit || "5", 10), 20);

    let html = null;
    let usedUrl = JCCA_NEWS_URL;

    const fetchPage = async (url) => {
      const r = await axios.get(url, {
        timeout: 15000,
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123 Safari/537.36",
        },
      });
      return r.data;
    };

    try {
      html = await fetchPage(usedUrl);
    } catch (_) {
      // ✅ fallback إذا احتاج lang=ar
      usedUrl = `${JCCA_NEWS_URL}?lang=ar`;
      html = await fetchPage(usedUrl);
    }

    const $ = cheerio.load(html);

    const items = [];
    const seen = new Set();

    // ✅ روابط الأخبار الصحيحة حالياً: News.aspx?id=...
    const selectors = [
      'a[href*="News.aspx?id="]',
      'a[href*="news.aspx?id="]',
    ];

    $(selectors.join(",")).each((_, el) => {
      const href = $(el).attr("href");
      if (!href) return;

      // link absolute
      const link = href.startsWith("http")
        ? href
        : `${BASE}/${href.replace(/^\//, "")}`;

      if (seen.has(link)) return;

      let title = $(el).text().replace(/\s+/g, " ").trim();

      if (!title || title.includes("مشاهدة") || title.length < 4) {
        title = $(el)
          .closest("tr, li, div")
          .text()
          .replace(/\s+/g, " ")
          .trim();
      }

      // تنظيف
      title = title
        .replace("", "")
        .replace("مشاهدة التفاصيل", "")
        .replace("View Details", "")
        .replace(/\d{1,2}\/[A-Za-z]{3,}\/\d{4}/g, "") // 07/December/2025
        .replace(/\d{1,2}\/\d{1,2}\/\d{4}/g, "")      // 07/12/2025
        .replace(/\s+/g, " ")
        .trim();

      if (!title) title = "New update from JCCA";

      seen.add(link);
      items.push({ title, link });
    });

    // ✅ لو ما لقينا شيء نهائياً
    if (items.length === 0) {
      return res.json({
        source: "JCCA",
        url: usedUrl,
        items: [],
        message:
          "No news items found. The website structure may have changed.",
      });
    }

    return res.json({
      source: "JCCA",
      url: usedUrl,
      items: items.slice(0, limit),
    });
  } catch (err) {
    console.error("getJccaNews error:", err.message);
    return res.status(500).json({ message: "Failed to fetch JCCA news" });
  }
};
