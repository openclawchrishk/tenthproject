import Link from "next/link";
import { Button } from "@/components/ui/button";

const nav = [
  { href: "/projects", label: "項目與路演" },
  { href: "/consulting", label: "AI 顧問" },
  { href: "/events", label: "活動" },
  { href: "/courses", label: "課程" },
  { href: "/investors", label: "投資者" },
  { href: "/about", label: "關於" },
  { href: "/contact", label: "聯絡" },
];

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-50 border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/80">
      <div className="mx-auto flex h-14 max-w-6xl items-center justify-between gap-4 px-4 sm:px-6">
        <Link href="/" className="text-lg font-semibold tracking-tight text-foreground">
          Tenthproject
        </Link>
        <nav className="hidden items-center gap-1 md:flex">
          {nav.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="rounded-md px-3 py-2 text-sm font-medium text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="flex items-center gap-2">
          <Button variant="ghost" size="sm" className="hidden sm:inline-flex" asChild>
            <Link href="/dashboard">後台</Link>
          </Button>
          <Button size="sm" asChild>
            <Link href="/auth/login">登入</Link>
          </Button>
        </div>
      </div>
    </header>
  );
}

export function SiteFooter() {
  return (
    <footer className="border-t bg-muted/40 py-12">
      <div className="mx-auto grid max-w-6xl gap-8 px-4 sm:grid-cols-2 sm:px-6 lg:grid-cols-4">
        <div>
          <p className="text-sm font-semibold">Tenthproject</p>
          <p className="mt-2 text-sm text-muted-foreground">
            Connect great ideas and investment — 專業路演與機遇平台（香港）。
          </p>
        </div>
        <div>
          <p className="text-sm font-semibold">平台</p>
          <ul className="mt-2 space-y-2 text-sm text-muted-foreground">
            <li>
              <Link href="/projects" className="hover:text-foreground">
                瀏覽項目
              </Link>
            </li>
            <li>
              <Link href="/projects/new" className="hover:text-foreground">
                發佈項目
              </Link>
            </li>
            <li>
              <Link href="/dashboard" className="hover:text-foreground">
                會員後台
              </Link>
            </li>
          </ul>
        </div>
        <div>
          <p className="text-sm font-semibold">服務</p>
          <ul className="mt-2 space-y-2 text-sm text-muted-foreground">
            <li>
              <Link href="/consulting" className="hover:text-foreground">
                AI 自動化顧問
              </Link>
            </li>
            <li>
              <Link href="/events" className="hover:text-foreground">
                Webinar
              </Link>
            </li>
            <li>
              <Link href="/courses" className="hover:text-foreground">
                Vibe Coding 課程
              </Link>
            </li>
          </ul>
        </div>
        <div>
          <p className="text-sm font-semibold">法律與聯絡</p>
          <ul className="mt-2 space-y-2 text-sm text-muted-foreground">
            <li>
              <Link href="/contact" className="hover:text-foreground">
                聯絡我們
              </Link>
            </li>
            <li>
              <Link href="/investors" className="hover:text-foreground">
                投資者網絡
              </Link>
            </li>
          </ul>
        </div>
      </div>
      <p className="mx-auto mt-10 max-w-6xl px-4 text-center text-xs text-muted-foreground sm:px-6">
        © {new Date().getFullYear()} Tenthproject. 與 DeskerHK 流動應用共用同一 Supabase 資料庫。
      </p>
    </footer>
  );
}
