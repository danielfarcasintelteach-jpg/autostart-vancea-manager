import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "AUTOSTART VANCEA Manager",
  description: "Administrarea școlii de șoferi AUTOSTART VANCEA",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="ro" className="h-full antialiased">
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
