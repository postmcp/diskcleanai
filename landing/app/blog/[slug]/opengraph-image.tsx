import { ogCard, ogContentType, ogSize } from "@/lib/og";
import { getPost, posts } from "@/lib/blog";

export const size = ogSize;
export const contentType = ogContentType;

export function generateStaticParams() {
  return posts.map(({ slug }) => ({ slug }));
}

export default async function Image({ params }: { params: Promise<{ slug: string }> }) {
  const post = getPost((await params).slug);
  return ogCard({
    title: post?.title ?? "Mac storage guides",
    subtitle: post?.description,
    kicker: post ? `Guide · ${post.readingMinutes} min read` : "Blog",
  });
}
