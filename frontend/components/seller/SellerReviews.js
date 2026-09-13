const REVIEWS = [
  { name: "Нурлан Б.", text: "Быстрая доставка, товар как на фото. Спасибо!", rating: 5 },
  { name: "Салтанат Р.", text: "Отличный продавец, всегда на связи.", rating: 5 },
  { name: "Данияр К.", text: "Один товар пришёл с небольшим браком, но продавец быстро заменил.", rating: 4 },
];

export default function SellerReviews() {
  return (
    <div>
      {REVIEWS.map((r, i) => (
        <div className="review-card" key={i}>
          <div className="review-avatar">{r.name.charAt(0)}</div>
          <div>
            <div className="review-head">
              <span className="review-name">{r.name}</span>
              <span className="stars">{"★".repeat(r.rating)}</span>
            </div>
            <div className="review-text">{r.text}</div>
          </div>
        </div>
      ))}
    </div>
  );
}
