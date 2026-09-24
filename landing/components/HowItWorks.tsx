import Image from "next/image";
import { CheckCircle2, ScanSearch, Sparkles } from "lucide-react";
import { Container, SectionHeading } from "./ui";

const steps = [
  {
    n: 1,
    title: "Scan",
    body:
      "Point it at a drive or folder. The scan runs entirely on your Mac — nothing is uploaded, and a full startup disk takes about a minute.",
    icon: ScanSearch,
    color: "bg-chart-blue",
    shot: "/screenshots/welcome.webp",
    alt: "The welcome screen with Scan Macintosh HD, Scan Home Folder and Choose Folder buttons.",
  },
  {
    n: 2,
    title: "Ask the AI",
    body:
      "Add your OpenRouter key and pick a model. It reads names, sizes and dates — never file contents — and explains what's safe to remove and why.",
    icon: Sparkles,
    color: "bg-chart-violet",
    shot: "/screenshots/ai-advisor-ready.webp",
    alt: "The AI Advisor screen showing the chosen model and the inputs it will receive.",
  },
  {
    n: 3,
    title: "Approve and clean",
    body:
      "Tick what goes, skip what stays, hit Clean. Everything lands in the Trash, so you can still change your mind.",
    icon: CheckCircle2,
    color: "bg-chart-teal",
    shot: "/screenshots/review-clean.webp",
    alt: "The Review & Clean screen with six approved items totalling 5.92 GB.",
  },
];

export function HowItWorks() {
  return (
    <section id="how-it-works" className="scroll-mt-20 py-24 sm:py-32">
      <Container>
        <SectionHeading
          eyebrow="How it works"
          title="Three steps. You stay in control of each one."
        />

        <ol className="relative mt-14 grid gap-10 md:grid-cols-3 md:gap-6">
          {steps.map(({ n, title, body, icon: Icon, color, shot, alt }) => (
            <li key={n} className="flex flex-col">
              <div className="flex items-center gap-3">
                <span
                  className={`grid h-12 w-12 place-items-center rounded-2xl text-white ${color}`}
                >
                  <Icon size={22} strokeWidth={2} aria-hidden="true" />
                </span>
                <span className="font-mono text-sm text-muted">Step {n}</span>
              </div>
              <h3 className="mt-5 text-xl font-semibold tracking-[-0.02em] text-ink">
                {title}
              </h3>
              <p className="mt-2 text-pretty text-[15px] leading-relaxed text-body">
                {body}
              </p>
              <div className="mt-auto pt-6">
                <div className="overflow-hidden rounded-2xl border border-white/70 bg-[#f6f7fb] shadow-[0_1px_0_rgba(255,255,255,0.8)_inset,0_24px_50px_-28px_rgba(16,24,40,0.35)] ring-1 ring-black/5">
                  <Image
                    src={shot}
                    alt={alt}
                    width={2560}
                    height={1624}
                    sizes="(max-width: 768px) 100vw, 360px"
                    quality={90}
                    className="block h-auto w-full"
                  />
                </div>
              </div>
            </li>
          ))}
        </ol>
      </Container>
    </section>
  );
}
