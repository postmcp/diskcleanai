import type { Metadata } from "next";
import { BringYourKey } from "@/components/BringYourKey";
import { FAQ, faqs } from "@/components/FAQ";
import { Features } from "@/components/Features";
import { Footer } from "@/components/Footer";
import { Hero } from "@/components/Hero";
import { HowItWorks } from "@/components/HowItWorks";
import { JsonLd } from "@/components/JsonLd";
import { LatestPosts } from "@/components/LatestPosts";
import { Nav } from "@/components/Nav";
import { OpenSource } from "@/components/OpenSource";
import { Products } from "@/components/Products";
import { downloadUrl, repo, rssAlternate, site } from "@/lib/site";

export const metadata: Metadata = {
  alternates: { canonical: "/", types: rssAlternate },
};

export default function Home() {
  return (
    <>
      <Nav />
      <main className="flex-1">
        <Hero />
        <Features />
        <HowItWorks />
        <BringYourKey />
        <OpenSource />
        <FAQ />
        <LatestPosts />
        <Products />
      </main>
      <Footer />
      <JsonLd
        data={{
          "@context": "https://schema.org",
          "@graph": [
            {
              "@type": "Organization",
              "@id": `${site.url}/#organization`,
              name: site.legalName,
              url: site.url,
              logo: { "@type": "ImageObject", url: `${site.url}/images/mascot.png`, width: 640, height: 640 },
              email: site.supportEmail,
            },
            {
              "@type": "WebSite",
              "@id": `${site.url}/#website`,
              url: site.url,
              name: site.name,
              description: site.description,
              publisher: { "@id": `${site.url}/#organization` },
              inLanguage: "en",
            },
            {
              "@type": "SoftwareApplication",
              "@id": `${site.url}/#app`,
              name: site.name,
              description: site.description,
              url: site.url,
              image: `${site.url}/images/mascot.png`,
              applicationCategory: "UtilitiesApplication",
              operatingSystem: "macOS 14 or later",
              downloadUrl,
              installUrl: downloadUrl,
              softwareHelp: { "@type": "WebPage", url: `${site.url}/blog` },
              isAccessibleForFree: true,
              license: repo.license,
              sameAs: [repo.url],
              featureList: [
                "Disk visualisation: sunburst, treemap, bubbles, mind map, icicle, age map",
                "Quick Wins: caches, logs, Downloads, Trash, Xcode DerivedData, node_modules",
                "Large file finder",
                "Duplicate file finder (SHA-256) and similar photo finder",
                "App uninstaller with leftover support files",
                "AI Advisor using your own OpenRouter key",
                "Nothing deleted without approval; items go to the Trash",
                `Free and open source (${site.license})`,
              ],
              offers: {
                "@type": "Offer",
                price: "0",
                priceCurrency: "USD",
                description: `Free and open source under the ${site.license} license`,
              },
              publisher: { "@id": `${site.url}/#organization` },
            },
            {
              "@type": "SoftwareSourceCode",
              "@id": `${site.url}/#source`,
              name: site.name,
              codeRepository: repo.url,
              programmingLanguage: "Swift",
              runtimePlatform: "macOS 14 or later",
              license: repo.license,
              targetProduct: { "@id": `${site.url}/#app` },
            },
            {
              "@type": "FAQPage",
              "@id": `${site.url}/#faq`,
              mainEntity: faqs.map((f) => ({
                "@type": "Question",
                name: f.q,
                acceptedAnswer: { "@type": "Answer", text: f.a },
              })),
            },
          ],
        }}
      />
    </>
  );
}
