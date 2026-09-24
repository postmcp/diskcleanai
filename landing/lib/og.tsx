import { ImageResponse } from "next/og";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { site } from "./site";

export const ogSize = { width: 1200, height: 630 };
export const ogContentType = "image/png";

/* Read once per build; the mascot is the same on every card. */
const mascot = readFile(join(process.cwd(), "public/icons/mascot-256.png")).then(
  (buf) => `data:image/png;base64,${buf.toString("base64")}`,
);

type Card = {
  title: string;
  subtitle?: string;
  /** Small label above the title, e.g. "Guide · 9 min read". */
  kicker?: string;
};

/** Shared Open Graph card: white ground, blue accent, mascot — matches the site. */
export async function ogCard({ title, subtitle, kicker }: Card) {
  const long = title.length > 60;
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          padding: "64px 72px",
          background: "linear-gradient(135deg, #ffffff 0%, #eef3ff 100%)",
          color: "#0b0b0f",
          fontFamily: "sans-serif",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={await mascot} width={64} height={64} alt="" />
          <span style={{ fontSize: 30, fontWeight: 700, letterSpacing: -0.5 }}>{site.name}</span>
          {kicker ? (
            <span
              style={{
                marginLeft: 12,
                padding: "6px 14px",
                borderRadius: 999,
                background: "#dce6ff",
                color: "#1d4ed8",
                fontSize: 22,
                fontWeight: 600,
              }}
            >
              {kicker}
            </span>
          ) : null}
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 22 }}>
          <div
            style={{
              fontSize: long ? 58 : 68,
              fontWeight: 800,
              lineHeight: 1.05,
              letterSpacing: -2,
              maxWidth: 1000,
            }}
          >
            {title}
          </div>
          {subtitle ? (
            <div style={{ fontSize: 28, lineHeight: 1.35, color: "#55565f", maxWidth: 960 }}>{subtitle}</div>
          ) : null}
        </div>

        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", fontSize: 24, color: "#8b8d98" }}>
          <span>{site.url.replace(/^https?:\/\//, "")}</span>
          <span style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <span style={{ width: 12, height: 12, borderRadius: 999, background: "#2563eb" }} />
            Free, open-source Mac storage cleaner
          </span>
        </div>
      </div>
    ),
    ogSize,
  );
}
