import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@yhcrames/shared": path.resolve(__dirname, "frontend/shared/src"),
    },
  },
  test: {
    globals: true,
    environment: "jsdom",
    // vitest's default is 5000ms, which was never a deliberate choice for this
    // suite. jsdom + antd renders here legitimately take seconds (the heaviest
    // form tests sit around 3s serially), so under the default 10-way file
    // parallelism contention pushed borderline tests over the line and the
    // failing set changed from run to run -- 25/30/33 failures with different
    // members on an identical tree. That made "is the suite green?"
    // unanswerable. The ceiling is now far enough above real cost that only a
    // genuine hang reaches it; it does not slow passing runs down.
    testTimeout: 20000,
    hookTimeout: 20000,
    globalSetup: ["./frontend/shared/src/test/global-setup.ts"],
    setupFiles: ["./frontend/shared/src/test/setup.ts"],
    include: [
      "frontend/**/*.test.{ts,tsx}",
      "frontend/**/*.spec.{ts,tsx}",
    ],
    exclude: ["node_modules", "dist", "e2e"],
    css: true,
    coverage: {
      provider: "v8",
      reporter: ["text", "text-summary", "lcov", "html"],
      reportsDirectory: "./coverage/frontend",
      include: [
        "frontend/shared/src/components/PageShell.tsx",
        "frontend/shared/src/components/StatusBadge.tsx",
        "frontend/shared/src/components/EmptyState.tsx",
        "frontend/shared/src/components/ErrorState.tsx",
        "frontend/shared/src/components/FormField.tsx",
        "frontend/shared/src/components/ErrorBoundary.tsx",
        "frontend/shared/src/components/SkipLinks.tsx",
        "frontend/shared/src/components/SkeletonTable.tsx",
        "frontend/shared/src/components/LoginPage.tsx",
        "frontend/shared/src/components/HeaderUser.tsx",
        "frontend/shared/src/utils/platform.ts",
        "frontend/shared/src/hooks/usePageTitle.ts",
        "frontend/shared/src/hooks/useNotify.ts",
        "frontend/shared/src/hooks/useAutoRefresh.ts",
        "frontend/shared/src/design-system/**/*.ts",
        "frontend/shared/src/stores/auth.ts",
      ],
      exclude: [
        "**/*.test.{ts,tsx}",
        "**/*.spec.{ts,tsx}",
        "**/index.ts",
        "**/*.d.ts",
        "**/test/**",
      ],
      thresholds: {
        statements: 85,
        branches: 75,
        functions: 85,
        lines: 85,
      },
    },
  },
});
