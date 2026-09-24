import type { Metadata } from "next";
import { LegalPage } from "@/components/legal/LegalPage";
import { repo, site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Terms of use",
  description: `The plain-English terms for using ${site.name}: the open-source license, what you're responsible for, and how the optional AI Advisor works.`,
  alternates: { canonical: "/terms" },
};

export default function TermsPage() {
  return (
    <LegalPage eyebrow="Terms" title="Terms of use" updated="September 24, 2026">
      <p>
        These terms cover the {site.name} app and website, provided by {site.legalName}. By downloading or using the app you agree to
        them. They&rsquo;re short on purpose; if anything is unclear, email <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a>.
      </p>

      <h2>Open-source license</h2>
      <p>
        {site.name} is free and open source. The source code is published at <a href={repo.url}>{repo.url.replace(/^https:\/\//, "")}</a>{" "}
        under the <a href={repo.license}>{site.license} license</a>, which lets you use, copy, modify and redistribute it, including
        commercially, as long as the license notice comes along. If anything on this page conflicts with the {site.license} license for the
        source code, the license wins.
      </p>
      <p>
        There is no trial, subscription, account or license key, and nothing to pay us. Builds published on the GitHub releases page are
        the official ones; builds from forks or other sites are the responsibility of whoever made them.
      </p>

      <h2>Contributions</h2>
      <p>
        Issues and pull requests are welcome. By submitting a contribution you agree that it is your own work and that it may be
        distributed under the project&rsquo;s {site.license} license.
      </p>

      <h2>Your responsibility</h2>
      <p>
        {site.name} shows you what&rsquo;s on your disk and moves the items <em>you</em> approve to the macOS Trash. It makes no changes
        without that approval, and it marks system locations as protected — but you decide what to remove. Review the list before you
        confirm, keep a backup (Time Machine is fine), and don&rsquo;t empty the Trash until you&rsquo;re sure. We are not liable for
        data you chose to delete.
      </p>

      <h2>The AI Advisor and third parties</h2>
      <p>
        The AI Advisor is optional and uses your own OpenRouter account; OpenRouter charges you for model usage under its own terms, and we
        add no markup. Model suggestions can be wrong, which is why they are presented as checkboxes for you to approve, never applied
        automatically. Our <a href="/privacy">privacy policy</a> describes exactly what is sent.
      </p>

      <h2>Warranty and liability</h2>
      <p>
        The app is provided &ldquo;as is&rdquo;. To the extent permitted by law, {site.legalName} is not liable for indirect or
        consequential loss arising from the app, as set out in the {site.license} license. Nothing here limits rights you have as a
        consumer under the laws of your country.
      </p>

      <h2>Updates and changes</h2>
      <p>
        The app checks for updates once a day and installs them after verifying a checksum; you can turn automatic checks off in
        Settings, or download any version from the <a href={repo.releases}>releases page</a>. We may update these terms; the date above changes when we do, and continued use after a change means you accept it.
      </p>
    </LegalPage>
  );
}
