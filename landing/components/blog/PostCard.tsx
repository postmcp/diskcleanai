import Image from "next/image";
import Link from "next/link";
import { ArrowUpRight } from "lucide-react";
import { formatDate, type Post } from "@/lib/blog";

export function PostCard({ post, featured = false }: { post: Post; featured?: boolean }) {
  return (
    <article className="group relative flex h-full flex-col overflow-hidden rounded-3xl border border-white/70 bg-white/65 backdrop-blur-md transition-[border-color,box-shadow,transform] duration-200 hover:-translate-y-0.5 hover:border-ink/15 hover:shadow-[0_16px_40px_-24px_rgba(0,0,0,0.25)]">
      <div className={`relative overflow-hidden border-b border-line bg-surface ${featured ? "aspect-[16/9]" : "aspect-[16/10]"}`}>
        <Image
          src={post.image}
          alt={post.imageAlt}
          fill
          sizes={featured ? "(min-width: 1024px) 720px, 100vw" : "(min-width: 1024px) 360px, (min-width: 640px) 50vw, 100vw"}
          quality={90}
          className="object-cover object-top"
        />
      </div>
      <div className="flex flex-1 flex-col p-6">
        <p className="flex flex-wrap items-center gap-x-2 gap-y-1 text-[13px] text-muted">
          <time dateTime={post.date}>{formatDate(post.date)}</time>
          <span aria-hidden="true">·</span>
          <span>{post.readingMinutes} min read</span>
        </p>
        <h2 className={`mt-3 text-balance font-bold leading-snug tracking-[-0.02em] text-ink ${featured ? "text-2xl sm:text-3xl" : "text-lg"}`}>
          <Link href={`/blog/${post.slug}`} className="after:absolute after:inset-0">
            {post.title}
          </Link>
        </h2>
        <p className="mt-3 text-pretty text-[15px] leading-relaxed text-body">{post.description}</p>
        <div className="mt-5 flex flex-1 items-end justify-between gap-4">
          <ul className="flex flex-wrap gap-1.5">
            {post.tags.map((tag) => (
              <li key={tag} className="rounded-full bg-surface px-2.5 py-1 text-xs font-medium text-body">
                {tag}
              </li>
            ))}
          </ul>
          <ArrowUpRight size={18} className="shrink-0 text-muted transition-colors group-hover:text-ink" aria-hidden="true" />
        </div>
      </div>
    </article>
  );
}
