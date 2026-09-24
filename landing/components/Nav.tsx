"use client";

import { useState } from "react";
import Link from "next/link";
import { Download, Menu, X } from "lucide-react";
import { downloadUrl, navLinks, repo, site } from "@/lib/site";
import { ButtonLink, Container, GitHubIcon, Logo } from "./ui";

export function Nav() {
  const [open, setOpen] = useState(false);

  return (
    <header className="sticky top-0 z-40 border-b border-white/60 bg-white/70 backdrop-blur-md">
      <Container className="flex h-[68px] items-center justify-between gap-6">
        <Link href="/" aria-label="Disk Clean AI — home" className="shrink-0">
          <Logo />
        </Link>

        <nav aria-label="Primary" className="hidden md:block">
          <ul className="flex items-center gap-8">
            {navLinks.map((link) => (
              <li key={link.href}>
                <Link
                  href={link.href}
                  className="text-[15px] font-medium text-ink/80 transition-colors hover:text-ink"
                >
                  {link.label}
                </Link>
              </li>
            ))}
          </ul>
        </nav>

        <div className="hidden items-center gap-5 md:flex">
          <a
            href={repo.url}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-2 text-[15px] font-medium text-ink/80 transition-colors hover:text-ink"
          >
            <GitHubIcon size={18} />
            GitHub
          </a>
          <ButtonLink href={downloadUrl} className="!px-4 !py-2.5">
            Download for Mac
            <Download size={16} strokeWidth={2.2} aria-hidden="true" />
          </ButtonLink>
        </div>

        <button
          type="button"
          className="grid h-10 w-10 place-items-center rounded-lg text-ink hover:bg-surface md:hidden"
          aria-expanded={open}
          aria-controls="mobile-nav"
          aria-label={open ? "Close menu" : "Open menu"}
          onClick={() => setOpen((v) => !v)}
        >
          {open ? <X size={20} /> : <Menu size={20} />}
        </button>
      </Container>

      {open ? (
        <div id="mobile-nav" className="border-t border-line bg-white/90 backdrop-blur-md md:hidden">
          <Container className="flex flex-col gap-1 py-4">
            {navLinks.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                onClick={() => setOpen(false)}
                className="rounded-lg px-3 py-3 text-base font-medium text-ink hover:bg-surface"
              >
                {link.label}
              </Link>
            ))}
            <a
              href={repo.url}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-2 rounded-lg px-3 py-3 text-base font-medium text-ink hover:bg-surface"
            >
              <GitHubIcon size={18} />
              GitHub
            </a>
            <ButtonLink href={downloadUrl} className="mt-3 w-full">
              Download for Mac
              <Download size={16} strokeWidth={2.2} aria-hidden="true" />
            </ButtonLink>
            <p className="mt-2 text-center text-sm text-muted">Free &amp; open source · {site.minMacOS}</p>
          </Container>
        </div>
      ) : null}
    </header>
  );
}
