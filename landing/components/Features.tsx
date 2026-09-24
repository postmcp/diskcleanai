import Image from "next/image";
import type { ReactNode } from "react";
import {
  AppWindow,
  Check,
  Compass,
  Eye,
  HardDrive,
  Lock,
  Palette,
  Search,
  ShieldCheck,
  Sparkles,
  Trash2,
  Undo2,
  Zap,
} from "lucide-react";
import { ScreenshotTabs, type ScreenshotTab } from "./ScreenshotTabs";
import { Container, SectionHeading } from "./ui";

/* ------------------------------------------------------------------ */
/* Copy. Blurbs and labels match the wording inside the app.           */
/* ------------------------------------------------------------------ */

const exploreTabs: ScreenshotTab[] = [
  {
    id: "sunburst",
    label: "Sunburst",
    blurb: "Rings radiating out from the focused folder.",
    src: "/screenshots/explore-sunburst.webp",
    alt: "Sunburst view: concentric rings of folders coloured by file type, with the total scanned in the centre.",
  },
  {
    id: "treemap",
    label: "Treemap",
    blurb: "Every item is a rectangle sized by bytes.",
    src: "/screenshots/explore-treemap.webp",
    alt: "Treemap view: nested rectangles where each folder's area matches its size on disk.",
  },
  {
    id: "bubbles",
    label: "Bubbles",
    blurb: "Nested bubbles, one per folder.",
    src: "/screenshots/explore-bubbles.webp",
    alt: "Bubbles view: circles packed inside circles, one per folder, sized by bytes.",
  },
  {
    id: "mindmap",
    label: "Mind Map",
    blurb: "Branches from the root, sized by weight.",
    src: "/screenshots/explore-mindmap.webp",
    alt: "Mind map view: the disk as a node graph branching out from the root, heavier folders drawn larger.",
  },
  {
    id: "icicle",
    label: "Icicle",
    blurb: "Layers from the root down, widest wins.",
    src: "/screenshots/explore-icicle.webp",
    alt: "Icicle view: horizontal layers from the root folder down, each band as wide as its share of the disk.",
  },
  {
    id: "topsizes",
    label: "Top Sizes",
    blurb: "The biggest items, ranked.",
    src: "/screenshots/explore-topsizes.webp",
    alt: "Top Sizes view: a ranked bar list of the largest folders with file counts and percentages.",
  },
  {
    id: "agemap",
    label: "Age Map",
    blurb: "Where your bytes sit on a timeline.",
    src: "/screenshots/explore-agemap.webp",
    alt: "Age Map view: how old the bytes are, a heatmap by last-modified month, and a list of big files untouched for over a year.",
  },
  {
    id: "folders",
    label: "Folders",
    blurb: "Browse folder by folder, sized as you go.",
    src: "/screenshots/explore-folders.webp",
    alt: "Folders view: large folder cards showing item counts and sizes.",
  },
  {
    id: "list",
    label: "List",
    blurb: "Outline of every folder with sizes and dates.",
    src: "/screenshots/explore-list.webp",
    alt: "List view: an expandable outline of every folder with size, share, item count and dates.",
  },
];

const findTabs: ScreenshotTab[] = [
  {
    id: "large",
    label: "Large Files",
    blurb: "Every file over 10 MB, largest first.",
    src: "/screenshots/find-large-files.webp",
    alt: "Large Files: a table of the biggest files with size, category, modified and last-opened dates, filterable from 10 MB to 1 GB and up.",
  },
  {
    id: "duplicates",
    label: "Duplicates",
    blurb: "Byte-for-byte copies, grouped.",
    src: "/screenshots/find-duplicates.webp",
    alt: "Duplicates: 285 groups of identical files listed by recoverable size, with a keep rule and one-click staging of the extras.",
  },
  {
    id: "photos",
    label: "Similar Photos",
    blurb: "Near-identical shots, side by side.",
    src: "/screenshots/find-similar-photos.webp",
    alt: "Similar Photos: groups of near-identical images shown as thumbnails, the best copy in each group marked Keep.",
  },
  {
    id: "downloads",
    label: "Downloads",
    blurb: "Old installers, archives and forgotten files.",
    src: "/screenshots/find-downloads.webp",
    alt: "Downloads: files older than 30 days, installers and the largest download summarised, with filters by age and type.",
  },
];

const details = [
  {
    icon: HardDrive,
    title: "Scan anything",
    body: "The startup disk, an external drive, your home folder, ~/Library, or any folder you pick.",
  },
  {
    icon: Lock,
    title: "Protected paths",
    body: "The OS, frameworks, keychains, Mail, Photos and anything inside a package can never be queued.",
  },
  {
    icon: Eye,
    title: "Quick Look & Reveal",
    body: "Preview any file with Quick Look before deciding, or jump straight to it in Finder.",
  },
  {
    icon: Undo2,
    title: "Undo a whole batch",
    body: "Each cleanup is one batch. Changed your mind? Undo puts every item back where it was.",
  },
  {
    icon: Palette,
    title: "Nine themes",
    body: "Daylight, Midnight, Graphite, Nord, Solar, Dusk, Ocean, Forest, Sakura — or follow the system.",
  },
  {
    icon: ShieldCheck,
    title: "No accounts, no telemetry",
    body: "Nothing leaves your Mac except the AI request you choose to send and an anonymous check for updates.",
  },
];

/* ------------------------------------------------------------------ */
/* Building blocks                                                     */
/* ------------------------------------------------------------------ */

function FeatureHeader({
  icon: Icon,
  eyebrow,
  title,
  children,
  illustration,
}: {
  icon: typeof Compass;
  eyebrow: string;
  title: string;
  children: ReactNode;
  illustration?: string;
}) {
  return (
    <div className="grid gap-6 lg:grid-cols-[1fr_minmax(0,34rem)] lg:items-end lg:gap-12">
      <div className="flex items-start gap-4">
        {illustration ? (
          <Image
            src={illustration}
            alt=""
            width={112}
            height={112}
            className="hidden h-16 w-16 shrink-0 sm:block"
          />
        ) : (
          <span className="hidden h-12 w-12 shrink-0 place-items-center rounded-2xl bg-brand-soft text-brand sm:grid">
            <Icon size={22} strokeWidth={2} aria-hidden="true" />
          </span>
        )}
        <div>
          <p className="inline-flex items-center gap-1.5 text-sm font-semibold uppercase tracking-[0.12em] text-brand">
            <Icon size={14} strokeWidth={2.5} aria-hidden="true" className="sm:hidden" />
            {eyebrow}
          </p>
          <h3 className="mt-2 text-balance text-2xl font-bold leading-[1.1] tracking-[-0.03em] text-ink sm:text-3xl">
            {title}
          </h3>
        </div>
      </div>
      <p className="text-pretty text-[15px] leading-relaxed text-body sm:text-base">
        {children}
      </p>
    </div>
  );
}

function Shot({
  src,
  alt,
  sizes,
  className = "",
  width = 2560,
  height = 1624,
}: {
  src: string;
  alt: string;
  sizes: string;
  className?: string;
  width?: number;
  height?: number;
}) {
  return (
    <div
      className={`overflow-hidden rounded-2xl border border-white/70 bg-[#f6f7fb] shadow-[0_1px_0_rgba(255,255,255,0.8)_inset,0_30px_70px_-30px_rgba(16,24,40,0.35)] ring-1 ring-black/5 ${className}`}
    >
      <Image
        src={src}
        alt={alt}
        width={width}
        height={height}
        sizes={sizes}
        quality={90}
        className="block h-auto w-full"
      />
    </div>
  );
}

function FeatureRow({
  icon: Icon,
  eyebrow,
  title,
  body,
  points,
  shot,
  flip = false,
  illustration,
}: {
  icon: typeof Compass;
  eyebrow: string;
  title: string;
  body: string;
  points: string[];
  shot: ReactNode;
  flip?: boolean;
  illustration?: string;
}) {
  return (
    <article className="grid items-center gap-10 lg:grid-cols-12 lg:gap-14">
      <div className={`lg:col-span-5 ${flip ? "lg:order-2" : ""}`}>
        <div className="flex items-start gap-4">
          {illustration ? (
            <Image
              src={illustration}
              alt=""
              width={112}
              height={112}
              className="hidden h-16 w-16 shrink-0 sm:block"
            />
          ) : (
            <span className="hidden h-12 w-12 shrink-0 place-items-center rounded-2xl bg-brand-soft text-brand sm:grid">
              <Icon size={22} strokeWidth={2} aria-hidden="true" />
            </span>
          )}
          <div>
            <p className="inline-flex items-center gap-1.5 text-sm font-semibold uppercase tracking-[0.12em] text-brand">
              <Icon size={14} strokeWidth={2.5} aria-hidden="true" className="sm:hidden" />
              {eyebrow}
            </p>
            <h3 className="mt-2 text-balance text-2xl font-bold leading-[1.1] tracking-[-0.03em] text-ink sm:text-3xl">
              {title}
            </h3>
          </div>
        </div>
        <p className="mt-4 text-pretty text-[15px] leading-relaxed text-body sm:text-base">
          {body}
        </p>
        <ul className="mt-6 space-y-3">
          {points.map((point) => (
            <li key={point} className="flex gap-3 text-[15px] leading-relaxed text-body">
              <span className="mt-1 grid h-5 w-5 shrink-0 place-items-center rounded-full bg-brand-soft text-brand">
                <Check size={12} strokeWidth={3} aria-hidden="true" />
              </span>
              {point}
            </li>
          ))}
        </ul>
      </div>
      <div className={`lg:col-span-7 ${flip ? "lg:order-1" : ""}`}>{shot}</div>
    </article>
  );
}

/* ------------------------------------------------------------------ */
/* Section                                                             */
/* ------------------------------------------------------------------ */

export function Features() {
  const wideShot = "(max-width: 1024px) 100vw, 640px";

  return (
    <section id="features" className="scroll-mt-20 py-24 sm:py-32">
      <Container>
        <SectionHeading
          eyebrow="Features"
          title="Everything taking up space, explained."
          lead="Disk Clean AI scans your whole drive on your Mac, then groups what it finds into things you can actually act on. Every screenshot below is the real app."
        />

        {/* Explore ------------------------------------------------- */}
        <div className="mt-20 sm:mt-24">
          <FeatureHeader icon={Compass} eyebrow="Explore" title="One scan, nine ways to see it.">
            The whole tree, drawn for you. Click any slice, rectangle or bubble
            to focus on it, colour by file type, folder or age, and read the
            details in the inspector on the right. Anything you select can be
            revealed in Finder, previewed with Quick Look, or added to the
            cleanup queue.
          </FeatureHeader>
          <div className="mt-8">
            <ScreenshotTabs tabs={exploreTabs} label="Explore views" />
          </div>
        </div>

        {/* Find ---------------------------------------------------- */}
        <div className="mt-24 sm:mt-32">
          <FeatureHeader
            icon={Search}
            eyebrow="Find"
            title="Large files, duplicates, similar photos, stale downloads."
            illustration="/images/large-files.png"
          >
            Four searches under one roof, each hunting a different kind of
            clutter. Duplicates are matched by size, a partial hash, then a full
            SHA-256 — so a match is a byte-for-byte copy. Similar photos are
            grouped by a perceptual hash, with the best copy marked Keep. Every
            result has a + to stage it for review.
          </FeatureHeader>
          <div className="mt-8">
            <ScreenshotTabs tabs={findTabs} label="Find tools" />
          </div>
        </div>

        {/* Rows ---------------------------------------------------- */}
        <div className="mt-24 space-y-24 sm:mt-32 sm:space-y-32">
          <FeatureRow
            icon={AppWindow}
            eyebrow="Apps"
            title="Unused apps, and everything they left behind."
            body="Every installed app with its size, version and the last time you opened it. Each one lists the caches, logs and support files it keeps in your Library — so you can uninstall the whole thing, or just sweep the leftovers."
            points={[
              "Filter to apps unused for 30, 60, 90, 180 days or a year.",
              "See leftover support files per app, with their paths.",
              "Uninstall, or clean leftovers only and keep the app.",
            ]}
            illustration="/images/unused-apps.png"
            shot={
              <Shot
                src="/screenshots/apps.webp"
                alt="Apps: 18 installed apps ranked by size with last-opened dates; Blender selected, showing its 950 MB bundle, 1.5 MB of leftovers, and Uninstall or Clean leftovers only buttons."
                sizes={wideShot}
              />
            }
          />

          <FeatureRow
            flip
            icon={Zap}
            eyebrow="Quick wins"
            title="Developer clutter, already sorted."
            body="The moment a scan finishes, the sidebar surfaces the usual suspects — with totals. Click one and Explore jumps straight to those folders so you can see exactly what you'd get back."
            points={[
              "iOS Simulator runtimes and Xcode DerivedData.",
              "node_modules and build folders, outermost only.",
              "Downloads, caches and logs, large media, the Trash.",
            ]}
            shot={
              <div className="flex justify-center lg:justify-end">
                <Shot
                  src="/screenshots/quick-wins.webp"
                  alt="The Quick wins list in the sidebar: iOS Simulators 13.5 GB, Large media 1.94 GB, Xcode DerivedData 1.79 GB, Downloads 1.28 GB, Build artifacts 618 MB, node_modules 513 MB."
                  sizes="(max-width: 640px) 80vw, 360px"
                  width={480}
                  height={540}
                  className="w-full max-w-[360px]"
                />
              </div>
            }
          />

          <FeatureRow
            icon={Sparkles}
            eyebrow="AI Advisor"
            title="Ask a model what's safe to remove."
            body="Add an OpenRouter key, pick any model, and the advisor reviews your biggest files, well-known cache folders, old downloads, unused apps and duplicate groups. It explains what's safe to remove and why, with a confidence level on every suggestion."
            points={[
              "Sends names, sizes, kinds and dates — never file contents.",
              "A checkbox shows you exactly what was sent.",
              "A typical run costs a few cents, billed to your own key.",
            ]}
            shot={
              <Shot
                src="/screenshots/ai-advisor-ready.webp"
                alt="AI Advisor, ready to run: the chosen model anthropic/claude-sonnet-4.5, the inputs it will get (60 large files, 60 downloads, 9 unused apps, 25 duplicate groups), and a note that a typical run costs a few cents."
                sizes={wideShot}
              />
            }
          />

          <FeatureRow
            flip
            icon={Trash2}
            eyebrow="Review & Clean"
            title="Nothing moves until you say so."
            body="Everything you stage lands here first, grouped by where it came from. Items from your Library or system folders are flagged for a second look; the rest are marked Safe. Tick what goes, hit Clean, and it all goes to the Trash — never straight to oblivion."
            points={[
              "Approve, skip or remove items one by one or per group.",
              "Quick Look or reveal any item before deciding.",
              "Undo the whole batch with one click.",
            ]}
            illustration="/images/safe-delete.png"
            shot={
              <Shot
                src="/screenshots/review-clean.webp"
                alt="Review & Clean: 6 of 6 items approved for 5.92 GB, two flagged as needing a second look, each item marked Review or Safe, grouped under Large files, Duplicates and Downloads."
                sizes={wideShot}
              />
            }
          />
        </div>

        {/* Details grid -------------------------------------------- */}
        <ul className="mt-24 grid gap-4 sm:mt-32 sm:grid-cols-2 lg:grid-cols-3">
          {details.map(({ icon: Icon, title, body }) => (
            <li
              key={title}
              className="rounded-3xl border border-white/70 bg-white/65 p-6 shadow-[0_1px_0_rgba(255,255,255,0.8)_inset,0_10px_40px_-24px_rgba(16,24,40,0.18)] backdrop-blur-md"
            >
              <span className="grid h-10 w-10 place-items-center rounded-xl bg-brand-soft text-brand">
                <Icon size={18} strokeWidth={2} aria-hidden="true" />
              </span>
              <h4 className="mt-4 text-[17px] font-semibold tracking-[-0.01em] text-ink">
                {title}
              </h4>
              <p className="mt-1.5 text-pretty text-[14.5px] leading-relaxed text-body">
                {body}
              </p>
            </li>
          ))}
        </ul>
      </Container>
    </section>
  );
}
