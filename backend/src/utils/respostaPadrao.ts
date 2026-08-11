import { Response } from "express";

export function sucesso<T>(res: Response, data: T, message = "OK", status = 200): Response {
  return res.status(status).json({ success: true, message, data });
}

export function erro(res: Response, status: number, message: string, error?: unknown): Response {
  return res.status(status).json({ success: false, message, error: error ?? null });
}
