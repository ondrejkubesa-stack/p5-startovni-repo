// Konfigurace Playwright · šablona P5.1 · ověřeno k 2026-10-07 proti https://playwright.dev/docs/test-webserver (volatilní)
// webServer: Playwright si před testy sám pustí vývojový server; když už běží (npm run dev), použije ho.
// Adresa je 127.0.0.1, ne localhost ani 0.0.0.0: `next dev` bez -H poslouchá na 0.0.0.0, tedy pro celou Wi-Fi
// (Next.js 16.4, `next dev --help`: „default: 0.0.0.0“). Skript dev v package.json proto musí být `next dev -H 127.0.0.1`.
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  use: { baseURL: 'http://127.0.0.1:3000' },
  webServer: {
    command: 'npm run dev',
    url: 'http://127.0.0.1:3000',
    reuseExistingServer: !process.env.CI,
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
