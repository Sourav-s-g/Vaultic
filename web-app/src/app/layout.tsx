import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";
import { AppProviders } from "@/components/app-providers";
import { WorkspaceShell } from "@/components/workspace-shell";

export const metadata: Metadata = {
  title: "Dashboard · Vaultic",
  description: "A clear, private workspace for personal finance.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <AppProviders>
          <WorkspaceShell>{children}</WorkspaceShell>
        </AppProviders>
      </body>
    </html>
  );
}
