export const metadata = { title: "顧問紀錄" };

export default function DashboardBookingsPage() {
  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Consulting booking 記錄</h1>
      <p className="text-sm text-muted-foreground">
        查詢寫入 <code className="text-xs">tp_consulting_leads</code>。進階版本可與日曆／CRM 同步。
      </p>
    </div>
  );
}
