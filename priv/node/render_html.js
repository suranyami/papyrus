#!/usr/bin/env node
/**
 * HTML to PNG renderer using Puppeteer
 *
 * Usage:
 *   node render_html.js --width 800 --height 480 --input file.html
 *   node render_html.js --width 800 --height 480 --url https://example.com
 *
 * Output: PNG binary to stdout
 */

const puppeteer = require('puppeteer');
const fs = require('fs');

// Parse command-line arguments
function parseArgs(args) {
  const result = {
    width: 800,
    height: 600,
    url: null,
    inputFile: null
  };

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--width' && args[i + 1]) {
      result.width = parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === '--height' && args[i + 1]) {
      result.height = parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === '--url' && args[i + 1]) {
      result.url = args[i + 1];
      i++;
    } else if (args[i] === '--input' && args[i + 1]) {
      result.inputFile = args[i + 1];
      i++;
    }
  }

  return result;
}

// Main rendering function
async function render() {
  const args = parseArgs(process.argv.slice(2));

  let browser;
  try {
    // Launch Puppeteer with options for maximum compatibility
    browser = await puppeteer.launch({
      headless: 'new',
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--disable-web-security',
        '--disable-features=IsolateOrigins,site-per-process',
        '--font-render-hinting=none',
        '--no-zygote',
        '--single-process'
      ]
    });

    const page = await browser.newPage();

    // Set viewport to exact dimensions
    await page.setViewport({
      width: args.width,
      height: args.height,
      deviceScaleFactor: 1
    });

    if (args.url) {
      // Render URL
      await page.goto(args.url, {
        waitUntil: 'networkidle0',
        timeout: 30000
      });
    } else if (args.inputFile) {
      // Render HTML from file
      const html = fs.readFileSync(args.inputFile, 'utf8');
      await page.setContent(html, {
        waitUntil: 'load',
        timeout: 30000
      });
    } else {
      console.error('Error: Either --url or --input must be provided');
      process.exit(1);
    }

    // Capture screenshot as PNG binary
    const screenshot = await page.screenshot({
      type: 'png',
      fullPage: false,
      omitBackground: false
    });

    // Write PNG binary to stdout
    process.stdout.write(screenshot);

  } catch (error) {
    console.error('Renderer error:', error.message);
    process.exit(1);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

// Run the renderer
render().catch(err => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
