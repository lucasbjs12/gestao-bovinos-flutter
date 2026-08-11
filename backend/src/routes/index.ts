import { Router } from "express";
import { healthRouter } from "./health.routes";
import { authRouter } from "./auth.routes";
import { fazendaRouter } from "./fazenda.routes";
import { invernadaRouter } from "./invernada.routes";
import { bovinoRouter } from "./bovino.routes";
import { eventoSanitarioRouter } from "./eventoSanitario.routes";
import { movimentacaoRouter } from "./movimentacao.routes";
import { atividadeRouter } from "./atividade.routes";
import { conviteRouter } from "./convite.routes";
import { convitePublicoRouter } from "./convitePublico.routes";
import { membroRouter } from "./membro.routes";
import { uploadRouter } from "./upload.routes";
import { adminRouter } from "./admin.routes";
import { docsRouter } from "./docs.routes";

export const apiRouter = Router();

apiRouter.use("/v1/health", healthRouter);
apiRouter.use("/v1/docs", docsRouter);
apiRouter.use("/v1/auth", authRouter);
apiRouter.use("/v1/convites", convitePublicoRouter);
apiRouter.use("/v1/admin", adminRouter);

apiRouter.use("/v1/fazendas/:fazendaId", fazendaRouter);
apiRouter.use("/v1/fazendas/:fazendaId/invernadas", invernadaRouter);
apiRouter.use("/v1/fazendas/:fazendaId/bovinos", bovinoRouter);
apiRouter.use("/v1/fazendas/:fazendaId/eventos-sanitarios", eventoSanitarioRouter);
apiRouter.use("/v1/fazendas/:fazendaId/movimentacoes", movimentacaoRouter);
apiRouter.use("/v1/fazendas/:fazendaId/atividades", atividadeRouter);
apiRouter.use("/v1/fazendas/:fazendaId/convites", conviteRouter);
apiRouter.use("/v1/fazendas/:fazendaId/membros", membroRouter);
apiRouter.use("/v1/fazendas/:fazendaId/uploads", uploadRouter);
