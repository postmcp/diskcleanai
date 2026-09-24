import type { MetadataRoute } from "next";
import { posts, postUrl } from "@/lib/blog";
import { site } from "@/lib/site";

export default function sitemap(): MetadataRoute.Sitemap {
  const newestPost = posts.map((p) => p.updated ?? p.date).sort().at(-1) ?? "2026-09-01";
  return [
    { url: site.url, lastModified: new Date(newestPost), changeFrequency: "weekly", priority: 1 },
    { url: `${site.url}/blog`, lastModified: new Date(newestPost), changeFrequency: "weekly", priority: 0.8 },
    { url: `${site.url}/tools`, lastModified: new Date("2026-09-21"), changeFrequency: "monthly", priority: 0.6 },
    ...posts.map((post) => ({
      url: postUrl(post),
      lastModified: new Date(post.updated ?? post.date),
      changeFrequency: "monthly" as const,
      priority: 0.7,
      images: [`${site.url}${post.image}`],
    })),
    { url: `${site.url}/privacy`, lastModified: new Date("2026-09-24"), changeFrequency: "yearly", priority: 0.3 },
    { url: `${site.url}/terms`, lastModified: new Date("2026-09-24"), changeFrequency: "yearly", priority: 0.3 },
  ];
}
