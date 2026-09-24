import type { Metadata } from "next";
import { Footer } from "@/components/Footer";
import { JsonLd } from "@/components/JsonLd";
import { Nav } from "@/components/Nav";
import { ToolsGrid } from "@/components/tools/ToolsGrid";
import { Container, Eyebrow } from "@/components/ui";
import { rssAlternate, site } from "@/lib/site";
import { tools } from "@/lib/tools";

const title = "Other tools & all our projects";
const description = `${tools.length} products from the team behind ${site.name}: AI website redesign, social scheduling, support chatbots, image and audio generators, MCP servers and mobile apps.`;

export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: "/tools", types: rssAlternate },
  openGraph: { title: `${title} · ${site.name}`, description, url: "/tools", type: "website" },
};

export default function ToolsPage() {
  return (
    <>
      <Nav />
      <main className="flex-1 pb-24 pt-16 sm:pt-24">
        <Container>
          <div className="max-w-2xl">
            <Eyebrow>Other tools</Eyebrow>
            <h1 className="text-balance text-4xl font-bold leading-[1.05] tracking-[-0.035em] text-ink sm:text-5xl">
              Everything we build, in one place.
            </h1>
            <p className="mt-5 text-pretty text-lg leading-relaxed text-body">
              {site.name} is one of {tools.length} products from {site.legalName}. Each one does a single job well —
              here&apos;s the full list and what each is for.
            </p>
          </div>

          <ToolsGrid />
        </Container>
      </main>
      <Footer />
      <JsonLd
        data={{
          "@context": "https://schema.org",
          "@type": "ItemList",
          name: title,
          url: `${site.url}/tools`,
          description,
          numberOfItems: tools.length,
          itemListElement: tools.map((t, i) => ({
            "@type": "ListItem",
            position: i + 1,
            item: {
              "@type": "SoftwareApplication",
              name: t.name,
              url: t.url,
              description: t.description,
              applicationCategory: t.category,
              author: { "@type": "Organization", name: site.legalName, url: site.url },
            },
          })),
        }}
      />
    </>
  );
}
