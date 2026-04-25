import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export const metadata = { title: "AI 顧問服務" };

const services = [
  "AI strategy call",
  "Workflow audit",
  "Automation design",
  "AI agent implementation",
  "Internal tool build",
  "Team workshop / training",
  "Monthly retainer",
];

export default function ConsultingPage() {
  return (
    <div className="space-y-12">
      <section className="max-w-3xl space-y-4">
        <h1 className="text-3xl font-bold">AI Agent Workflow Automation Consulting</h1>
        <p className="text-lg text-muted-foreground">
          由朱 Sir 與 Chris 提供服務，幫你把 AI、workflow、process 與 automation 真正落地。
        </p>
        <ul className="list-inside list-disc space-y-2 text-sm text-muted-foreground">
          <li>我們不只講 AI</li>
          <li>協助 workflow audit、設計自動化、建立內部工具與 agents</li>
          <li>為 founder／公司／團隊節省時間與成本</li>
        </ul>
        <div className="flex flex-wrap gap-3">
          <Button asChild size="lg">
            <Link href="/consulting/book">預約通話</Link>
          </Button>
          <Button asChild size="lg" variant="outline">
            <Link href="/contact">提交查詢</Link>
          </Button>
        </div>
      </section>
      <section>
        <h2 className="text-xl font-semibold">服務類型</h2>
        <div className="mt-6 grid gap-4 sm:grid-cols-2">
          {services.map((s) => (
            <Card key={s}>
              <CardHeader>
                <CardTitle className="text-base">{s}</CardTitle>
              </CardHeader>
              <CardContent className="text-sm text-muted-foreground">按需求組合提案與報價。</CardContent>
            </Card>
          ))}
        </div>
      </section>
    </div>
  );
}
