import Link from "next/link";
import { Mail, Rss } from "lucide-react";
import { sortedPosts } from "@/lib/blog";
import { downloadUrl, products, repo, site } from "@/lib/site";
import { Container, GitHubIcon, Logo } from "./ui";

type FooterLink = { label: string; href: string };

const columns: { heading: string; links: FooterLink[] }[] = [
  {
    heading: "Product",
    links: [
      { label: "Features", href: "/#features" },
      { label: "How it works", href: "/#how-it-works" },
      { label: "Bring your own key", href: "/#bring-your-key" },
      { label: "Open source", href: "/#open-source" },
      { label: "FAQ", href: "/#faq" },
      { label: "Download for Mac", href: downloadUrl },
    ],
  },
  {
    heading: "Guides",
    links: [
      ...sortedPosts.slice(0, 5).map((p) => ({ label: p.shortTitle ?? p.title, href: `/blog/${p.slug}` })),
      { label: "All guides →", href: "/blog" },
    ],
  },
  {
    heading: "Open source",
    links: [
      { label: "Source on GitHub", href: repo.url },
      { label: "Releases", href: repo.releases },
      { label: "Report an issue", href: repo.issues },
      { label: "Contributing", href: repo.contributing },
      { label: `${site.license} license`, href: repo.license },
      { label: "Get an OpenRouter key", href: "https://openrouter.ai/keys" },
    ],
  },
  {
    heading: "More from us",
    links: [...products.map((p) => ({ label: p.name, href: p.url })), { label: "All our tools →", href: "/tools" }],
  },
];

function FooterAnchor({ link, className = "" }: { link: FooterLink; className?: string }) {
  // Downloads stay in this tab; opening a zip in a new one just flashes an empty tab.
  const external = /^https?:/.test(link.href) && !link.href.startsWith(site.url) && link.href !== downloadUrl;
  const internal = link.href.startsWith("/");
  const base = `text-[15px] text-body transition-colors hover:text-ink ${className}`;
  if (internal) {
    return (
      <Link href={link.href} className={base}>
        {link.label}
      </Link>
    );
  }
  return (
    <a href={link.href} className={base} target={external ? "_blank" : undefined} rel={external ? "noreferrer" : undefined}>
      {link.label}
    </a>
  );
}

export function Footer() {
  return (
    <footer className="border-t border-white/70 bg-white/55 backdrop-blur-md">
      <Container className="py-14">
        <div className="grid gap-10 sm:grid-cols-2 lg:grid-cols-[1.5fr_repeat(4,1fr)]">
          <div className="sm:col-span-2 lg:col-span-1">
            <Link href="/" aria-label={`${site.name} — home`} className="inline-block">
              <Logo />
            </Link>
            <p className="mt-4 max-w-xs text-pretty text-[15px] leading-relaxed text-body">
              A free, open-source Mac storage cleaner. Bring your own OpenRouter key, keep your files on your
              machine.
            </p>
            <ul className="mt-5 flex flex-col gap-2 text-[15px]">
              <li>
                <a
                  href={repo.url}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center gap-2 text-body transition-colors hover:text-ink"
                >
                  <GitHubIcon size={15} />
                  {repo.slug}
                </a>
              </li>
              <li>
                <a href={`mailto:${site.supportEmail}`} className="inline-flex items-center gap-2 text-body transition-colors hover:text-ink">
                  <Mail size={15} aria-hidden="true" />
                  {site.supportEmail}
                </a>
              </li>
              <li>
                <a href="/blog/feed.xml" className="inline-flex items-center gap-2 text-body transition-colors hover:text-ink">
                  <Rss size={15} aria-hidden="true" />
                  RSS feed
                </a>
              </li>
            </ul>

            <div className="mt-6">
              <a
                href="http://saasworldmap.com/?ref=badge&p=6ab0cd7ed34145f7fdb366d1"
                target="_blank"
                rel="noopener"
                data-saasworldmap-verification="swm_d59301370d61dd9193daebd4"
                title="Disk Clean Ai on saasworldmap.com"
                className="inline-block transition-opacity hover:opacity-90"
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src="https://api.saasworldmap.com/public/badge/6ab0cd7ed34145f7fdb366d1.svg?t=swm_d59301370d61dd9193daebd4&theme=light"
                  alt="Disk Clean Ai on saasworldmap.com"
                  height="62"
                  loading="lazy"
                />
              </a>
            </div>
          </div>

          {columns.map((column) => (
            <nav key={column.heading} aria-label={column.heading}>
              <h3 className="text-sm font-semibold text-ink">{column.heading}</h3>
              <ul className="mt-4 space-y-2.5">
                {column.links.map((link) => (
                  <li key={link.href}>
                    <FooterAnchor link={link} />
                  </li>
                ))}
              </ul>
            </nav>
          ))}
        </div>

        <div className="mt-12 flex flex-col gap-4 border-t border-line pt-6 text-sm text-muted sm:flex-row sm:items-center sm:justify-between">
          <p>
            © {new Date().getFullYear()} {site.legalName}. Released under the{" "}
            <a href={repo.license} target="_blank" rel="noreferrer" className="underline-offset-2 hover:text-ink hover:underline">
              {site.license} license
            </a>
            .
          </p>
          <ul className="flex flex-wrap items-center gap-x-5 gap-y-2">
            <li>
              <Link href="/privacy" className="transition-colors hover:text-ink">
                Privacy
              </Link>
            </li>
            <li>
              <Link href="/terms" className="transition-colors hover:text-ink">
                Terms
              </Link>
            </li>
            <li>
              <a href="/llms.txt" className="transition-colors hover:text-ink">
                llms.txt
              </a>
            </li>
            <li>Built for {site.minMacOS}, Apple silicon and Intel.</li>
          </ul>
        </div>
      </Container>
    </footer>
  );
}
