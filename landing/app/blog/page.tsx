import type { Metadata } from "next";
import { Footer } from "@/components/Footer";
import { JsonLd } from "@/components/JsonLd";
import { Nav } from "@/components/Nav";
import { PostCard } from "@/components/blog/PostCard";
import { Container, Eyebrow } from "@/components/ui";
import { postUrl, sortedPosts } from "@/lib/blog";
import { rssAlternate, site } from "@/lib/site";

const title = "Mac storage guides";
const description =
  "Practical, tested guides to freeing up space on a Mac: System Data, large files, duplicates, caches, leftover app files and developer clutter.";

export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: "/blog", types: rssAlternate },
  openGraph: { title: `${title} · ${site.name}`, description, url: "/blog", type: "website" },
};

export default function BlogIndex() {
  const [latest, ...rest] = sortedPosts;
  return (
    <>
      <Nav />
      <main className="flex-1 pb-24 pt-16 sm:pt-24">
        <Container>
          <div className="max-w-2xl">
            <Eyebrow>Blog</Eyebrow>
            <h1 className="text-balance text-4xl font-bold leading-[1.05] tracking-[-0.035em] text-ink sm:text-5xl">
              Guides to a lighter Mac.
            </h1>
            <p className="mt-5 text-pretty text-lg leading-relaxed text-body">{description}</p>
          </div>

          <div className="mt-12">
            <PostCard post={latest} featured />
          </div>
          <div className="mt-6 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {rest.map((post) => (
              <PostCard key={post.slug} post={post} />
            ))}
          </div>
        </Container>
      </main>
      <Footer />
      <JsonLd
        data={{
          "@context": "https://schema.org",
          "@type": "Blog",
          name: `${site.name} Blog`,
          url: `${site.url}/blog`,
          description,
          publisher: { "@type": "Organization", name: site.legalName, url: site.url },
          blogPost: sortedPosts.map((p) => ({
            "@type": "BlogPosting",
            headline: p.title,
            url: postUrl(p),
            datePublished: p.date,
            dateModified: p.updated ?? p.date,
          })),
        }}
      />
    </>
  );
}
