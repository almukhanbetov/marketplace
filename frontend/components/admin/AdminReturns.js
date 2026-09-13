import { getMockReturns } from "@/data/adminMock";

export default function AdminReturns() {
  const returns = getMockReturns();
  return (
    <div className="data-table-wrap">
      <table className="data-table">
        <thead><tr><th>Заказ</th><th>Товар</th><th>Причина</th><th>Статус</th></tr></thead>
        <tbody>
          {returns.map((r) => (
            <tr key={r.order}>
              <td>{r.order}</td>
              <td>{r.product}</td>
              <td>{r.reason}</td>
              <td><span className={`status-pill ${r.approved ? "status-pill--done" : "status-pill--new"}`}>{r.approved ? "Одобрен" : "На рассмотрении"}</span></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
