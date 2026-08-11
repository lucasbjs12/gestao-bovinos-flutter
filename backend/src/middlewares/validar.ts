import { NextFunction, Request, Response } from "express";
import { ZodTypeAny } from "zod";

export function validarBody(schema: ZodTypeAny) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    req.body = schema.parse(req.body);
    next();
  };
}

export function validarQuery(schema: ZodTypeAny) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    // req.query e ParsedQs (readonly no tipo) mas mutavel em runtime; substituimos
    // pelo objeto ja validado/coagido (numeros, defaults) para uso no controller.
    req.query = schema.parse(req.query) as unknown as Request["query"];
    next();
  };
}
