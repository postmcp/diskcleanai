import type { Metadata } from "next";
import { LegalPage } from "@/components/legal/LegalPage";
import { repo, site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy policy",
  description: `What ${site.name} collects (very little), what stays on your Mac, and how update checks and the optional AI Advisor handle data.`,
  alternates: { canonical: "/privacy" },
};

export default function PrivacyPage() {
  return (
    <LegalPage eyebrow="Privacy" title="Privacy policy" updated="September 24, 2026">
      <p>
        {site.name} is a Mac app that scans your disk locally. This page explains the small amount of data that leaves your
        Mac, why, and what never does. It applies to the app and to this website. The app and site are operated by {site.legalName}.
        Because the app is <a href={repo.url}>open source</a>, you don&rsquo;t have to take our word for any of this — every network
        request is in the code.
      </p>

      <h2>What stays on your Mac</h2>
      <ul>
        <li><strong>Your files.</strong> Scanning, the disk visualisations, large-file, duplicate, similar-photo and app tools all run on your Mac. File contents are never read for analysis and never uploaded.</li>
        <li><strong>Your OpenRouter API key.</strong> Stored in the macOS Keychain on your Mac. It is sent only to OpenRouter, directly from the app, when you use the AI Advisor.</li>
        <li><strong>Deletions.</strong> Items you approve are moved to the macOS Trash by the app. Nothing is removed without your explicit approval.</li>
      </ul>

      <h2>What the app sends to us</h2>
      <p>
        Nothing. Disk Clean AI has no server of its own: no account, no license key, no device identifier and no analytics.
        The only request the app makes on its own is a once-a-day update check that asks GitHub&rsquo;s public API for the newest
        release of <a href={repo.releases}>{repo.slug}</a> (<code>api.github.com</code>); it sends no information about you or your
        files. You can turn automatic update checks off in Settings.
      </p>

      <h2>Downloads and GitHub</h2>
      <p>
        App downloads, source code, issues and pull requests are hosted on <a href="https://github.com">GitHub</a>. When you download a
        release or take part on GitHub, GitHub&rsquo;s own privacy statement applies, and anything you post in an issue or pull request is
        public.
      </p>

      <h2>The AI Advisor (optional)</h2>
      <p>
        If you add an OpenRouter key and run the AI Advisor, the app sends <strong>scan metadata</strong> — file paths, names, sizes, types and
        dates for the largest and most relevant items — directly from your Mac to OpenRouter and the model you chose. It never sends file
        contents, and it never goes through our servers. Metadata about your files can still be personal (a file name can be), so use a
        model provider you trust; OpenRouter&rsquo;s and the model provider&rsquo;s policies apply to that request.
      </p>

      <h2>This website</h2>
      <p>
        The site uses no analytics scripts, no advertising trackers and no cookies of its own. Our hosting provider keeps standard server
        logs (IP address, user agent, requested page) for a short time for security and capacity purposes.
      </p>

      <h2>Your rights</h2>
      <p>
        We don&rsquo;t hold an account or profile for you. If you&rsquo;ve emailed us and want that correspondence deleted, or to ask
        anything about this policy, email{" "}
        <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a>. We&rsquo;ll respond within a few days. If you are in the EU/EEA or UK
        you also have the right to lodge a complaint with your data protection authority.
      </p>

      <h2>Changes</h2>
      <p>If this policy changes materially we&rsquo;ll update the date above and mention it in the release notes on GitHub.</p>
    </LegalPage>
  );
}
