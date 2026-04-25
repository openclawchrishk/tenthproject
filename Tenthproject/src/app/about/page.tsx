export const metadata = { title: "關於我們" };

export default function AboutPage() {
  return (
    <div className="mx-auto max-w-3xl space-y-8 text-sm leading-relaxed text-muted-foreground">
      <h1 className="text-3xl font-bold text-foreground">關於 Tenthproject</h1>
      <p>
        我們不是只做內容，也不是只做課程。Tenthproject 正在建立一個真實的機遇與路演平台：讓 founder、investor、operator
        與機構在審批、資料室與顧問服務之下，安全地推進合作。
      </p>
      <p>
        <span className="font-semibold text-foreground">Mission：</span>
        Connect great ideas and investment — 以專業流程連結想法與資本，並以 AI workflow 顧問協助團隊落地。
      </p>
      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-foreground">朱 Sir</h2>
        <p>首席導師與技術負責人，專注 AI、系統開發、產品思維與 workflow automation。</p>
      </section>
      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-foreground">Chris Lau</h2>
        <p>創辦人與商業負責人，專注 product strategy、community、路演協調、business development 與 deal flow orchestration。</p>
      </section>
    </div>
  );
}
