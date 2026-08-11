/// Endereço do backend próprio (Node/Express + PostgreSQL). Troque via
/// NEXT_PUBLIC_API_URL quando o deploy no Railway estiver pronto (ver
/// backend/README.md) — sem a env var, cai no servidor local de dev.
export const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3000/api/v1";
