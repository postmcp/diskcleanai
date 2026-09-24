import { ChevronRight, Scale, ShieldCheck } from "lucide-react";
import { downloadUrl, repo, site } from "@/lib/site";
import { ButtonLink, GitHubIcon } from "../ui";

/** The "try the app" card that closes every post. */
export function AppCTA() {
  return (
    <aside className="not-prose mt-14 rounded-[28px] bg-ink px-7 py-8 text-white sm:px-10 sm:py-10">
      <p className="text-sm font-semibold uppercase tracking-[0.12em] text-chart-cyan">Do it in one scan</p>
      <h2 className="mt-3 text-balance text-2xl font-bold leading-tight tracking-[-0.02em] sm:text-3xl">
        Let Disk Clean AI find all of this for you.
      </h2>
      <p className="mt-4 max-w-xl text-pretty text-[15px] leading-relaxed text-white/70 sm:text-base">
        One scan maps your whole disk, groups the safe wins, finds large files, duplicates and unused apps, and
        explains every suggestion. Nothing is deleted until you approve it, and approved items go to the Trash.
      </p>
      <ul className="mt-5 flex flex-wrap gap-x-6 gap-y-2 text-sm text-white/60">
        <li className="inline-flex items-center gap-2">
          <Scale size={15} className="text-chart-cyan" aria-hidden="true" />
          Free and open source ({site.license})
        </li>
        <li className="inline-flex items-center gap-2">
          <ShieldCheck size={15} className="text-chart-cyan" aria-hidden="true" />
          Nothing deleted without approval
        </li>
      </ul>
      <div className="mt-7 flex flex-col gap-3 sm:flex-row sm:items-center">
        <ButtonLink href={downloadUrl} variant="inverted">
          Download for Mac
          <ChevronRight size={16} aria-hidden="true" />
        </ButtonLink>
        <a
          href={repo.url}
          target="_blank"
          rel="noreferrer"
          className="inline-flex items-center gap-2 text-sm text-white/60 transition-colors hover:text-white"
        >
          <GitHubIcon size={15} />
          Source on GitHub
        </a>
        <span className="text-sm text-white/50">{site.minMacOS} · Apple silicon &amp; Intel</span>
      </div>
    </aside>
  );
}
