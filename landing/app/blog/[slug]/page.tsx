import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { Footer } from "@/components/Footer";
import { JsonLd } from "@/components/JsonLd";
import { Nav } from "@/components/Nav";
import { AppCTA } from "@/components/blog/AppCTA";
import { PostCard } from "@/components/blog/PostCard";
import { Container } from "@/components/ui";
import { formatDate, getPost, postUrl, posts, relatedPosts } from "@/lib/blog";
import { rssAlternate, site } from "@/lib/site";

type Props = { params: Promise<{ slug: string }> };

export const dynamicParams = false;

export function generateStaticParams() {
  return posts.map(({ slug }) => ({ slug }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const post = getPost((await params).slug);
  if (!post) return {};
  return {
    title: post.title,
    description: post.description,
    keywords: post.tags,
    alternates: { canonical: `/blog/${post.slug}`, types: rssAlternate },
    openGraph: {
      type: "article",
      title: post.title,
      description: post.description,
      url: `/blog/${post.slug}`,
      publishedTime: `${post.date}T00:00:00Z`,
      modifiedTime: `${post.updated ?? post.date}T00:00:00Z`,
      authors: [site.name],
      tags: post.tags,
    },
    twitter: { card: "summary_large_image", title: post.title, description: post.description },
  };
}

export default async function PostPage({ params }: Props) {
  const { slug } = await params;
  const post = getPost(slug);
  if (!post) notFound();
  const { default: Body } = await import(`@/content/blog/${slug}.mdx`);
  const related = relatedPosts(post);

  return (
    <>
      <Nav />
      <main className="flex-1 pb-24 pt-12 sm:pt-16">
        <Container>
          <article className="mx-auto max-w-3xl">
            <Link
              href="/blog"
              className="inline-flex items-center gap-1.5 text-sm font-medium text-body transition-colors hover:text-ink"
            >
              <ArrowLeft size={15} aria-hidden="true" />
              All guides
            </Link>

            <header className="mt-6">
              <p className="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-muted">
                <time dateTime={post.date}>{formatDate(post.date)}</time>
                {post.updated ? (
                  <>
                    <span aria-hidden="true">·</span>
                    <span>Updated {formatDate(post.updated)}</span>
                  </>
                ) : null}
                <span aria-hidden="true">·</span>
                <span>{post.readingMinutes} min read</span>
              </p>
              <h1 className="mt-4 text-balance text-[34px] font-bold leading-[1.08] tracking-[-0.035em] text-ink sm:text-5xl">
                {post.title}
              </h1>
              <p className="mt-5 text-pretty text-lg leading-relaxed text-body sm:text-xl">{post.description}</p>
              <ul className="mt-5 flex flex-wrap gap-1.5">
                {post.tags.map((tag) => (
                  <li key={tag} className="rounded-full bg-surface px-2.5 py-1 text-xs font-medium text-body">
                    {tag}
                  </li>
                ))}
              </ul>
            </header>

            <figure className="mt-9 overflow-hidden rounded-3xl border border-line bg-surface shadow-[0_30px_60px_-40px_rgba(11,11,15,0.45)]">
              <Image
                src={post.image}
                alt={post.imageAlt}
                width={1600}
                height={1000}
                priority
                quality={90}
                sizes="(min-width: 768px) 768px, 100vw"
                className="h-auto w-full"
              />
            </figure>

            <div className="prose-root">
              <Body />
            </div>

            <AppCTA />
          </article>

          {related.length ? (
            <section className="mx-auto mt-20 max-w-6xl" aria-labelledby="related">
              <h2 id="related" className="text-2xl font-bold tracking-[-0.02em] text-ink">
                Keep reading
              </h2>
              <div className="mt-6 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                {related.map((p) => (
                  <PostCard key={p.slug} post={p} />
                ))}
              </div>
            </section>
          ) : null}
        </Container>
      </main>
      <Footer />
      <JsonLd
        data={{
          "@context": "https://schema.org",
          "@graph": [
            {
              "@type": "BlogPosting",
              "@id": `${postUrl(post)}#article`,
              headline: post.title,
              description: post.description,
              image: [`${postUrl(post)}/opengraph-image`, `${site.url}${post.image}`],
              datePublished: `${post.date}T00:00:00Z`,
              dateModified: `${post.updated ?? post.date}T00:00:00Z`,
              keywords: post.tags.join(", "),
              wordCount: post.readingMinutes * 200,
              inLanguage: "en",
              isAccessibleForFree: true,
              mainEntityOfPage: postUrl(post),
              author: { "@type": "Organization", name: site.name, url: site.url },
              publisher: {
                "@type": "Organization",
                name: site.legalName,
                url: site.url,
                logo: { "@type": "ImageObject", url: `${site.url}/images/mascot.png`, width: 640, height: 640 },
              },
            },
            {
              "@type": "BreadcrumbList",
              itemListElement: [
                { "@type": "ListItem", position: 1, name: "Home", item: site.url },
                { "@type": "ListItem", position: 2, name: "Blog", item: `${site.url}/blog` },
                { "@type": "ListItem", position: 3, name: post.title, item: postUrl(post) },
              ],
            },
          ],
        }}
      />
    </>
  );
}
