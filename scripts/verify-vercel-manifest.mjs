#!/usr/bin/env node
/**
 * Fails if the monorepo root is missing a direct `next` dependency.
 * Vercel reads the Root Directory's package.json for Next version detection;
 * workspace-only roots without `next` here cause "No Next.js version detected".
 */
import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

function readPkg(dir) {
  const path = join(dir, "package.json");
  if (!existsSync(path)) return null;
  return JSON.parse(readFileSync(path, "utf8"));
}

const rootPkg = readPkg(root);
if (!rootPkg) {
  console.error("verify-vercel-manifest: missing package.json at repo root");
  process.exit(1);
}

const hasNext =
  (rootPkg.dependencies && rootPkg.dependencies.next) ||
  (rootPkg.devDependencies && rootPkg.devDependencies.next);

if (!hasNext) {
  console.error(
    "verify-vercel-manifest: root package.json must list \"next\" in dependencies or devDependencies (Vercel Next version detection)."
  );
  process.exit(1);
}

const appPkg = readPkg(join(root, "Tenthproject"));
if (appPkg) {
  const appHas =
    (appPkg.dependencies && appPkg.dependencies.next) ||
    (appPkg.devDependencies && appPkg.devDependencies.next);
  if (!appHas) {
    console.error('verify-vercel-manifest: Tenthproject/package.json must list "next".');
    process.exit(1);
  }
}

console.log("verify-vercel-manifest: ok (next declared at root and Tenthproject)");
