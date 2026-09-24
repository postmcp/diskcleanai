import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { sortedPosts } from "@/lib/blog";
import { PostCard } from "./blog/PostCard";
import { Container, SectionHeading } from "./ui";

/** Three newest guides on the homepage — internal links the crawler (and readers) can follow. */
export function LatestPosts() {
  return (
    <section id="guides" className="scroll-mt-20 py-24 sm:py-32">
      <Container>
        <SectionHeading
          eyebrow="Guides"
          title="Know your Mac before you clean it."
          lead="Tested, step-by-step guides to the storage problems people search for most — with the manual method and the one-scan shortcut."
        />
        <div className="mt-14 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {sortedPosts.slice(0, 3).map((post) => (
            <PostCard key={post.slug} post={post} />
          ))}
        </div>
        <p className="mt-10 text-center">
          <Link href="/blog" className="inline-flex items-center gap-2 text-[15px] font-medium text-ink transition-colors hover:text-brand">
            All guides
            <ArrowRight size={16} aria-hidden="true" />
          </Link>
        </p>
      </Container>
    </section>
  );
}
