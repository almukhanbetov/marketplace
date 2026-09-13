/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Standalone output produces a self-contained server bundle (server.js +
  // only the node_modules actually traced as used) under .next/standalone,
  // which is what the production Docker image copies into its runtime stage.
  output: "standalone",
};

export default nextConfig;
