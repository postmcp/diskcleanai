/**
 * Every product built by the team behind Disk Clean AI (Redesignr AI), as listed on
 * saasworldmap.com/founders/shiva. Shown on /tools. `products` in site.ts is the
 * shorter, hand-picked set for the home page and footer — keep both in sync when a
 * product launches or is retired.
 */

export const toolCategories = ["All", "SaaS", "Mac app", "Mobile app", "MCP server"] as const;
export type ToolCategory = (typeof toolCategories)[number];

export type Tool = {
  name: string;
  url: string;
  category: Exclude<ToolCategory, "All">;
  logo: string;
  /** Background behind transparent logos. */
  logoBg?: string;
  tagline: string;
  description: string;
  useCases: string[];
  /** True for the product this site belongs to. */
  current?: boolean;
};

export const tools: Tool[] = [
  {
    name: "Redesignr",
    url: "https://redesignr.ai",
    category: "SaaS",
    logo: "/logos/redesignr.png",
    logoBg: "#f6efe4",
    tagline: "AI website redesign made simple",
    description:
      "Paste any URL and get a modern, production-ready rebuild — 10,000+ sections and 1,600+ themes to start from.",
    useCases: [
      "Rebuild an outdated marketing site in an afternoon",
      "Generate landing pages for a new product or campaign",
      "Export clean HTML, React or Next.js you can ship",
    ],
  },
  {
    name: "PostMCP AI",
    url: "https://postmcpai.com",
    category: "SaaS",
    logo: "/logos/postmcp.png",
    logoBg: "#3b5bdb",
    tagline: "Social media on autopilot",
    description:
      "Publish, schedule and automate posts across every social network from one dashboard — or straight from your AI agent via MCP.",
    useCases: [
      "Schedule a week of posts across X, LinkedIn and Instagram in one go",
      "Let Claude, ChatGPT or Cursor post for you through one unified API",
      "Announce a launch to every network at once",
    ],
  },
  {
    name: "CustomerBot",
    url: "https://customerbot.co",
    category: "SaaS",
    logo: "/logos/customerbot.png",
    logoBg: "#000000",
    tagline: "A support chatbot trained on your site",
    description:
      "Point it at your website, PDFs and docs and it answers customer questions 24/7. Review every chat, fix wrong answers and hand off to your team.",
    useCases: [
      "Add live support chat to a site without hiring a support team",
      "Deflect repetitive pre-sales and FAQ questions",
      "Monitor and correct answers from the web or the mobile app",
    ],
  },
  {
    name: "SaaS World Map",
    url: "https://www.saasworldmap.com",
    category: "SaaS",
    logo: "/logos/saasworldmap.png",
    tagline: "A 3D map of SaaS products and founders",
    description:
      "List your product on an interactive globe for free, get discovered by country, and browse what other founders are building.",
    useCases: [
      "Get a free, verified listing and backlink for your product",
      "Rank #1 in your country for extra visibility",
      "Discover startups and founders around the world",
    ],
  },
  {
    name: "Image MCP Server",
    url: "https://imagemcpserver.com",
    category: "MCP server",
    logo: "/logos/imagemcp.png",
    logoBg: "#f9c623",
    tagline: "Give your coding agent a visual layer",
    description:
      "Your agent writes the markup but leaves grey boxes. This MCP server generates the hero shots, product cutouts and OG cards from inside your editor.",
    useCases: [
      "Generate hero images and OG cards while vibe-coding a site",
      "Remove backgrounds, upscale and convert images from Claude or Cursor",
      "Create transparent product cutouts and icons on demand",
    ],
  },
  {
    name: "Character Animation AI",
    url: "https://www.characteranimationai.com",
    category: "SaaS",
    logo: "/logos/characteranimationai.png",
    tagline: "One character. Every kind of story.",
    description:
      "Create a character from a prompt or your own image, then give it new motions, moods and moments for videos, ads and social content.",
    useCases: [
      "Build a consistent brand mascot and animate it",
      "Turn a still illustration into short animated clips",
      "Produce character-led explainer and social videos",
    ],
  },
  {
    name: "App Mockup Generator AI",
    url: "https://www.appmockupgeneratorai.com",
    category: "SaaS",
    logo: "/logos/appmockupgeneratorai.png",
    tagline: "Raw screens → App Store creatives",
    description:
      "Upload your app screenshots and get polished, on-brand App Store and Play Store screenshots in seconds — no designer, no design tools.",
    useCases: [
      "Ship App Store screenshots for a new release",
      "Localise store creatives for multiple markets",
      "Make device mockups for your landing page",
    ],
  },
  {
    name: "Audio Maker AI",
    url: "https://audiomakerai.com",
    category: "SaaS",
    logo: "/logos/audiomakerai.png",
    tagline: "Turn words into sound",
    description:
      "Describe a track and hear it in about a minute, or paste your lyrics and pick the voice that sings them. Music, voices, sound effects and ambience in one studio.",
    useCases: [
      "Generate background music for videos and reels",
      "Voice-over a demo or tutorial with an AI voice",
      "Create jingles, sound effects and ambient loops",
    ],
  },
  {
    name: "Design Maker AI",
    url: "https://www.designmakerai.co",
    category: "SaaS",
    logo: "/logos/designmakerai.png",
    tagline: "Describe it once. Get a design that ships.",
    description:
      "Turns a sentence or rough sketch into landing pages, social posts, infographics and marketing assets. Refine by chat, export in seconds.",
    useCases: [
      "Create social post graphics that match your brand",
      "Mock up ad creatives and banners quickly",
      "Draft marketing assets for a launch",
    ],
  },
  {
    name: "SVG Maker AI",
    url: "https://www.svgmakerai.com",
    category: "SaaS",
    logo: "/logos/svgmakerai.png",
    tagline: "Prompt in. Path data out.",
    description:
      "Describe a graphic or drop in an image and get real vector geometry back — named layers, editable bezier handles and markup small enough to read in a diff.",
    useCases: [
      "Generate icons and logos as clean, editable SVG",
      "Convert a raster image into vector paths",
      "Produce lightweight illustrations for your site",
    ],
  },
  {
    name: "GPS for Family",
    url: "https://www.gpsforfamily.com",
    category: "Mobile app",
    logo: "/logos/gpsforfamily.svg",
    tagline: "Stay connected to the people you love",
    description:
      "Real-time family location sharing with places, alerts and check-ins — because the people you love live different lives in different places.",
    useCases: [
      "Know when the kids arrive at school or home",
      "Share your live location with family on a trip",
      "Get alerts when someone leaves or reaches a place",
    ],
  },
  {
    name: "Toonly AI",
    url: "https://www.toonlyai.com",
    category: "SaaS",
    logo: "/logos/toonlyai.png",
    tagline: "Turn your photo into anything",
    description:
      "Upload one photo of yourself, tap the look you want, and get a brand-new picture back in about 30 seconds. No editing skills needed.",
    useCases: [
      "Make a cartoon or anime avatar for your profiles",
      "Try dozens of art styles on a single selfie",
      "Create fun, shareable portraits for social media",
    ],
  },
  {
    name: "Calculator Locker",
    url: "https://calculatorlockerapp.com",
    category: "Mobile app",
    logo: "/logos/calculatorlocker.png",
    tagline: "It's a calculator. Until you press =",
    description:
      "Hides your photos, files, notes and a private browser behind a fully working calculator. Type your code, press equals, and it opens.",
    useCases: [
      "Keep private photos and documents out of sight",
      "Store notes and files behind a disguised app",
      "Browse privately from a hidden built-in browser",
    ],
  },
  {
    name: "Infographic Generator AI",
    url: "https://infographicgeneratorai.com",
    category: "SaaS",
    logo: "/logos/infographicgeneratorai.png",
    tagline: "Turn content into infographics",
    description:
      "Give it a topic, text or data and get stunning infographic slides in seconds — perfect for Instagram carousels, presentations and blogs.",
    useCases: [
      "Turn a blog post into an Instagram carousel",
      "Visualise stats and data for a presentation",
      "Create shareable explainer graphics for LinkedIn",
    ],
  },
  {
    name: "Disk Clean AI",
    url: "https://diskcleanai.com",
    category: "Mac app",
    logo: "/images/mascot.png",
    current: true,
    tagline: "See what's filling up your Mac",
    description:
      "Free and open source. Visualise every file, uncover hidden clutter and safely reclaim space on your Mac with AI — using your own OpenRouter key.",
    useCases: [
      "Find the large files and caches eating your disk",
      "Clean up safely before a macOS update",
      "Spot duplicate downloads and forgotten installers",
    ],
  },
];
