import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

export default function HomePage() {
  return (
    <div className="space-y-20">
      <section className="rounded-2xl border bg-card px-6 py-16 text-center shadow-sm sm:px-10">
        <p className="text-sm font-medium uppercase tracking-widest text-secondary">Professional platform</p>
        <h1 className="mt-4 text-3xl font-bold tracking-tight text-foreground sm:text-5xl">
          Connect great ideas and investment
        </h1>
        <p className="mx-auto mt-4 max-w-2xl text-lg text-muted-foreground">
          A professional platform for project roadshows, investor discovery, AI automation consulting, and
          learning experiences.
        </p>
        <ul className="mx-auto mt-6 max-w-xl space-y-2 text-left text-sm text-muted-foreground sm:text-center sm:text-base">
          <li>免費發佈項目或路演 · 精準邀請合適的人選</li>
          <li>審批申請 · 在安全的資料室分享機密資料</li>
          <li>預約 AI agent 顧問 · Webinar 與課程生態</li>
        </ul>
        <div className="mt-10 flex flex-wrap items-center justify-center gap-3">
          <Button asChild size="lg">
            <Link href="/projects/new">發佈項目</Link>
          </Button>
          <Button asChild size="lg" variant="outline">
            <Link href="/projects">瀏覽項目</Link>
          </Button>
          <Button asChild size="lg" variant="secondary">
            <Link href="/events">Webinar 報名</Link>
          </Button>
          <Button asChild size="lg" variant="ghost">
            <Link href="/consulting/book">預約顧問</Link>
          </Button>
          <Button asChild size="lg" variant="ghost">
            <Link href="/investors">加入投資者網絡</Link>
          </Button>
        </div>
      </section>

      <section>
        <h2 className="text-center text-2xl font-bold">三大支柱</h2>
        <p className="mx-auto mt-2 max-w-2xl text-center text-muted-foreground">
          我們不是單一課程站，而是可擴展的機遇與服務平台。
        </p>
        <div className="mt-10 grid gap-6 md:grid-cols-3">
          <Card>
            <CardHeader>
              <CardTitle>項目與路演</CardTitle>
              <CardDescription>Project & Roadshow Discovery</CardDescription>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground">
              發佈項目、招募角色、審批申請、資料室協作。適合認真 founder、operator 與投資者對接。
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle>AI 自動化顧問</CardTitle>
              <CardDescription>Workflow & agents</CardDescription>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground">
              由朱 Sir 與 Chris 提供：流程盤點、自動化設計、內部工具與 agent 落地，節省團隊時間並建立槓桿。
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle>Webinar 與課程</CardTitle>
              <CardDescription>Lead → payment</CardDescription>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground">
              免費 Webinar 建立信任；課程收款頁僅向合適對象發放連結，配合 Stripe 完成付款與解鎖。
            </CardContent>
          </Card>
        </div>
      </section>

      <section className="rounded-2xl border bg-muted/30 p-8 sm:p-12">
        <h2 className="text-2xl font-bold">運作流程</h2>
        <ol className="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {[
            "創辦人發佈項目或路演",
            "申請者按開放角色提交申請",
            "創辦人審批、短名單、錄取或拒絕",
            "錄取成員進入資料室協作",
          ].map((t, i) => (
            <li key={t} className="flex gap-3">
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-primary text-sm font-bold text-primary-foreground">
                {i + 1}
              </span>
              <span className="text-sm leading-relaxed text-foreground">{t}</span>
            </li>
          ))}
        </ol>
      </section>

      <section>
        <h2 className="text-2xl font-bold">專業與信任</h2>
        <p className="mt-4 max-w-3xl text-muted-foreground">
          此平台面向 founder、investor、operator、機構與上市公司路演場景。設有申請、審批與資料室權限，支援真實項目與私密機會，而非一般社交群組。
        </p>
        <p className="mt-4 text-sm text-muted-foreground">
          Beta 開放期：首批路演與 cohort 招募中；數字與案例以「early access」形式更新，不作虛假宣傳。
        </p>
      </section>

      <section className="grid gap-10 md:grid-cols-2">
        <div>
          <h3 className="text-lg font-semibold text-secondary">朱 Sir</h3>
          <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
            首席導師與技術負責人，專注 AI、系統開發、產品思維與 workflow automation。把複雜技術整理成可落地的方案，協助客戶建立真正的 automation system。
          </p>
        </div>
        <div>
          <h3 className="text-lg font-semibold text-secondary">Chris Lau</h3>
          <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
            創辦人與商業負責人，專注 product strategy、community、路演協調、business development 與 deal flow
            orchestration，把平台、用戶與商業模式串連。
          </p>
        </div>
      </section>
    </div>
  );
}
