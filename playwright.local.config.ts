import { defineConfig, devices } from "@playwright/test";

// Local-harness config for verifying design-v2 backlog changes against the
// locally-served Studio (vite :3000, base /studio/) + SQLite-backed backend
// (:8001). Mirrors playwright.live.config.ts but targets localhost and only the
// surfaces touched by the current item.
export default defineConfig({
  testDir: "./e2e-local",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 120000,
  expect: { timeout: 15000 },
  reporter: [["list"]],
  use: {
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    ignoreHTTPSErrors: true,
  },
  projects: [
    { name: "setup", testMatch: /auth\.setup\.local\.ts/, use: { ...devices["Desktop Chrome"] } },
    {
      name: "chromium",
      testIgnore: [/auth\.setup\.local\.ts/],
      use: { ...devices["Desktop Chrome"], storageState: ".auth/local-state.json" },
      dependencies: ["setup"],
    },
  ],
});
