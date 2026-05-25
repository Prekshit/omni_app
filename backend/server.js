import crypto from 'node:crypto';
import fs from 'node:fs';
import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import multer from 'multer';
import { createClient } from '@supabase/supabase-js';
import { categories, categoryById } from './config/categories.js';
import { domainCategoryMap } from './config/domainMap.js';

dotenv.config();

const {
  PORT = 3000,
  SERPAPI_KEY,
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  SUPABASE_BUCKET,
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

      if (uploadResult.error) {
        throw uploadResult.error;
      }

      log(`[${requestId}] Creating signed image URL...`);

      const signedUrlResult = await withTimeout(
        supabase.storage
          .from(SUPABASE_BUCKET)
          .createSignedUrl(storagePath, 60 * 10),
        10000,
        'Supabase signed URL creation timed out.',
      );

      if (signedUrlResult.error) {
        throw signedUrlResult.error;
      }

      log(`[${requestId}] Calling SerpApi Google Lens...`);

      const products = await searchProductsWithGoogleLens(
        signedUrlResult.data.signedUrl,
        requestId,
      );
      const groupedCategories = groupProductsByCategory(products);
      const categorySummary = summarizeCategories(groupedCategories);

      writeDebugJson(`${requestId}-omni-products.json`, {
        requestId,
        categorySummary,
        categories: groupedCategories,
        products,
      });

      log(
        `[${requestId}] Found ${products.length} products in ${Date.now() - startedAt} ms`,
        categorySummary,
      );

      return res.json({
        products,
        categorySummary,
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
  const timeout = setTimeout(() => controller.abort(), 30000);

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

  return parseLensProducts(data);
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
  const candidates = [
    data.shopping_results,
    data.visual_matches,
    data.exact_matches,
  ]
    .filter(Array.isArray)
    .flat();

  const seen = new Set();

  return candidates
    .map(toOmniProduct)
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

function toOmniProduct(item) {
  const shoppingLink = firstString(
    item.link,
    item.product_link,
    item.redirect_link,
  );
  const domain = extractDomain(shoppingLink);
  const categoryId = categorizeDomain(domain);
  const category = categoryById[categoryId] ?? categoryById.other;

  return {
    title: firstString(item.title, item.name),
    image: firstString(item.thumbnail, item.image, item.source_icon),
    price: firstString(item.price, item.extracted_price),
    source: firstString(item.source, item.seller, item.domain),
    shoppingLink,
    domain,
    categoryId,
    categoryTitle: category.title,
  };
}

function categorizeDomain(domain) {
  if (!domain) {
    return 'other';
  }

  const directMatch = domainCategoryMap[domain];

  if (directMatch) {
    return directMatch;
  }

  const parentDomain = findMappedParentDomain(domain);

  if (parentDomain) {
    return domainCategoryMap[parentDomain];
  }

  if (domain.endsWith('.in') || domain.endsWith('.co.in')) {
    return 'indian_ecommerce';
  }

  return 'other';
}

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

app.listen(Number(PORT), '0.0.0.0', () => {
  log(`Omni visual search backend running on port ${PORT}`);
});
