const production = process.env.NODE_ENV === "production";

export const site = {
  name: "Disk Clean AI",
  legalName: "Redesignr AI",
  tagline: "See what's filling up your Mac.",
  description:
    "Free, open-source Mac storage cleaner. Visualize every file, uncover hidden clutter, and safely reclaim space with AI — using your own OpenRouter key.",
  /** Production builds default to the live domains even without env vars; dev stays on localhost. */
  url: (process.env.NEXT_PUBLIC_SITE_URL ?? (production ? "https://diskcleanai.com" : "http://localhost:3000")).replace(/\/$/, ""),
  supportEmail: "hello@diskcleanai.com",
  minMacOS: "macOS 14+",
  license: "MIT",
};

/** The public source repository. No trailing slash. */
export const repo = {
  url: "https://github.com/postmcp/diskcleanai",
  slug: "postmcp/diskcleanai",
  releases: "https://github.com/postmcp/diskcleanai/releases",
  issues: "https://github.com/postmcp/diskcleanai/issues",
  newIssue: "https://github.com/postmcp/diskcleanai/issues/new",
  pulls: "https://github.com/postmcp/diskcleanai/pulls",
  license: "https://github.com/postmcp/diskcleanai/blob/main/LICENSE",
  contributing: "https://github.com/postmcp/diskcleanai/blob/main/CONTRIBUTING.md",
  clone: "https://github.com/postmcp/diskcleanai.git",
};

/** `alternates.types` entry for the RSS feed; pages that set their own `alternates` must include it. */
export const rssAlternate = { "application/rss+xml": "/blog/feed.xml" } as const;

/** The zip attached to every GitHub release under this exact name (macApp/scripts/build-release.sh). */
export const releaseAsset = "DiskCleanAI.zip";

/** Direct download: GitHub always serves this file from the newest published release. */
export const downloadUrl = `${repo.releases}/latest/download/${releaseAsset}`;

/** Absolute paths so the links also work from /blog and other pages. */
export const navLinks = [
  { label: "Features", href: "/#features" },
  { label: "How it works", href: "/#how-it-works" },
  { label: "Open source", href: "/#open-source" },
  { label: "Blog", href: "/blog" },
  { label: "Other tools", href: "/tools" },
];

/** The other tools built by the same team, shown just above the footer. */
export const products = [
  {
    name: "Redesignr",
    url: "https://redesignr.ai",
    tagline: "AI website redesign made simple",
    description:
      "Paste any URL and get a modern, production-ready rebuild — 10,000+ sections and 1,600+ themes to start from.",
    logo: "/logos/redesignr.png",
    logoBg: "#f6efe4",
  },
  {
    name: "CustomerBot",
    url: "https://customerbot.co",
    tagline: "AI support trained on your own site",
    description:
      "Learns from your website, PDFs and docs. Deploys with one line of code and answers in 95+ languages.",
    logo: "/logos/customerbot.png",
    logoBg: "#000000",
  },
  {
    name: "PostMCP AI",
    url: "https://postmcpai.com",
    tagline: "Schedule and auto-post across 7 networks",
    description:
      "Draft, schedule and publish to LinkedIn, X, Instagram, Threads, Bluesky and more — from one dashboard or straight from Claude via MCP.",
    logo: "/logos/postmcp.png",
    logoBg: "#3b5bdb",
  },
  {
    name: "Image MCP Server",
    url: "https://imagemcpserver.com",
    tagline: "Generate website images in your editor",
    description:
      "Eight image tools — generate, edit, upscale, remove backgrounds, SVG — for AI agents behind one API key. Every illustration on this page was made with it.",
    logo: "/logos/imagemcp.png",
    logoBg: "#f9c623",
  },
];
