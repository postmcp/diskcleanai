import { ogCard, ogContentType, ogSize } from "@/lib/og";
import { posts } from "@/lib/blog";

export const alt = "Disk Clean AI blog — Mac storage guides";
export const size = ogSize;
export const contentType = ogContentType;

export default function Image() {
  return ogCard({
    title: "Guides to a lighter Mac.",
    subtitle: `${posts.length} practical guides: System Data, large files, duplicates, caches, app leftovers and developer clutter.`,
    kicker: "Blog",
  });
}
