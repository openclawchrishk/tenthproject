import type { Metadata } from "next";
import localFont from "next/font/local";
import "./globals.css";
import { SiteFooter, SiteHeader } from "@/components/site-shell";

const geistSans = localFont({
  src: "./fonts/GeistVF.woff",
  variable: "--font-geist-sans",
  weight: "100 900",
});

export const metadata: Metadata = {
  title: {
    default: "Tenthproject — Connect great ideas and investment",
    template: "%s · Tenthproject",
  },
  description:
    "專業路演與機遇平台：發佈項目、審批申請、資料室協作，以及 AI workflow 顧問與課程生態。",
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000"),
};

export const dynamic = "force-dynamic";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh-Hant">
      <body className={`${geistSans.variable} min-h-screen font-sans antialiased`}>
        <SiteHeader />
        <main className="mx-auto min-h-[calc(100vh-8rem)] max-w-6xl px-4 py-8 sm:px-6">{children}</main>
        <SiteFooter />
      </body>
    </html>
  );
}
