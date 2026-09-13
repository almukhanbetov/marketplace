"use client";

import { useState } from "react";
import Modal from "@/components/ui/Modal";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";

export const MOCK_QUESTIONS = [
  { q: "Есть ли официальная гарантия?", a: "Да, гарантия производителя 12 месяцев, плюс 6 месяцев от продавца.", author: "Тимур К." },
  { q: "Возможна ли доставка в другой город?", a: "Да, доставляем по всему Казахстану через партнёрскую логистику.", author: "Асель Ж." },
];

export default function ProductQuestions({ seller }) {
  const { t } = useLanguage();
  const { showToast } = useToast();
  const [askOpen, setAskOpen] = useState(false);
  const [question, setQuestion] = useState("");

  function submit(e) {
    e.preventDefault();
    showToast("Вопрос отправлен продавцу", "success", "✓");
    setAskOpen(false);
    setQuestion("");
  }

  return (
    <div>
      {MOCK_QUESTIONS.map((q, i) => (
        <div className="review-card" key={i}>
          <div className="review-avatar">{q.author.charAt(0)}</div>
          <div style={{ flex: 1 }}>
            <div className="review-name">{q.author}</div>
            <div className="review-text" style={{ margin: "4px 0" }}>
              <b>Q:</b> {q.q}
            </div>
            <div className="review-text" style={{ color: "var(--text)" }}>
              <b style={{ color: "var(--accent)" }}>{seller}:</b> {q.a}
            </div>
          </div>
        </div>
      ))}
      <button className="btn btn--outline" style={{ marginTop: 16 }} onClick={() => setAskOpen(true)}>
        {t("askQuestion")}
      </button>

      <Modal open={askOpen} onClose={() => setAskOpen(false)} title={t("askQuestion")} labelledBy="ask-q-title">
        <form style={{ display: "flex", flexDirection: "column", gap: 14 }} onSubmit={submit}>
          <div className="field">
            <label>Ваш вопрос</label>
            <textarea
              required
              placeholder="Например: Есть ли гарантия?"
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
            />
          </div>
          <button type="submit" className="btn btn--primary btn--block btn--lg">
            {t("askQuestion")}
          </button>
        </form>
      </Modal>
    </div>
  );
}
