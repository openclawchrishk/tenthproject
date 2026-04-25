export const metadata = { title: "活動報名" };

export default function DashboardEventsPage() {
  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">活動報名紀錄</h1>
      <p className="text-sm text-muted-foreground">
        報名寫入 <code className="text-xs">tp_event_registrations</code>。後續可接使用者 email 與 auth 帳戶關聯查詢。
      </p>
    </div>
  );
}
