const { getDefaultConfig } = require("expo/metro-config");
const path = require("path");

const projectRoot = __dirname;
const monorepoRoot = path.resolve(projectRoot, "..");

const config = getDefaultConfig(projectRoot);

config.projectRoot = projectRoot;

// Watch shared for hot-reload
config.watchFolders = [path.resolve(monorepoRoot, "shared")];

// Resolve node_modules from both mobile/ and the monorepo root (for hoisted deps)
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, "node_modules"),
  path.resolve(monorepoRoot, "node_modules"),
];

// Map @cinezoo/shared to the shared source directory
config.resolver.extraNodeModules = {
  "@cinezoo/shared": path.resolve(monorepoRoot, "shared/src"),
};

// Prevent Metro from crawling into other workspaces
config.resolver.blockList = [
  new RegExp(path.resolve(monorepoRoot, "frontend").replace(/[/\\]/g, "[/\\\\]") + ".*"),
  new RegExp(path.resolve(monorepoRoot, "backend").replace(/[/\\]/g, "[/\\\\]") + ".*"),
];

// Rewrite bundle requests: Metro's server root is the monorepo root (due to
// watchFolders/nodeModulesPaths), so /index.bundle resolves from there.
// Rewrite to /mobile/index.bundle so Metro finds mobile/index.ts.
config.server = {
  ...config.server,
  rewriteRequestUrl(url) {
    // /index.bundle?... → /mobile/index.bundle?...
    if (url.startsWith("/index.bundle")) {
      return url.replace("/index.bundle", "/mobile/index.bundle");
    }
    return url;
  },
};

module.exports = config;
