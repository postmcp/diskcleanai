import { ogCard, ogContentType, ogSize } from "@/lib/og";
import { site } from "@/lib/site";

export const alt = `${site.name} — ${site.tagline}`;
export const size = ogSize;
export const contentType = ogContentType;

export default function Image() {
  return ogCard({
    title: site.tagline,
    subtitle: "Visualize every file, uncover hidden clutter, and safely reclaim space with AI.",
  });
}
