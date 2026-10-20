import { defineConfig } from 'astro/config';
const site = process.env.SITE_URL ?? (process.env.VERCEL_PROJECT_PRODUCTION_URL ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}` : undefined);
export default defineConfig({output:'static',trailingSlash:'always',site});
