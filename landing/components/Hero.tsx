import Image from "next/image";
import { ChevronRight, Scale, ShieldCheck } from "lucide-react";
import { downloadUrl, repo, site } from "@/lib/site";
import { AppMockup } from "./AppMockup";
import { ButtonLink, Container, GitHubIcon } from "./ui";

export function Hero() {
  return (
    <section id="top" className="relative overflow-x-clip pb-12 pt-20 sm:pt-28">
      {/* Soft blue ground the laptop sits on — same glow as the reference. */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-x-[-10%] bottom-[4%] top-[42%] bg-[radial-gradient(closest-side,rgba(37,99,235,0.16)_0%,rgba(37,99,235,0.05)_55%,rgba(37,99,235,0)_100%)]"
      />

      <Container className="relative">
        <div className="mx-auto max-w-4xl text-center">
          <a
            href={repo.url}
            target="_blank"
            rel="noreferrer"
            className="fade-up fade-up-1 inline-flex items-center gap-2 rounded-full border border-line bg-white px-3.5 py-1.5 text-[13px] font-medium text-body shadow-[0_1px_2px_rgba(0,0,0,0.04)] transition-colors hover:border-brand/40 hover:text-ink"
          >
            <GitHubIcon size={14} className="text-ink" />
            <span className="whitespace-nowrap">Now fully open source</span>
            <span className="h-3.5 w-px bg-line" aria-hidden="true" />
            <span className="whitespace-nowrap">
              <span className="hidden sm:inline">Star </span>{repo.slug}
            </span>
            <ChevronRight size={14} className="text-muted" aria-hidden="true" />
          </a>

          <h1 className="fade-up fade-up-2 mt-7 text-balance text-[44px] font-bold leading-[1.02] tracking-[-0.045em] text-ink sm:text-6xl lg:text-[84px]">
            See what&rsquo;s filling up your Mac.
          </h1>

          <p className="fade-up fade-up-3 mx-auto mt-6 max-w-2xl text-pretty text-lg leading-relaxed text-body sm:text-2xl sm:leading-snug">
            Visualize every file, uncover hidden clutter, and safely reclaim
            space with AI.
          </p>

          <ul className="fade-up fade-up-4 mt-7 flex flex-wrap items-center justify-center gap-x-3 gap-y-2 text-[15px] text-body sm:text-base">
            <li className="inline-flex items-center gap-2">
              <Scale size={18} className="text-chart-coral" aria-hidden="true" />
              Free and open source ({site.license})
            </li>
            <li aria-hidden="true" className="hidden h-5 w-px bg-line sm:block" />
            <li className="inline-flex items-center gap-2">
              <ShieldCheck size={18} className="text-brand" aria-hidden="true" />
              Nothing deleted without approval
            </li>
          </ul>

          <div className="fade-up fade-up-5 mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <ButtonLink href={downloadUrl} size="lg" className="w-full sm:w-auto">
              Download for Mac
              <ChevronRight size={18} aria-hidden="true" />
            </ButtonLink>
            <ButtonLink
              href={repo.url}
              target="_blank"
              rel="noreferrer"
              variant="secondary"
              size="lg"
              className="w-full sm:w-auto"
            >
              <GitHubIcon size={18} />
              Star on GitHub
            </ButtonLink>
          </div>

          <p className="fade-up fade-up-5 mt-6 text-[15px] text-muted">
            No account. No license key. No catch.
          </p>
        </div>

        <div className="fade-up fade-up-6 relative mt-14 sm:mt-20">
          <Image
            src="/images/mascot.png"
            alt=""
            width={200}
            height={200}
            className="pointer-events-none absolute -top-[92px] right-4 z-10 hidden w-28 -rotate-6 drop-shadow-[0_12px_20px_rgba(37,99,235,0.25)] sm:block lg:-top-[136px] lg:right-8 lg:w-40"
          />
          <AppMockup />
        </div>
      </Container>
    </section>
  );
}
