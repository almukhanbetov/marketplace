"use client";

import { createContext, useContext, useCallback, useMemo, useState } from "react";

const ModalContext = createContext(null);

/**
 * Global controller for modals that can be triggered from anywhere in the
 * tree (login/register from the header, quick view from any product card).
 * Page-local modals (gallery, add-product, ask-question) use the same
 * <Modal> component but manage their own open state instead of this context.
 */
export function ModalProvider({ children }) {
  const [activeModal, setActiveModal] = useState(null);
  const [modalData, setModalData] = useState(null);

  const openModal = useCallback((id, data = null) => {
    setActiveModal(id);
    setModalData(data);
  }, []);

  const closeModal = useCallback(() => {
    setActiveModal(null);
    setModalData(null);
  }, []);

  const value = useMemo(
    () => ({ activeModal, modalData, openModal, closeModal }),
    [activeModal, modalData, openModal, closeModal]
  );

  return <ModalContext.Provider value={value}>{children}</ModalContext.Provider>;
}

export function useModal() {
  const ctx = useContext(ModalContext);
  if (!ctx) throw new Error("useModal must be used within ModalProvider");
  return ctx;
}
