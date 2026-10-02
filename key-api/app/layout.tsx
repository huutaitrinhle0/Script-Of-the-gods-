import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Expiring Key System",
  description: "Generate and verify keys with hour/day expiration.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
