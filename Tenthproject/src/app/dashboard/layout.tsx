import Link from "next/link";
import { redirect } from "next/navigation";
import { signOutAction } from "@/app/actions/auth";
import { createClient } from "@/lib/supabase/server";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

const links = [
  { href: "/dashboard", label: "總覽" },
  { href: "/dashboard/projects", label: "我的項目" },
  { href: "/dashboard/applications", label: "我的申請" },
  { href: "/dashboard/events", label: "活動報名" },
  { href: "/dashboard/bookings", label: "顧問紀錄" },
];

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  if (!supabase) {
    return <div className="p-6 text-sm text-muted-foreground">請設定 Supabase 環境變數。</div>;
  }
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/auth/login?next=/dashboard");

  return (
    <div className="flex flex-col gap-8 lg:flex-row">
      <aside className="shrink-0 lg:w-52">
        <p className="mb-3 text-xs text-muted-foreground">已登入：{user.email}</p>
        <nav className="flex flex-row flex-wrap gap-2 lg:flex-col lg:gap-1">
          {links.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className={cn(
                "rounded-md px-3 py-2 text-sm font-medium text-muted-foreground hover:bg-accent hover:text-foreground"
              )}
            >
              {l.label}
            </Link>
          ))}
        </nav>
        <form action={signOutAction} className="mt-6">
          <Button type="submit" variant="outline" size="sm">
            登出
          </Button>
        </form>
      </aside>
      <div className="min-w-0 flex-1">{children}</div>
    </div>
  );
}
