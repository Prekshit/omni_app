import dotenv from 'dotenv';
import FirecrawlApp from '@mendable/firecrawl-js';

dotenv.config();

const firecrawl = new FirecrawlApp({ apiKey: process.env.FIRECRAWL_API_KEY });

async function test() {
  console.log('Starting scrape...');
  try {
    const url = 'https://www.amazon.in/Puma-Mens-Quest-Running-Shoe/dp/B0FNC7FVWF';
    const response = await firecrawl.scrapeUrl(url, {
      formats: [{
        type: 'json',
        schema: {
          type: 'object',
          properties: {
            productName: { type: 'string' }
          }
        }
      }]
    });
    console.log('Response:', JSON.stringify(response, null, 2));
  } catch (err) {
    console.error('Error caught:', err);
  }
}

test();
