import { defineConfig, devices } from "@playwright/test";

// Runs against the LIVE deployed app (design-v2). Specs use absolute URLs
// (Studio at /studio, Runtime at root). Auth via a one-time setup that saves
// storageState (shared origin → authenticates both surfaces).
export default defineConfig({
  testDir: "./e2e-live",
  fullyParallel: false,
  workers: 1,
  retries: 1,
  timeout: 60000,
  expect: { timeout: 15000 },
  reporter: [["list"]],
  use: {
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    ignoreHTTPSErrors: true,
  },
  projects: [
    { name: "setup", testMatch: /auth\.setup\.ts/, use: { ...devices["Desktop Chrome"] } },
    {
      name: "chromium",
      testIgnore: [/auth\.setup\.ts/, /_smoke\.spec\.ts/],
      use: { ...devices["Desktop Chrome"], storageState: ".auth/live-state.json" },
      dependencies: ["setup"],
    },
  ],
});
