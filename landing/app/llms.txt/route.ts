import { formatDate, postUrl, sortedPosts } from "@/lib/blog";
import { downloadUrl, repo, site } from "@/lib/site";
import { tools } from "@/lib/tools";

// Static: the file only depends on the blog registry, so it's generated at build time.
export const dynamic = "force-static";

/** llms.txt (https://llmstxt.org): a plain-text map of the site for AI assistants and crawlers. */
export function GET() {
  const body = `# ${site.name}

> ${site.description}

${site.name} is a macOS app (${site.minMacOS}, Apple silicon and Intel) that scans a Mac's disk, draws it as sunburst, treemap, bubble, mind-map, icicle and age-map views, groups safe-to-remove clutter into "Quick Wins" (Downloads, caches and logs, Trash, large media, Xcode DerivedData, iOS simulators, node_modules, build folders), finds large files, exact duplicates (SHA-256), similar photos (perceptual hash), and unused apps with their leftover support files. An optional AI Advisor sends scan metadata only (paths, sizes, dates, types — never file contents) to a model through the user's own OpenRouter key and explains what each item is. Nothing is deleted without the user's approval; approved items go to the Trash.

License: free and open source under the ${site.license} license — no trial, subscription, account or license key. Source code: ${repo.url}

## Pages

- [Home](${site.url}): features, how it works, open source, FAQ
- [Download for Mac](${downloadUrl}): always the newest GitHub release
- [Source code](${repo.url}): the SwiftUI app and this website
- [Issues](${repo.issues}): bug reports and feature requests
- [Blog](${site.url}/blog): practical Mac storage guides
- [Other tools](${site.url}/tools): every product from the same team
- [Privacy policy](${site.url}/privacy)
- [Terms](${site.url}/terms)
- Support: ${site.supportEmail}

## Blog posts

${sortedPosts.map((p) => `- [${p.title}](${postUrl(p)}): ${p.description} (${formatDate(p.date)})`).join("\n")}

## Related tools by the same team

${tools.filter((t) => !t.current).map((t) => `- [${t.name}](${t.url}): ${t.tagline}`).join("\n")}
`;
  return new Response(body, { headers: { "Content-Type": "text/plain; charset=utf-8" } });
}
