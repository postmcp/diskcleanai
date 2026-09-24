import { site } from "./site";

/**
 * The blog registry. Each entry has a matching `content/blog/<slug>.mdx`; this file is
 * the single source of truth for the index page, sitemap, RSS, llms.txt and OG images,
 * so adding a post means adding it here and writing the MDX.
 */
export type Post = {
  slug: string;
  title: string;
  /** Short label for the footer and other tight spots. */
  shortTitle?: string;
  /** Meta description, 140–160 characters. */
  description: string;
  /** ISO date (YYYY-MM-DD). */
  date: string;
  updated?: string;
  readingMinutes: number;
  tags: string[];
  /** Cover image under /public, shown on the index card and post header. */
  image: string;
  imageAlt: string;
};

export const posts: Post[] = [
  {
    slug: "not-enough-space-to-update-mac",
    shortTitle: "Not enough space to update",
    title: "Not Enough Space to Update Your Mac? How to Clear Room for macOS 27 Golden Gate",
    description:
      "How much free space a macOS update really needs, why the installer ignores 'purgeable' space, and a 20-minute sequence that clears 50 GB or more so the update goes through.",
    date: "2026-09-19",
    readingMinutes: 11,
    tags: ["macOS", "Updates", "How-to"],
    image: "/screenshots/quick-wins.webp",
    imageAlt: "Disk Clean AI's Quick Wins view listing safe, large cleanup targets on a Mac with their sizes.",
  },
  {
    slug: "delete-time-machine-local-snapshots-mac",
    shortTitle: "Delete Time Machine snapshots",
    title: "How to Delete Time Machine Local Snapshots on Mac (and Get Your Space Back)",
    description:
      "Time Machine local snapshots quietly hold on to files you've deleted. Learn what they are, how to list and delete them with tmutil or Disk Utility, and which one to keep.",
    date: "2026-09-18",
    readingMinutes: 11,
    tags: ["Storage", "Time Machine", "How-to"],
    image: "/screenshots/explore-icicle.webp",
    imageAlt: "Icicle chart of a Mac's startup disk in Disk Clean AI, with hidden system and snapshot data shown as stacked layers.",
  },
  {
    slug: "mac-startup-disk-full-even-after-deleting-files",
    shortTitle: "Disk still full after deleting",
    title: "Mac Startup Disk Full Even After Deleting Files? Here's Why and How to Fix It",
    description:
      "Deleted files, emptied the Trash, disk still full? Six causes in order of likelihood — snapshots, hidden Trashes, open files, stale Storage figures — each with a check and a fix.",
    date: "2026-09-17",
    readingMinutes: 10,
    tags: ["Storage", "Troubleshooting", "How-to"],
    image: "/screenshots/scanning.webp",
    imageAlt: "Disk Clean AI scanning a Mac's startup disk and tallying files and folders by size.",
  },
  {
    slug: "delete-iphone-ipad-backups-on-mac",
    shortTitle: "Delete iPhone backups",
    title: "How to Delete iPhone and iPad Backups on Mac (Finder, Settings or Terminal)",
    description:
      "Old iOS backups often hold 50 to 150 GB. Here's where macOS stores them, three ways to delete them safely, which ones to keep, and how to move future backups to an external drive.",
    date: "2026-09-14",
    readingMinutes: 10,
    tags: ["How-to", "Backups", "Storage"],
    image: "/screenshots/explore-folders.webp",
    imageAlt: "Disk Clean AI's folder view showing the hidden Library folder with MobileSync backups ranked by size.",
  },
  {
    slug: "purgeable-space-on-mac",
    shortTitle: "Purgeable space explained",
    title: "Purgeable Space on Mac: What It Is, Why You Can't Delete It, and How to Get It Back",
    description:
      "Finder says 60 GB is purgeable but the installer says the disk is full. What purgeable space really contains, why the number is often wrong, and the steps that actually free it.",
    date: "2026-09-11",
    readingMinutes: 10,
    tags: ["Storage", "macOS"],
    image: "/screenshots/explore-list.webp",
    imageAlt: "Disk Clean AI's list view of a Mac's disk with used, free and reclaimable space broken out by folder.",
  },
  {
    slug: "mail-taking-up-space-on-mac",
    shortTitle: "Mail taking up space",
    title: "Mail Taking Up Space on Mac? How to Shrink Apple Mail's Storage",
    description:
      "Apple Mail downloads every message and attachment in every account and never removes them. Where the data lives, what's safe to delete, and the settings that stop it growing back.",
    date: "2026-09-08",
    readingMinutes: 10,
    tags: ["How-to", "Apps", "Storage"],
    image: "/screenshots/explore-agemap.webp",
    imageAlt: "Disk Clean AI's age map colouring a Mac's files by how long ago they were last used, with old mail data highlighted.",
  },
  {
    slug: "messages-taking-up-space-on-mac",
    shortTitle: "Messages taking up space",
    title: "Messages Taking Up Space on Mac? How to Clear iMessage Attachments Safely",
    description:
      "Messages stores every photo and video you've ever been sent at full size. Where it hides, the built-in tool for clearing it, and how to free the Mac without deleting from your iPhone.",
    date: "2026-09-06",
    readingMinutes: 9,
    tags: ["How-to", "Apps", "Storage"],
    image: "/screenshots/explore-bubbles.webp",
    imageAlt: "Bubble chart in Disk Clean AI where each circle is a folder sized by its contents, with a large Messages attachments bubble.",
  },
  {
    slug: "mac-photos-library-too-big",
    shortTitle: "Photos library too big",
    title: "Mac Photos Library Too Big? How to Shrink It or Move It to an External Drive",
    description:
      "Why a Photos library is bigger than the photos in it, safe ways to shrink it without losing a picture, and how to move it to an external SSD without breaking iCloud Photos.",
    date: "2026-09-03",
    readingMinutes: 11,
    tags: ["How-to", "Photos", "Storage"],
    image: "/screenshots/find-similar-photos.webp",
    imageAlt: "Disk Clean AI's similar photos finder grouping near-identical shots from a Mac's Photos library.",
  },
  {
    slug: "icloud-drive-taking-up-space-on-mac",
    shortTitle: "iCloud Drive taking up space",
    title: "Why iCloud Drive Takes Up Space on Your Mac (and How to Free It Without Deleting Anything)",
    description:
      "iCloud Drive keeps a full local copy of your files by default. How Optimise Mac Storage really works, how to evict folders instantly with Remove Download, and what to do about Desktop & Documents.",
    date: "2026-08-31",
    readingMinutes: 10,
    tags: ["iCloud", "Storage", "How-to"],
    image: "/screenshots/explore-mindmap.webp",
    imageAlt: "Mind map view in Disk Clean AI branching from a Mac's home folder into iCloud Drive and its largest subfolders.",
  },
  {
    slug: "how-much-storage-do-i-need-macbook",
    shortTitle: "How much storage do I need?",
    title: "How Much Storage Do You Need on a MacBook? 256 GB vs 512 GB vs 1 TB",
    description:
      "A practical way to pick MacBook storage: what macOS and Apple Intelligence take, real sizes for photo libraries, dev tools and games, and when iCloud or an external SSD lets you go smaller.",
    date: "2026-08-27",
    readingMinutes: 11,
    tags: ["Buying guide", "Storage"],
    image: "/screenshots/welcome.webp",
    imageAlt: "Disk Clean AI's welcome screen showing a Mac's total, used and free storage before a scan.",
  },
  {
    slug: "how-to-free-up-space-on-mac",
    shortTitle: "Free up space on Mac",
    title: "How to Free Up Space on Your Mac: The Complete Guide",
    description:
      "A step-by-step guide to freeing up space on a Mac: what's safe to delete, where the big files hide, built-in macOS tools, Terminal commands and how to avoid doing it again next month.",
    date: "2026-09-15",
    readingMinutes: 12,
    tags: ["Storage", "How-to"],
    image: "/screenshots/explore-topsizes.webp",
    imageAlt: "Disk Clean AI's Top Sizes view ranking the largest folders on a Mac with sizes and percentages.",
  },
  {
    slug: "what-is-system-data-on-mac",
    shortTitle: "What is System Data?",
    title: "What Is “System Data” on Mac and How to Reduce It",
    description:
      "System Data eating 50, 100 or 200 GB? Here's what macOS actually counts in that category, why it grows, and the safe ways to shrink it — Time Machine snapshots, caches, logs and more.",
    date: "2026-09-12",
    readingMinutes: 10,
    tags: ["Storage", "macOS"],
    image: "/screenshots/explore-sunburst.webp",
    imageAlt: "Sunburst chart of a Mac's disk, with the Library folder and its caches taking up a large ring segment.",
  },
  {
    slug: "find-large-files-on-mac",
    shortTitle: "Find large files",
    title: "How to Find Large Files on Mac (Finder, Terminal and Visual Tools)",
    description:
      "Four reliable ways to find the biggest files on your Mac — Finder search, the Storage settings, Terminal commands like du and find, and visual disk maps — plus what's safe to delete.",
    date: "2026-09-09",
    readingMinutes: 9,
    tags: ["How-to", "Large files"],
    image: "/screenshots/find-large-files.webp",
    imageAlt: "Disk Clean AI's Find Large Files tool listing the biggest files on a Mac, sorted by size.",
  },
  {
    slug: "find-and-delete-duplicate-files-on-mac",
    shortTitle: "Find duplicate files",
    title: "How to Find and Delete Duplicate Files and Photos on Mac",
    description:
      "Duplicates quietly eat gigabytes. Learn how macOS Photos finds duplicate pictures, how to catch duplicate files with Smart Folders or fdupes, and how to remove them without losing an original.",
    date: "2026-09-05",
    readingMinutes: 9,
    tags: ["How-to", "Duplicates"],
    image: "/screenshots/find-duplicates.webp",
    imageAlt: "Disk Clean AI's duplicate finder grouping identical files by content hash with one copy kept.",
  },
  {
    slug: "uninstall-apps-on-mac-completely",
    shortTitle: "Uninstall apps completely",
    title: "How to Completely Uninstall Apps on Mac (and Remove Leftover Files)",
    description:
      "Dragging an app to the Trash leaves caches, support files and launch agents behind. Here's where macOS keeps them, how to remove them safely, and how to spot apps you haven't opened in months.",
    date: "2026-09-02",
    readingMinutes: 9,
    tags: ["How-to", "Apps"],
    image: "/screenshots/apps.webp",
    imageAlt: "Disk Clean AI's Apps view listing installed applications with size and last-used date.",
  },
  {
    slug: "clear-cache-on-mac",
    shortTitle: "Clear cache on Mac",
    title: "How to Clear Cache on Mac Safely: User, System and Browser Caches",
    description:
      "Which Mac caches are safe to clear, which ones macOS manages itself, and exactly how to empty Safari, Chrome, app and developer caches without breaking anything.",
    date: "2026-08-29",
    readingMinutes: 8,
    tags: ["How-to", "Caches"],
    image: "/screenshots/review-clean.webp",
    imageAlt: "Disk Clean AI's review step showing cache folders selected for removal with a total size.",
  },
  {
    slug: "developer-mac-storage-xcode-docker-node-modules",
    shortTitle: "Clean a developer Mac",
    title: "Reclaim Space on a Developer Mac: Xcode, Docker, Homebrew and node_modules",
    description:
      "DerivedData, old simulators, Docker.raw, Homebrew downloads, npm and pip caches, and a forest of node_modules — where developer junk piles up on a Mac and the commands that clear it.",
    date: "2026-08-25",
    readingMinutes: 11,
    tags: ["Developers", "How-to"],
    image: "/screenshots/explore-treemap.webp",
    imageAlt: "Treemap of a developer's home folder dominated by Xcode DerivedData, Docker and node_modules directories.",
  },
  {
    slug: "best-mac-cleaner-apps",
    shortTitle: "Best Mac cleaner apps",
    title: "Best Mac Cleaner Apps: Free and Paid Options Compared",
    updated: "2026-09-24",
    description:
      "An honest comparison of Mac cleaning tools — Apple's built-in Storage settings, free disk visualisers, subscription cleaners and AI-assisted apps — and how to pick one without getting scammed.",
    date: "2026-08-20",
    readingMinutes: 10,
    tags: ["Comparison", "Apps"],
    image: "/screenshots/ai-advisor-ready.webp",
    imageAlt: "Disk Clean AI's AI Advisor suggesting what to clean, with every item waiting for approval.",
  },
];

export const sortedPosts = [...posts].sort((a, b) => (a.date < b.date ? 1 : -1));

export const getPost = (slug: string) => posts.find((p) => p.slug === slug);

export const postUrl = (post: Pick<Post, "slug">) => `${site.url}/blog/${post.slug}`;

export const formatDate = (iso: string) =>
  new Date(`${iso}T00:00:00Z`).toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
    timeZone: "UTC",
  });

/** Up to three other posts, preferring shared tags. */
export function relatedPosts(post: Post, count = 3) {
  return sortedPosts
    .filter((p) => p.slug !== post.slug)
    .map((p) => ({ p, score: p.tags.filter((t) => post.tags.includes(t)).length }))
    .sort((a, b) => b.score - a.score)
    .slice(0, count)
    .map(({ p }) => p);
}
