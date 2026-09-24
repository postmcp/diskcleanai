import { Bug, Code2, Download, Eye, GitPullRequest, Hammer, Scale, Star } from "lucide-react";
import { downloadUrl, repo, site } from "@/lib/site";
import { ButtonLink, Container, GitHubIcon } from "./ui";

const pillars = [
  {
    icon: Eye,
    title: "Read every line",
    text: "The code that scans your disk, decides what's safe, and moves files to the Trash is all public. So is exactly what gets sent to the AI.",
  },
  {
    icon: Hammer,
    title: "Build it yourself",
    text: "Clone the repo, open it in Xcode 16 and hit Run. No account, no license key, no server you have to trust.",
  },
  {
    icon: GitPullRequest,
    title: "Make it better",
    text: "Found a cache folder we missed or a pattern that would help? Open an issue or send a pull request.",
  },
];

const buildSteps = [
  `git clone ${repo.clone}`,
  "cd diskcleanai/macApp",
  "open DiskCleanAI.xcodeproj",
];

const links = [
  { icon: Star, label: "Star the repo", href: repo.url },
  { icon: Bug, label: "Report a bug", href: repo.newIssue },
  { icon: Code2, label: "Contributing guide", href: repo.contributing },
  { icon: Scale, label: `${site.license} license`, href: repo.license },
];

export function OpenSource() {
  return (
    <section id="open-source" className="scroll-mt-20 py-12 sm:py-16">
      <Container>
        <div className="rounded-[32px] bg-ink px-6 py-12 text-white shadow-[0_40px_80px_-40px_rgba(11,11,15,0.6)] sm:px-12 sm:py-16 lg:px-16">
          <div className="grid items-end gap-10 lg:grid-cols-[1.2fr_auto]">
            <div className="max-w-2xl">
              <p className="mb-4 inline-flex items-center gap-2 text-sm font-semibold uppercase tracking-[0.12em] text-chart-cyan">
                <GitHubIcon size={16} />
                Open source
              </p>
              <h2 className="text-balance text-3xl font-bold leading-[1.08] tracking-[-0.03em] sm:text-4xl lg:text-[44px]">
                Free forever. Every line on GitHub.
              </h2>
              <p className="mt-5 text-pretty text-lg leading-relaxed text-white/70">
                {site.name} is {site.license}-licensed and completely free. There&rsquo;s no trial, no
                subscription and no license key. An app that can delete your files should be one you can
                read, so all of it is public.
              </p>
            </div>
            <div className="flex flex-col gap-3 sm:flex-row lg:flex-col">
              <ButtonLink href={repo.url} target="_blank" rel="noreferrer" variant="inverted">
                <GitHubIcon size={18} />
                View on GitHub
              </ButtonLink>
              <ButtonLink
                href={downloadUrl}
                className="border border-white/15 !bg-white/5 text-white hover:!bg-white/10"
              >
                <Download size={18} aria-hidden="true" />
                Download latest release
              </ButtonLink>
            </div>
          </div>

          <div className="mt-14 grid gap-4 lg:grid-cols-[1fr_1fr_1fr]">
            {pillars.map(({ icon: Icon, title, text }) => (
              <article key={title} className="rounded-3xl border border-white/10 bg-white/5 p-7">
                <span className="grid h-10 w-10 place-items-center rounded-xl bg-white/10 text-chart-cyan">
                  <Icon size={20} aria-hidden="true" />
                </span>
                <h3 className="mt-5 text-lg font-semibold tracking-[-0.01em]">{title}</h3>
                <p className="mt-2 text-[15px] leading-relaxed text-white/65">{text}</p>
              </article>
            ))}
          </div>

          <div className="mt-4 overflow-hidden rounded-3xl border border-white/10 bg-black/40">
            <div className="flex items-center gap-2 border-b border-white/10 px-5 py-3">
              <span className="h-3 w-3 rounded-full bg-white/15" aria-hidden="true" />
              <span className="h-3 w-3 rounded-full bg-white/15" aria-hidden="true" />
              <span className="h-3 w-3 rounded-full bg-white/15" aria-hidden="true" />
              <span className="ml-3 text-[13px] text-white/45">Terminal · build from source</span>
            </div>
            <pre className="overflow-x-auto px-5 py-5 font-mono text-[13px] leading-7 text-white/85 sm:text-sm">
              {buildSteps.map((line) => (
                <code key={line} className="block whitespace-pre">
                  <span className="select-none text-chart-mint">$ </span>
                  {line}
                </code>
              ))}
            </pre>
          </div>

          <ul className="mt-10 flex flex-wrap items-center justify-center gap-x-8 gap-y-3 text-sm text-white/60">
            {links.map(({ icon: Icon, label, href }) => (
              <li key={label}>
                <a
                  href={href}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center gap-2 transition-colors hover:text-white"
                >
                  <Icon size={16} className="text-chart-cyan" aria-hidden="true" />
                  {label}
                </a>
              </li>
            ))}
          </ul>
        </div>
      </Container>
    </section>
  );
}
