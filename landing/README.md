# Disk Clean AI — landing page

Website for Disk Clean AI, a free, open-source Mac storage cleaner that visualizes your
disk and uses AI (via your own OpenRouter key) to suggest what's safe to remove. Includes
the open-source section, the blog and the privacy/terms pages.

Built with Next.js 16 (App Router), Tailwind CSS 4, MDX and `lucide-react`.
The mascot logo, page backdrop, sunburst chart and feature icons were generated
with [Image MCP Server](https://imagemcpserver.com). Logos in `public/logos/`
are copied from the sibling product repos.

## Run it

```bash
npm install
npm run dev
```

Open http://localhost:3000. The download button downloads `DiskCleanAI.zip` straight from the
newest GitHub release (`downloadUrl` in `lib/site.ts`), so the site needs no backend.

## Before shipping

Production builds (`NODE_ENV=production`) default to `https://diskcleanai.com`; set
`NEXT_PUBLIC_SITE_URL` only to override it (see `.env.example`). `site.url` feeds canonical URLs, Open
Graph tags, the sitemap, RSS and `llms.txt`, so it must be the real domain.

## Blog

Posts live in two places:

- `lib/blog.ts` — the registry: slug, title, description, date, tags, cover image.
  It drives the index page, homepage "Guides" section, footer links, sitemap,
  RSS feed, `llms.txt` and the generated Open Graph cards.
- `content/blog/<slug>.mdx` — the body. GitHub-flavoured markdown plus a
  `<Callout type="tip|note|warning">` component. Headings get ids automatically.

To add a post: append an entry to `posts` and create the matching `.mdx`. Element
styling for the article lives in `mdx-components.tsx`.

## SEO surface

| Route | Source |
| --- | --- |
| `/robots.txt`, `/sitemap.xml`, `/manifest.webmanifest` | `app/robots.ts`, `app/sitemap.ts`, `app/manifest.ts` |
| `/llms.txt` | `app/llms.txt/route.ts` (plain-text site map for AI crawlers) |
| `/blog/feed.xml` | `app/blog/feed.xml/route.ts` (RSS 2.0) |
| `/opengraph-image`, `/blog/opengraph-image`, `/blog/<slug>/opengraph-image` | `lib/og.tsx` via `ImageResponse` |
| Favicons | `app/favicon.ico`, `app/icon.png`, `app/apple-icon.png`; manifest icons in `public/icons/` |
| Structured data | `components/JsonLd.tsx` — Organization, WebSite, SoftwareApplication (+ offers) and FAQPage on `/`; Blog on `/blog`; BlogPosting + BreadcrumbList on posts |

`/thanks` is `noindex`; `/api/` is disallowed in robots.

## Structure

```
app/                 layout, pages, metadata routes, global styles (design tokens live in globals.css)
app/blog             index, [slug] post page, OG images, RSS
components/          one file per section, plus ui.tsx for shared primitives
components/blog      PostCard, AppCTA (the closing "try the app" card)
content/blog         the MDX post bodies
lib/site.ts          site config, nav links, plans, product list
lib/blog.ts          blog registry
lib/og.tsx           shared Open Graph card renderer
mdx-components.tsx   element styling + Callout for MDX
public/images        generated art: mascot.png (logo), backdrop.jpg, sunburst.png, feature icons
public/screenshots   app screenshots (also used as blog covers)
public/logos         real logos of the four sibling products
public/icons         manifest icons and the small mascot used on OG cards
```
