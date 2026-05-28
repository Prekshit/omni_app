import crypto from 'node:crypto';
import fs from 'node:fs';
import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import multer from 'multer';
import { createClient } from '@supabase/supabase-js';
import FirecrawlApp from '@mendable/firecrawl-js';
import { categories, categoryById } from './config/categories.js';
import { domainCategoryMap } from './config/domainMap.js';

dotenv.config();

const firecrawl = new FirecrawlApp({ apiKey: process.env.FIRECRAWL_API_KEY });

const {
  PORT = 3000,
  SERPAPI_KEY,
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  SUPABASE_BUCKET,
  SERPAPI_SHOPPING_GL = 'in',
  SERPAPI_SHOPPING_HL = 'en',
  SERPAPI_SHOPPING_GOOGLE_DOMAIN = 'google.co.in',
} = process.env;

const missingConfig = [
  ['SERPAPI_KEY', SERPAPI_KEY],
  ['SUPABASE_URL', SUPABASE_URL],
  ['SUPABASE_SERVICE_ROLE_KEY', SUPABASE_SERVICE_ROLE_KEY],
  ['SUPABASE_BUCKET', SUPABASE_BUCKET],
]
  .filter(([, value]) => !value)
  .map(([name]) => name);

if (missingConfig.length > 0) {
  throw new Error(`Missing env values: ${missingConfig.join(', ')}`);
}

const app = express();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 8 * 1024 * 1024,
  },
});

const supabase = createClient(
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  },
);

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ ok: true });
});

function log(...parts) {
  const message = parts
    .map((part) => {
      if (part instanceof Error) {
        return `${part.message}\n${part.stack || ''}`;
      }

      if (typeof part === 'string') {
        return part;
      }

      return JSON.stringify(part);
    })
    .join(' ');

  const line = `${new Date().toISOString()} ${message}`;

  console.log(line);
  fs.appendFile('omni-backend.log', `${line}\n`, () => {});
}

app.post(
  '/api/visual-search',
  upload.single('image'),
  async (req, res) => {
    let storagePath;
    const requestId = crypto.randomUUID().slice(0, 8);
    const startedAt = Date.now();
    const timingMs = {};

    try {
      if (!req.file) {
        return res.status(400).json({
          error: 'Missing image file. Send multipart/form-data image=<file>.',
        });
      }

      log(
        `[${requestId}] Received ${req.file.originalname || 'camera image'} (${Math.round(req.file.size / 1024)} KB)`,
      );

      const extension = getExtension(req.file.mimetype);
      storagePath = `visual-search/${Date.now()}-${crypto.randomUUID()}.${extension}`;

      log(`[${requestId}] Uploading to Supabase...`);

      let stepStartedAt = Date.now();
      const uploadResult = await withTimeout(
        supabase.storage
          .from(SUPABASE_BUCKET)
          .upload(storagePath, req.file.buffer, {
            contentType: req.file.mimetype || 'image/jpeg',
            upsert: false,
          }),
        15000,
        'Supabase upload timed out.',
      );
      timingMs.supabaseUpload = Date.now() - stepStartedAt;

      if (uploadResult.error) {
        throw uploadResult.error;
      }

      log(
        `[${requestId}] Supabase upload completed in ${timingMs.supabaseUpload} ms`,
      );

      log(`[${requestId}] Creating signed image URL...`);

      stepStartedAt = Date.now();
      const signedUrlResult = await withTimeout(
        supabase.storage
          .from(SUPABASE_BUCKET)
          .createSignedUrl(storagePath, 60 * 10),
        10000,
        'Supabase signed URL creation timed out.',
      );
      timingMs.signedUrl = Date.now() - stepStartedAt;

      if (signedUrlResult.error) {
        throw signedUrlResult.error;
      }

      log(
        `[${requestId}] Signed image URL created in ${timingMs.signedUrl} ms`,
      );

      log(`[${requestId}] Calling SerpApi Google Lens...`);

      stepStartedAt = Date.now();
      const { products, rawData: lensRawData } = await searchProductsWithGoogleLens(
        signedUrlResult.data.signedUrl,
        requestId,
      );
      timingMs.serpApi = Date.now() - stepStartedAt;

      log(
        `[${requestId}] SerpApi Google Lens completed in ${timingMs.serpApi} ms`,
      );

      stepStartedAt = Date.now();
      const { query: inferredQuery, source: querySource } = inferProductQuery(products, lensRawData);
      timingMs.inferQuery = Date.now() - stepStartedAt;

      let shoppingProducts = [];
      if (inferredQuery) {
        log(
          `[${requestId}] Calling SerpApi Google Shopping with query "${inferredQuery}"...`,
        );

        stepStartedAt = Date.now();
        try {
          shoppingProducts = await searchProductsWithGoogleShopping(
            inferredQuery,
            requestId,
          );
          timingMs.shoppingApi = Date.now() - stepStartedAt;

          log(
            `[${requestId}] SerpApi Google Shopping completed in ${timingMs.shoppingApi} ms`,
          );
        } catch (shoppingError) {
          timingMs.shoppingApi = Date.now() - stepStartedAt;
          log(
            `[${requestId}] SerpApi Google Shopping failed, continuing with Lens results only:`,
            shoppingError,
          );
        }
      } else {
        timingMs.shoppingApi = 0;
      }

      stepStartedAt = Date.now();
      const mergedProducts = mergeProducts(products, shoppingProducts);
      const scoredProducts = scoreProducts(mergedProducts, inferredQuery);
      const groupedCategories = groupProductsByCategory(scoredProducts);
      const categorySummary = summarizeCategories(groupedCategories);
      timingMs.normalizeAndGroup = Date.now() - stepStartedAt;
      timingMs.total = Date.now() - startedAt;

      writeDebugJson(`${requestId}-omni-products.json`, {
        requestId,
        inferredQuery,
        querySource,
        timingMs,
        categorySummary,
        sourceSummary: {
          lens: products.length,
          shopping: shoppingProducts.length,
          merged: scoredProducts.length,
        },
        categories: groupedCategories,
        products: scoredProducts,
      });

      log(
        `[${requestId}] Found ${scoredProducts.length} products in ${timingMs.total} ms`,
        { inferredQuery, querySource },
        timingMs,
        {
          lens: products.length,
          shopping: shoppingProducts.length,
          merged: scoredProducts.length,
        },
        categorySummary,
      );

      return res.json({
        products: scoredProducts,
        inferredQuery,
        querySource,
        timingMs,
        categorySummary,
        sourceSummary: {
          lens: products.length,
          shopping: shoppingProducts.length,
          merged: scoredProducts.length,
        },
        categories: groupedCategories,
      });
    } catch (error) {
      log(`[${requestId}] Visual search failed:`, error);

      return res.status(500).json({
        error: 'Visual search failed.',
        detail: error instanceof Error ? error.message : String(error),
      });
    } finally {
      if (storagePath) {
        await supabase.storage
          .from(SUPABASE_BUCKET)
          .remove([storagePath])
          .catch((error) => {
            log(`[${requestId}] Supabase cleanup failed:`, error);
          });
      }
    }
  },
);

async function searchProductsWithGoogleLens(imageUrl, requestId) {
  const searchUrl = new URL('https://serpapi.com/search.json');
  searchUrl.searchParams.set('engine', 'google_lens');
  searchUrl.searchParams.set('url', imageUrl);
  searchUrl.searchParams.set('type', 'products');
  searchUrl.searchParams.set('api_key', SERPAPI_KEY);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 50000);

  const response = await fetch(searchUrl, {
    signal: controller.signal,
  }).finally(() => {
    clearTimeout(timeout);
  });

  const data = await response.json();

  if (!response.ok || data.error) {
    throw new Error(data.error || `SerpApi failed with ${response.status}`);
  }

  writeDebugJson(`${requestId}-serpapi-lens-raw.json`, data);

  return {
    products: parseLensProducts(data),
    rawData: data,
  };
}

async function searchProductsWithGoogleShopping(query, requestId) {
  const searchUrl = new URL('https://serpapi.com/search.json');
  searchUrl.searchParams.set('engine', 'google_shopping');
  searchUrl.searchParams.set('q', query);
  searchUrl.searchParams.set('gl', SERPAPI_SHOPPING_GL);
  searchUrl.searchParams.set('hl', SERPAPI_SHOPPING_HL);
  searchUrl.searchParams.set(
    'google_domain',
    SERPAPI_SHOPPING_GOOGLE_DOMAIN,
  );
  searchUrl.searchParams.set('api_key', SERPAPI_KEY);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 50000);

  const response = await fetch(searchUrl, {
    signal: controller.signal,
  }).finally(() => {
    clearTimeout(timeout);
  });

  const data = await response.json();

  if (!response.ok || data.error) {
    throw new Error(data.error || `SerpApi shopping failed with ${response.status}`);
  }

  writeDebugJson(`${requestId}-serpapi-shopping-raw.json`, data);

  return parseShoppingProducts(data);
}

function writeDebugJson(fileName, data) {
  fs.mkdirSync('debug', { recursive: true });
  fs.writeFileSync(
    `debug/${fileName}`,
    JSON.stringify(data, null, 2),
  );
}

function withTimeout(promise, timeoutMs, message) {
  let timeout;

  const timeoutPromise = new Promise((_, reject) => {
    timeout = setTimeout(() => reject(new Error(message)), timeoutMs);
  });

  return Promise.race([promise, timeoutPromise]).finally(() => {
    clearTimeout(timeout);
  });
}

function parseLensProducts(data) {
  return parseSearchProducts(data, [
    data.shopping_results,
    data.visual_matches,
    data.exact_matches,
  ], 'lens');
}

function parseShoppingProducts(data) {
  return parseSearchProducts(data, [
    data.shopping_results,
    data.featured_shopping_results,
    data.inline_shopping_results,
  ], 'shopping');
}

function parseSearchProducts(data, collections, sourceType) {
  const candidates = [
    ...collections.filter(Array.isArray).flat(),
  ];

  const seen = new Set();

  return candidates
    .map((item, index) => toOmniProduct(item, index + 1, sourceType))
    .filter((product) => {
      if (!product.title || !product.shoppingLink) {
        return false;
      }

      const key = `${product.title}|${product.shoppingLink}`;

      if (seen.has(key)) {
        return false;
      }

      seen.add(key);
      return true;
    });
}

function mergeProducts(...productGroups) {
  const merged = [];
  const seen = new Set();

  for (const group of productGroups) {
    for (const product of group) {
      const key = buildProductKey(product);

      if (seen.has(key)) {
        continue;
      }

      seen.add(key);
      merged.push(product);
    }
  }

  return merged;
}

/**
 * Strips leading marketplace prefixes (e.g. "Amazon.in: Buy ") and trailing
 * marketplace suffixes (e.g. ": Amazon.de: Computer & Accessories") from a
 * raw SerpApi product title so the actual product name can be used for
 * Shopping API queries without marketplace name pollution.
 */
function cleanProductTitle(title = '') {
  return title
    // Strip leading "Domain.tld: Buy " or "Domain.tld: "
    .replace(/^[\w.-]+\.[a-z]{2,}(?:\.[a-z]{2,})?:\s*(?:buy\s+)?/i, '')
    // Strip trailing ": Domain.tld: ..." (e.g. ": Amazon.de: Computer & Accessories")
    .replace(/\s*:\s*[\w.-]+\.[a-z]{2,}(?:\.[a-z]{2,})?[:\s].*$/i, '')
    // Strip trailing " - Domain.tld" (e.g. "Video Games - Amazon.com")
    .replace(/\s*-\s*[\w.-]+\.[a-z]{2,}(?:\.[a-z]{2,})?$/i, '')
    // Strip trailing " | Category" type endings
    .replace(/\s*\|[^|]{1,60}$/i, '')
    .trim();
}

/**
 * Builds a clean Shopping API query string from a product title by
 * tokenizing, filtering stop words, and joining the top 6 tokens.
 */
function buildQueryFromTitle(title) {
  return tokenizeProductText(title)
    .filter((token) => !queryStopWords.has(token))
    .slice(0, 6)
    .join(' ');
}

/**
 * Hybrid query inference — three stages in priority order:
 *
 * Stage 1 – Exact matches: if SerpApi Lens returned confirmed exact_matches,
 *   use the first one's cleaned title (highest precision).
 *
 * Stage 2 – Position-1 anchor: clean the top Lens result title and extract
 *   its brand.
 *   • High confidence   → brand found AND position-2 shares the same brand.
 *   • Medium confidence → brand found, position-2 differs or is absent.
 *   • No brand          → use cleaned position-1 title directly if non-trivial.
 *
 * Stage 3 – Consensus fallback: original weighted-token approach, now safe
 *   because marketplace names are excluded via queryStopWords.
 */
function inferProductQuery(products, lensRawData) {
  if (!products || products.length === 0) {
    return { query: '', source: 'empty' };
  }

  // ── Stage 1: Exact matches from raw Lens response (highest confidence) ──
  const exactMatches = lensRawData?.exact_matches;
  if (Array.isArray(exactMatches) && exactMatches.length > 0) {
    const cleaned = cleanProductTitle(exactMatches[0].title || '');
    if (cleaned.length > 5) {
      return { query: buildQueryFromTitle(cleaned), source: 'exact_match' };
    }
  }

  // ── Stage 2: Position-1 anchor with brand confidence check ──
  const top1 = products[0];
  const top2 = products[1];

  if (top1?.title) {
    const cleaned1 = cleanProductTitle(top1.title);
    const brand1 = tokenizeProductText(cleaned1).find((t) => knownBrands.has(t));

    if (brand1) {
      // High confidence: position-2 shares the same brand
      if (top2?.title) {
        const brand2 = tokenizeProductText(cleanProductTitle(top2.title))
          .find((t) => knownBrands.has(t));

        if (brand1 === brand2) {
          return {
            query: buildQueryFromTitle(cleaned1),
            source: 'position1_high_confidence',
          };
        }
      }

      // Medium confidence: brand found but position-2 disagrees or is absent
      return {
        query: buildQueryFromTitle(cleaned1),
        source: 'position1_medium_confidence',
      };
    }

    // No known brand but the cleaned title is long enough to be useful
    if (cleaned1.length > 5) {
      return {
        query: buildQueryFromTitle(cleaned1),
        source: 'position1_no_brand',
      };
    }
  }

  // ── Stage 3: Weighted-token consensus fallback ──
  // Marketplace names are already excluded via queryStopWords so 'amazon' etc.
  // can no longer hijack the brand slot.
  return { query: inferQueryByConsensus(products), source: 'consensus' };
}

/**
 * Original position-weighted consensus approach, kept as the Stage-3 fallback
 * for generic/unbranded products where no clean position-1 title is available.
 */
function inferQueryByConsensus(products) {
  const tokenScores = new Map();

  products.slice(0, 12).forEach((product, index) => {
    const weight = Math.max(1, 12 - index);
    const tokens = tokenizeProductText(product.title);

    for (const token of tokens) {
      if (queryStopWords.has(token)) {
        continue;
      }

      tokenScores.set(
        token,
        (tokenScores.get(token) ?? 0) + weight,
      );
    }
  });

  const rankedTokens = [...tokenScores.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([token]) => token);

  const brand = rankedTokens.find((token) => knownBrands.has(token));
  const importantTokens = rankedTokens.filter(
    (token) => token !== brand && !accessoryTerms.has(token),
  );

  return [brand, ...importantTokens]
    .filter(Boolean)
    .slice(0, 6)
    .join(' ');
}

function scoreProducts(products, inferredQuery) {
  const queryTokens = tokenizeProductText(inferredQuery);
  const primaryBrand = queryTokens.find((token) => knownBrands.has(token));
  const queryWithoutBrand = queryTokens.filter(
    (token) => token !== primaryBrand,
  );

  return products
    .map((product) => {
      const scoring = scoreProduct({
        product,
        queryTokens,
        queryWithoutBrand,
        primaryBrand,
      });

      return {
        ...product,
        relevanceScore: scoring.score,
        scoreReasons: scoring.reasons,
      };
    })
    .sort((a, b) => {
      if (b.relevanceScore !== a.relevanceScore) {
        return b.relevanceScore - a.relevanceScore;
      }

      return a.visualRank - b.visualRank;
    });
}

function scoreProduct({
  product,
  queryTokens,
  queryWithoutBrand,
  primaryBrand,
}) {
  let score = Math.max(0, 42 - product.visualRank);
  const reasons = [`visual_rank:${product.visualRank}`];
  const text = `${product.title} ${product.source} ${product.domain}`
    .toLowerCase();
  const productTokens = tokenizeProductText(text);
  const productTokenSet = new Set(productTokens);

  for (const token of queryTokens) {
    if (productTokenSet.has(token)) {
      score += 12;
      reasons.push(`query_token:${token}`);
    }
  }

  if (
    queryWithoutBrand.length >= 2 &&
    queryWithoutBrand.every((token) => productTokenSet.has(token))
  ) {
    score += 18;
    reasons.push('model_tokens_matched');
  }

  if (primaryBrand && productTokenSet.has(primaryBrand)) {
    score += 18;
    reasons.push(`brand_matched:${primaryBrand}`);
  }

  if (primaryBrand) {
    const differentBrand = [...knownBrands].find(
      (brand) => brand !== primaryBrand && productTokenSet.has(brand),
    );

    if (differentBrand) {
      score -= 35;
      reasons.push(`different_brand_penalty:${differentBrand}`);
    }
  }

  if (
    containsAny(text, [...accessoryTerms]) &&
    !queryTokens.some((token) => accessoryTerms.has(token))
  ) {
    score -= 24;
    reasons.push('accessory_penalty');
  }

  const categoryBoosts = {
    indian_ecommerce: 14,
    quick_commerce: 13,
    bulk: 8,
    international: 4,
    second_hand: 3,
    other: 0,
  };
  const categoryBoost = categoryBoosts[product.categoryId] ?? 0;

  if (categoryBoost > 0) {
    score += categoryBoost;
    reasons.push(`category_boost:${product.categoryTitle}`);
  }

  if (product.image) {
    score += 3;
    reasons.push('has_image');
  }

  if (product.price) {
    score += 3;
    reasons.push('has_price');
  }

  return {
    score,
    reasons,
  };
}

function groupProductsByCategory(products) {
  return categories.map((category) => ({
    id: category.id,
    title: category.title,
    products: products
      .filter((product) => product.categoryId === category.id)
      .slice(0, 25),
  }));
}

function summarizeCategories(groupedCategories) {
  return groupedCategories.map((category) => ({
    id: category.id,
    title: category.title,
    count: category.products.length,
  }));
}

function toOmniProduct(item, fallbackRank, sourceType = 'lens') {
  const shoppingLink = firstString(
    item.link,
    item.product_link,
    item.redirect_link,
  );
  let domain = extractDomain(shoppingLink);
  const title = firstString(item.title, item.name);
  const source = firstString(item.source, item.seller, item.domain);

  // Restore true seller domain if the parsed domain is a Google shopping comparison link
  if ((domain.includes('google.') || !domain) && source) {
    const cleanedSource = source.toLowerCase().trim().replace(/\s+/g, '');
    if (cleanedSource.includes('.') && !cleanedSource.includes(' ') && !cleanedSource.includes('/')) {
      domain = cleanedSource;
    }
  }

  const categorization = categorizeProduct({
    domain,
    source,
    title,
  });

  const categoryId = categorization.categoryId;
  const category = categoryById[categoryId] ?? categoryById.other;

  return {
    title,
    image: firstString(item.thumbnail, item.image, item.source_icon),
    price: firstString(item.price, item.extracted_price),
    source,
    shoppingLink,
    domain,
    visualRank: Number(item.position) || fallbackRank,
    categoryId,
    categoryTitle: category.title,
    categoryReason: categorization.reason,
    sourceType,
  };
}

function buildProductKey(product) {
  return [
    normalizeText(product.title),
    product.domain || '',
    normalizeLink(product.shoppingLink),
  ].join('|');
}

function normalizeText(value = '') {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function normalizeLink(link = '') {
  if (!link) {
    return '';
  }

  try {
    const url = new URL(link);
    url.hash = '';
    url.search = '';
    return url.toString().toLowerCase();
  } catch (_error) {
    return link.toLowerCase().trim();
  }
}

function categorizeProduct({
  domain,
  source = '',
  title = '',
}) {
  if (!domain) {
    return {
      categoryId: 'other',
      reason: 'fallback:missing_domain',
    };
  }

  const directMatch = domainCategoryMap[domain];

  if (directMatch) {
    return {
      categoryId: directMatch,
      reason: `domain_map:${domain}`,
    };
  }

  const parentDomain = findMappedParentDomain(domain);

  if (parentDomain) {
    return {
      categoryId: domainCategoryMap[parentDomain],
      reason: `parent_domain_map:${parentDomain}`,
    };
  }

  const text = `${domain} ${source} ${title}`.toLowerCase();

  if (isSecondHandResult(domain, text)) {
    return {
      categoryId: 'second_hand',
      reason: 'heuristic:second_hand',
    };
  }

  if (isBulkResult(domain, text)) {
    return {
      categoryId: 'bulk',
      reason: 'heuristic:bulk',
    };
  }

  if (isQuickCommerceResult(domain, text)) {
    return {
      categoryId: 'quick_commerce',
      reason: 'heuristic:quick_commerce',
    };
  }

  if (isGlobalMarketplaceResult(domain, text)) {
    return {
      categoryId: 'international',
      reason: 'heuristic:global_marketplace',
    };
  }

  if (domain.endsWith('.in') || domain.endsWith('.co.in')) {
    return {
      categoryId: 'indian_ecommerce',
      reason: 'heuristic:india_tld',
    };
  }

  return {
    categoryId: 'other',
    reason: 'fallback:other',
  };
}

function isSecondHandResult(domain, text) {
  return matchesAnyDomain(domain, [
    'resellpur.com',
    'ownpetz.com',
    'carousell.com',
    'facebook.com',
    'craigslist.org',
    'backmarket.com',
    'swappa.com',
    'gazelle.com',
  ]) ||
      containsAny(text, [
        'used',
        'pre-owned',
        'pre owned',
        'refurbished',
        'renewed',
        'second hand',
        'resale',
      ]);
}

function isBulkResult(domain, text) {
  return matchesAnyDomain(domain, [
    'indiamart.com',
    'tradeindia.com',
    'alibaba.com',
    'made-in-china.com',
    'globalsources.com',
    'dhgate.com',
    'moglix.com',
    'moglix.in',
    'industrybuying.com',
    'industrybuying.in',
  ]) ||

      containsAny(text, [
        'wholesale',
        'bulk',
        'supplier',
        'b2b',
        'manufacturer',
        'distributor',
      ]);
}

function isQuickCommerceResult(domain, text) {
  return matchesAnyDomain(domain, [
    'blinkit.com',
    'zeptonow.com',
    'zepto.in',
    'swiggy.com',
    'dunzo.com',
    'bigbasket.com',
    'jiomart.com',
    'minutes.flipkart.com',
    'dmart.in',
    'dmartready.com',
    'kpnfresh.com',
    'kpnfresh.in',
    'quicksnick.com',
  ]) ||
      containsAny(text, [
        'instamart',
        'zepto',
        'blinkit',
        'bigbasket',
        'dunzo',
        'gopuff',
        'jiomart',
        'kpnfresh',
        'kpn fresh',
        'dmart',
        'quicksnick',
        'quick delivery',
        'minutes',
        '10 minute',
        'same day',
      ]);
}

function isGlobalMarketplaceResult(domain, text) {
  return matchesAnyDomain(domain, [
    'amazon.',
    'ebay.',
    'aliexpress.',
    'mercadolibre.',
    'mercadolibre.com',
    'ozon.',
    'kaspi.kz',
    'microless.com',
    'ubuy.',
    'desertcart.',
    'snapklik.com',
    'crutchfield.com',
    'eustore.gr',
    'asasonline.net',
    'kiyoso.com.my',
    'ekobo.co',
    'foegioielli.it',
  ]) ||
      containsAny(text, [
        'global shipping',
        'international',
        'mercado libre',
        'aliexpress',
        'amazon uk',
        'amazon.it',
        'amazon.com.be',
        'ebay',
        'ozon',
      ]);
}

function matchesAnyDomain(domain, patterns) {
  return patterns.some((pattern) => {
    if (pattern.endsWith('.')) {
      return domain === pattern.slice(0, -1) ||
          domain.startsWith(pattern);
    }

    return domain === pattern || domain.endsWith(`.${pattern}`);
  });
}

function containsAny(text, terms) {
  return terms.some((term) => text.includes(term));
}

function tokenizeProductText(text = '') {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .split(' ')
    .map((token) => token.trim())
    .filter((token) => token.length >= 2 || /^\d+$/.test(token));
}

const knownBrands = new Set([
  // ── Smartphones & Tablets ──────────────────────────────────────────
  'acer',
  'apple',
  'asus',
  'google',
  'huawei',
  'infinix',
  'iqoo',
  'itel',
  'lava',
  'lenovo',
  'micromax',
  'motorola',
  'nothing',
  'oneplus',
  'oppo',
  'poco',
  'realme',
  'redmi',
  'samsung',
  'tecno',
  'vivo',
  'xiaomi',

  // ── Audio & Wearables ──────────────────────────────────────────────
  'airpods',
  'ambrane',
  'anker',
  'beats',
  'boat',
  'bose',
  'boult',
  'dizo',
  'jabra',
  'jbl',
  'marshall',
  'mi',
  'mifo',
  'mivi',
  'noise',
  'nuraphone',
  'ptron',
  'sennheiser',
  'shure',
  'skullcandy',
  'sony',

  // ── Laptops, PCs & Peripherals ─────────────────────────────────────
  'corsair',
  'dell',
  'hp',
  'hyperx',
  'logitech',
  'microsoft',
  'razer',
  'steelseries',
  'surface',

  // ── Cameras & Action Cams ─────────────────────────────────────────
  'canon',
  'dji',
  'fujifilm',
  'gopro',
  'nikon',
  'olympus',
  'panasonic',

  // ── Home Appliances & Electronics ─────────────────────────────────
  'dyson',
  'godrej',
  'haier',
  'iffalcon',
  'lg',
  'lloyd',
  'philips',
  'tcl',
  'voltas',
  'vu',
  'whirlpool',

  // ── Indian Accessories & Gadgets ──────────────────────────────────
  'portronics',
  'zebronics',

  // ── Fitness & Wearables ───────────────────────────────────────────
  'fastrack',
  'fitbit',
  'garmin',
  'noise',

  // ── Fashion & Footwear ────────────────────────────────────────────
  'adidas',
  'bata',
  'crocs',
  'levis',
  'levi',
  'nike',
  'puma',
  'reebok',
  'woodland',

  // ── Watches & Jewellery ───────────────────────────────────────────
  'casio',
  'fossil',
  'titan',

  // ── Gaming ───────────────────────────────────────────────────────
  'nintendo',
  'playstation',
  'xbox',
]);

const accessoryTerms = new Set([
  'adapter',
  'bag',
  'cable',
  'case',
  'charger',
  'charging',
  'cover',
  'protector',
  'skin',
  'sleeve',
  'stand',
]);

// Marketplace and platform names that must never influence the inferred
// product query — they appear in nearly every SerpApi title string and
// would otherwise hijack brand detection.
const marketplaceNames = new Set([
  'amazon',
  'aliexpress',
  'bestbuy',
  'ebay',
  'flipkart',
  'meesho',
  'myntra',
  'snapdeal',
  'walmart',
]);

const queryStopWords = new Set([
  ...accessoryTerms,
  ...marketplaceNames,
  'and',
  'best',
  'bluetooth',
  'buy',
  'compatible',
  'electronics',
  'for',
  'free',
  'genuine',
  'global',
  'india',
  'new',
  'official',
  'online',
  'original',
  'price',
  'pro',
  'sale',
  'shop',
  'store',
  'tws',
  'true',
  'wireless',
  'with',
]);

function findMappedParentDomain(domain) {
  const parts = domain.split('.');

  for (let index = 1; index < parts.length - 1; index += 1) {
    const parent = parts.slice(index).join('.');

    if (domainCategoryMap[parent]) {
      return parent;
    }
  }

  return '';
}

function extractDomain(link) {
  if (!link) {
    return '';
  }

  try {
    return new URL(link).hostname
      .toLowerCase()
      .replace(/^www\./, '');
  } catch (_error) {
    return '';
  }
}

function firstString(...values) {
  for (const value of values) {
    if (typeof value === 'string' && value.trim()) {
      return value.trim();
    }

    if (typeof value === 'number') {
      return String(value);
    }
  }

  return '';
}

function getExtension(mimeType = '') {
  if (mimeType.includes('png')) {
    return 'png';
  }

  if (mimeType.includes('webp')) {
    return 'webp';
  }

  return 'jpg';
}

app.get('/api/user-profile', (_req, res) => {
  res.json({
    name: 'Prekshit',
    address: '246, Green Glen Layout, Belandur, Bangalore',
    contact: '9999888822',
    creditCard: '**** **** **** *007'
  });
});

app.post('/api/product-details', express.json(), async (req, res) => {
  const { url } = req.body;
  if (!url) {
    return res.status(400).json({ error: 'URL is required' });
  }

  log(`[Product Details] Scraping URL: ${url}`);
  try {
    const response = await firecrawl.scrapeUrl(url, {
      formats: [{
        type: 'json',
        schema: {
          type: 'object',
          properties: {
            productName: { type: 'string' },
            images: { type: 'array', items: { type: 'string' } },
            description: { type: 'string' },
            specifications: { type: 'string' },
            sellerInfo: { type: 'string' },
            rating: { type: 'string' }
          },
          required: ['productName', 'images', 'description']
        }
      }]
    });

    if (response.success && response.json) {
      log(`[Product Details] Successfully extracted data for ${url}`);
      return res.json(response.json);
    } else {
      log(`[Product Details] Extraction failed or no data: ${JSON.stringify(response)}`);
      return res.status(500).json({ error: 'Failed to extract data' });
    }
  } catch (error) {
    log(`[Product Details] Error: ${error.message}`);
    return res.status(500).json({ error: error.message });
  }
});

app.listen(Number(PORT), '0.0.0.0', () => {
  log(`Omni visual search backend running on port ${PORT}`);
});

