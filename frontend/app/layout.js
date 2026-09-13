import "./globals.css";
import { Providers } from "@/context/Providers";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";
import MobileNav from "@/components/layout/MobileNav";
import CartDrawer from "@/components/cart/CartDrawer";
import AuthModals from "@/components/layout/AuthModals";
import QuickViewModal from "@/components/product/QuickViewModal";
import ToastStack from "@/components/ui/ToastStack";

export const metadata = {
  title: "Nova — маркетплейс нового поколения",
  description: "Nova — премиальный маркетплейс: электроника, мода, дом и тысячи продавцов в одном месте.",
};

// Runs before React hydrates so the saved theme applies with zero flash,
// without ever touching React-rendered attributes (avoids hydration
// mismatch warnings — see ThemeContext for the corresponding client sync).
const THEME_INIT_SCRIPT = `
(function () {
  try {
    var theme = localStorage.getItem("mp_theme");
    if (theme === "vivid") document.documentElement.setAttribute("data-theme", "vivid");
  } catch (e) {}
})();
`;

export default function RootLayout({ children }) {
  return (
    <html lang="ru" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
      </head>
      <body>
        <a href="#main" className="skip-link">
          Перейти к содержимому
        </a>
        <Providers>
          <Header />
          <main id="main">{children}</main>
          <Footer />
          <MobileNav />
          <CartDrawer />
          <AuthModals />
          <QuickViewModal />
          <ToastStack />
        </Providers>
      </body>
    </html>
  );
}
