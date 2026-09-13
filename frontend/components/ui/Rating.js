export default function Rating({ value, reviews, reviewsLabel, size }) {
  return (
    <div className="pc-rating" style={size === "lg" ? { fontSize: "var(--fs-sm)", marginBottom: 8 } : undefined}>
      <span className="stars">★★★★★</span>
      <b>{value}</b>
      {reviews != null && (
        <>
          &middot; {reviews} {reviewsLabel}
        </>
      )}
    </div>
  );
}
