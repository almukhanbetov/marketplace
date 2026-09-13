export default function AdminSettings() {
  return (
    <div className="info-card" style={{ maxWidth: 520 }}>
      <div className="field" style={{ marginBottom: 14 }}><label>Название платформы</label><input defaultValue="Nova Marketplace" /></div>
      <div className="field" style={{ marginBottom: 14 }}><label>Комиссия по умолчанию</label><input defaultValue="10%" /></div>
      <div className="field" style={{ marginBottom: 14 }}><label>Email поддержки</label><input defaultValue="support@nova.kz" /></div>
      <button className="btn btn--primary">Сохранить</button>
    </div>
  );
}
