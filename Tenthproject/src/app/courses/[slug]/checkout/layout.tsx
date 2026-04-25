import type { Metadata } from "next";

export const metadata: Metadata = {
  robots: { index: false, follow: false },
  title: "課程結帳",
};

export default function CheckoutLayout({ children }: { children: React.ReactNode }) {
  return children;
}
