const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: 'e2e',
  webServer: {
    command: 'npx serve -l 8123 --no-clipboard build/web',
    url: 'http://127.0.0.1:8123/index.html',
    reuseExistingServer: false,
  },
  use: { baseURL: 'http://127.0.0.1:8123' },
});
