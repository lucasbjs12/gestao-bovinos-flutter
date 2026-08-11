/**
 * Migra os dados do Firestore (app Flutter, Firebase Auth + Firestore) para o
 * Postgres deste backend. Script pontual, roda fora do servidor Express.
 *
 * USO:
 *   npm run migrate:firestore              -- dry-run (nao grava nada, so relatorio)
 *   npm run migrate:firestore -- --commit   -- grava de verdade no Postgres
 *
 * PRE-REQUISITOS:
 *   - FIREBASE_SERVICE_ACCOUNT_PATH no .env apontando pra chave de service account
 *   - DATABASE_URL no .env apontando pro Postgres de destino (confirme que NAO
 *     e o banco de producao na primeira rodada -- rode contra um banco vazio
 *     de teste antes de rodar --commit contra o banco real)
 *
 * LIMITACOES CONHECIDAS (ver README/memoria do projeto):
 *   1. SENHA: Firebase Auth guarda senhas com o scrypt proprio do Google, nao
 *      exportavel como bcrypt. Usuarios migrados recebem um placeholder de
 *      senha IMPOSSIVEL de adivinhar (nao e a senha real) e precisam passar
 *      por um fluxo de "esqueci minha senha" -- que AINDA NAO EXISTE no
 *      backend. Nao rode --commit em producao sem esse fluxo pronto.
 *   2. Nem todo usuario tem doc em `usuarios/{uid}` no Firestore (o app
 *      historicamente nao criava esse doc para todo mundo -- ver campo
 *      garantirUsuario na memoria do projeto). O script cai pro Firebase Auth
 *      (admin.auth().getUser) quando o doc Firestore nao existe.
 *   3. RFID (`leituras_rfid`) fica de fora, por decisao explicita (nao
 *      sincronizado no schema novo).
 *   4. NUNCA RODADO CONTRA DADOS REAIS -- sem credenciais de Firebase neste
 *      ambiente, so foi possivel revisar a logica, nao testar em runtime.
 *      Rode --dry-run primeiro e confira o relatorio com atencao.
 */
import "dotenv/config";
import crypto from "node:crypto";
import fs from "node:fs";
import { randomUUID } from "node:crypto";
import bcrypt from "bcryptjs";
import { CategoriaBovino, Papel, PrismaClient, StatusAssinatura } from "@prisma/client";
import { inicializarFirebaseAdmin } from "./migracao/firebase";
import {
  converterData,
  converterTimestamp,
  ehUuidValido,
  normalizarCategoria,
  normalizarMotivoBaixa,
  normalizarTipoEvento,
} from "./migracao/mapeadores";

const COMMIT = process.argv.includes("--commit");

const prisma = new PrismaClient();
const relatorio = {
  usuarios: 0,
  usuariosSemDocFirestore: 0,
  fazendas: 0,
  membros: 0,
  invernadas: 0,
  bovinos: 0,
  baixas: 0,
  eventosSanitarios: 0,
  movimentacoes: 0,
  atividades: 0,
  convites: 0,
  avisos: [] as string[],
};

function avisar(mensagem: string) {
  relatorio.avisos.push(mensagem);
  console.warn(`  ! ${mensagem}`);
}

/** Senha impossivel de adivinhar -- forca o usuario a redefinir senha depois. */
function gerarSenhaPlaceholder(): Promise<string> {
  return bcrypt.hash(crypto.randomBytes(32).toString("hex"), 12);
}

async function main() {
  console.log(`Modo: ${COMMIT ? "COMMIT (grava no Postgres)" : "DRY-RUN (so relatorio)"}`);
  const db = inicializarFirebaseAdmin();
  const auth = (await import("firebase-admin")).default.auth();

  // ---- 1. usuarios ----------------------------------------------------
  const usuarioIdPorUid = new Map<string, string>(); // firebaseUid -> novo uuid Postgres
  const usuariosParaCriar: {
    id: string;
    nome: string;
    email: string;
    senhaHash: string;
    isAdmin: boolean;
    statusAssinatura: StatusAssinatura;
  }[] = [];

  async function garantirUsuarioMigrado(uid: string, nomeFallback?: string): Promise<string> {
    const existente = usuarioIdPorUid.get(uid);
    if (existente) return existente;

    const novoId = randomUUID();
    const senhaHash = await gerarSenhaPlaceholder();

    const doc = await db.collection("usuarios").doc(uid).get();
    if (doc.exists) {
      const dados = doc.data()!;
      usuariosParaCriar.push({
        id: novoId,
        nome: dados.nome ?? nomeFallback ?? "Usuario sem nome",
        email: dados.email ?? `${uid}@migrado.invalido`,
        senhaHash,
        isAdmin: Boolean(dados.isAdmin),
        statusAssinatura: mapStatusAssinatura(dados.status),
      });
    } else {
      relatorio.usuariosSemDocFirestore += 1;
      // Fallback: Firebase Auth tem o registro mesmo sem doc no Firestore
      // (ver nota na memoria do projeto -- garantirUsuario nunca era chamado).
      try {
        const registroAuth = await auth.getUser(uid);
        usuariosParaCriar.push({
          id: novoId,
          nome: registroAuth.displayName ?? nomeFallback ?? "Usuario sem nome",
          email: registroAuth.email ?? `${uid}@migrado.invalido`,
          senhaHash,
          isAdmin: false,
          statusAssinatura: StatusAssinatura.ativo,
        });
        avisar(`Usuario ${uid} nao tinha doc em usuarios/, recuperado via Firebase Auth`);
      } catch {
        usuariosParaCriar.push({
          id: novoId,
          nome: nomeFallback ?? "Usuario desconhecido",
          email: `${uid}@migrado.invalido`,
          senhaHash,
          isAdmin: false,
          statusAssinatura: StatusAssinatura.ativo,
        });
        avisar(`Usuario ${uid} nao encontrado nem no Firestore nem no Firebase Auth (conta deletada?)`);
      }
    }

    usuarioIdPorUid.set(uid, novoId);
    relatorio.usuarios += 1;
    return novoId;
  }

  function mapStatusAssinatura(valor: unknown): StatusAssinatura {
    const texto = String(valor ?? "").trim();
    if (texto === "ativo" || texto === "bloqueado" || texto === "vencido" || texto === "pendente") {
      return texto as StatusAssinatura;
    }
    return StatusAssinatura.ativo;
  }

  // ---- 2. descobrir fazendas via collectionGroup('membros') -----------
  // fazendaId == uid do dono; usar o parent do parent pra achar o id, em vez
  // de assumir que `fazendas` e uma collection top-level listavel de verdade.
  console.log("Descobrindo fazendas (collectionGroup membros)...");
  const membrosSnapshot = await db.collectionGroup("membros").get();
  const fazendaIds = new Set<string>();
  for (const doc of membrosSnapshot.docs) {
    const fazendaId = doc.ref.parent.parent?.id;
    if (fazendaId) fazendaIds.add(fazendaId);
  }
  console.log(`${fazendaIds.size} fazenda(s) encontradas.`);

  interface DadosFazenda {
    id: string;
    donoId: string;
    nome: string;
    membros: { usuarioId: string; papel: Papel; nome?: string; desde?: Date }[];
    invernadas: { id: string; descricao: string; hectares?: number; urlFoto?: string; observacoes?: string }[];
    invernadaIdPorSyncId: Map<string, string>;
    bovinos: {
      id: string;
      nomeAnimal?: string;
      codigoEpc?: string;
      codigoInterno?: string;
      numeroBrinco: string;
      raca?: string;
      dataNascimento?: Date;
      pesoAtualKg?: number;
      pelagem?: string;
      categoria: CategoriaBovino;
      status: string;
      origem?: string;
      observacoes?: string;
      foto?: string;
      invernadaId?: string;
      idMae?: string;
      estaDeCria: boolean;
    }[];
    bovinoIdPorSyncId: Map<string, string>;
    bovinoIdPorLocalId: Map<number, string>;
    atividades: { autorId: string; autorNome?: string; acao: string; descricao: string; criadoEm: Date }[];
  }

  const fazendas: DadosFazenda[] = [];

  for (const fazendaId of fazendaIds) {
    console.log(`\n== Fazenda ${fazendaId} ==`);
    const donoId = await garantirUsuarioMigrado(fazendaId);

    const fazendaDoc = await db.collection("fazendas").doc(fazendaId).get();
    const nomeFazenda = fazendaDoc.exists ? fazendaDoc.data()?.nome : undefined;

    const dadosFazenda: DadosFazenda = {
      id: randomUUID(),
      donoId,
      nome: nomeFazenda ?? `Fazenda migrada ${fazendaId.slice(0, 6)}`,
      membros: [{ usuarioId: donoId, papel: Papel.dono }],
      invernadas: [],
      invernadaIdPorSyncId: new Map(),
      bovinos: [],
      bovinoIdPorSyncId: new Map(),
      bovinoIdPorLocalId: new Map(),
      atividades: [],
    };

    // membros (convidados; o dono ja foi adicionado acima)
    const membrosDaFazenda = await db.collection("fazendas").doc(fazendaId).collection("membros").get();
    for (const doc of membrosDaFazenda.docs) {
      const uid = doc.id;
      if (uid === fazendaId) continue; // dono ja tratado
      const dados = doc.data();
      const usuarioId = await garantirUsuarioMigrado(uid, dados.nome);
      dadosFazenda.membros.push({
        usuarioId,
        papel: dados.papel === "dono" ? Papel.dono : Papel.convidado,
        nome: dados.nome,
        desde: converterTimestamp(dados.desde),
      });
      relatorio.membros += 1;
    }

    // invernadas
    const invernadasSnap = await db.collection("fazendas").doc(fazendaId).collection("invernadas").get();
    for (const doc of invernadasSnap.docs) {
      const dados = doc.data();
      const syncId = ehUuidValido(dados.syncId) ? dados.syncId : doc.id;
      const novoId = ehUuidValido(syncId) ? syncId : randomUUID();
      dadosFazenda.invernadas.push({
        id: novoId,
        descricao: dados.descricao ?? "Invernada sem descricao",
        hectares: typeof dados.hectares === "number" ? dados.hectares : undefined,
        urlFoto: dados.urlFoto,
        observacoes: dados.observacoes,
      });
      dadosFazenda.invernadaIdPorSyncId.set(doc.id, novoId);
      if (typeof dados.syncId === "string") dadosFazenda.invernadaIdPorSyncId.set(dados.syncId, novoId);
      relatorio.invernadas += 1;
    }

    // bovinos
    const bovinosSnap = await db.collection("fazendas").doc(fazendaId).collection("bovinos").get();
    for (const doc of bovinosSnap.docs) {
      const dados = doc.data();
      const syncId = ehUuidValido(dados.syncId) ? dados.syncId : doc.id;
      const novoId = ehUuidValido(syncId) ? syncId : randomUUID();
      const invernadaId = dados.invernadaSyncId
        ? dadosFazenda.invernadaIdPorSyncId.get(dados.invernadaSyncId)
        : undefined;

      dadosFazenda.bovinos.push({
        id: novoId,
        nomeAnimal: dados.nomeAnimal,
        codigoEpc: dados.codigoEpc,
        codigoInterno: dados.codigoInterno,
        numeroBrinco: dados.numeroBrinco ?? "SEM-BRINCO",
        raca: dados.raca,
        dataNascimento: converterData(dados.dataNascimentoMillis, dados.dataNascimento),
        pesoAtualKg: typeof dados.pesoAtualKg === "number" ? dados.pesoAtualKg : undefined,
        pelagem: dados.pelagem,
        categoria: normalizarCategoria(dados.categoria),
        status: dados.status ?? "Ativo",
        origem: dados.origem,
        observacoes: dados.observacoes,
        foto: dados.foto,
        invernadaId,
        // idMae resolvido numa segunda passada, depois que todo bovino tiver id novo
        idMae: undefined,
        estaDeCria: Boolean(dados.estaDeCria),
      });
      dadosFazenda.bovinoIdPorSyncId.set(doc.id, novoId);
      if (typeof dados.syncId === "string") dadosFazenda.bovinoIdPorSyncId.set(dados.syncId, novoId);
      if (typeof dados.id === "number") dadosFazenda.bovinoIdPorLocalId.set(dados.id, novoId);
      relatorio.bovinos += 1;
    }
    // segunda passada: resolver idMae (maeSyncId) agora que o mapa esta completo
    for (const [index, doc] of bovinosSnap.docs.entries()) {
      const dados = doc.data();
      if (dados.maeSyncId) {
        dadosFazenda.bovinos[index]!.idMae = dadosFazenda.bovinoIdPorSyncId.get(dados.maeSyncId);
      }
    }

    // atividades (diario imutavel)
    const atividadesSnap = await db.collection("fazendas").doc(fazendaId).collection("atividades").get();
    for (const doc of atividadesSnap.docs) {
      const dados = doc.data();
      if (!dados.autorUid) {
        avisar(`Atividade ${doc.id}: sem autorUid, pulando`);
        continue;
      }
      const autorId = await garantirUsuarioMigrado(dados.autorUid, dados.autorNome);
      dadosFazenda.atividades.push({
        autorId,
        autorNome: dados.autorNome,
        acao: dados.acao ?? "desconhecida",
        descricao: dados.descricao ?? "",
        criadoEm: converterData(dados.dataMillis, undefined) ?? new Date(),
      });
      relatorio.atividades += 1;
    }

    fazendas.push(dadosFazenda);
    relatorio.fazendas += 1;
  }

  // ---- 3. gravar usuarios + fazendas + membros + invernadas + bovinos --
  if (COMMIT) {
    console.log("\nGravando usuarios...");
    for (const usuario of usuariosParaCriar) {
      await prisma.usuario.upsert({
        where: { email: usuario.email },
        update: {},
        create: usuario,
      });
    }

    for (const fazenda of fazendas) {
      console.log(`Gravando fazenda ${fazenda.nome}...`);
      await prisma.fazenda.create({
        data: { id: fazenda.id, donoId: fazenda.donoId, nome: fazenda.nome },
      });
      for (const membro of fazenda.membros) {
        await prisma.membro.create({
          data: { fazendaId: fazenda.id, usuarioId: membro.usuarioId, papel: membro.papel, nome: membro.nome },
        });
      }
      for (const invernada of fazenda.invernadas) {
        await prisma.invernada.create({ data: { ...invernada, fazendaId: fazenda.id } });
      }
      for (const bovino of fazenda.bovinos) {
        await prisma.bovino.create({ data: { ...bovino, fazendaId: fazenda.id } });
      }
      for (const atividade of fazenda.atividades) {
        await prisma.atividade.create({ data: { ...atividade, fazendaId: fazenda.id } });
      }
    }
  }

  // ---- 4. baixas, eventos sanitarios, movimentacoes ---------------------
  await migrarDependentes(db, fazendas, relatorio, COMMIT ? prisma : null);

  // ---- 5. convites (top-level) ------------------------------------------
  console.log("\nMigrando convites...");
  const fazendaIdPorDono = new Map(fazendas.map((f) => [f.donoId, f.id]));
  const convitesSnap = await db.collection("convites").get();
  for (const doc of convitesSnap.docs) {
    const dados = doc.data();
    const donoUid = dados.fazendaId as string | undefined;
    const donoNovoId = donoUid ? usuarioIdPorUid.get(donoUid) : undefined;
    const fazendaNovoId = donoNovoId ? fazendaIdPorDono.get(donoNovoId) : undefined;
    if (!fazendaNovoId) {
      avisar(`Convite ${doc.id}: fazenda ${donoUid} nao migrada, pulando`);
      continue;
    }
    const expiraEm = converterTimestamp(dados.expiraEm) ?? new Date();
    const criadoPorId = dados.criadoPorUid ? usuarioIdPorUid.get(dados.criadoPorUid) : undefined;
    const usadoPorId = dados.usadoPor ? usuarioIdPorUid.get(dados.usadoPor) : undefined;

    if (COMMIT) {
      await prisma!.convite.upsert({
        where: { codigo: doc.id },
        update: {},
        create: {
          codigo: doc.id,
          fazendaId: fazendaNovoId,
          papel: Papel.convidado,
          criadoPorId,
          expiraEm,
          usado: Boolean(dados.usado),
          usadoPorId,
        },
      });
    }
    relatorio.convites += 1;
  }

  console.log("\n===== RELATORIO =====");
  console.log(JSON.stringify(relatorio, null, 2));
  fs.writeFileSync(
    `relatorio-migracao-${Date.now()}.json`,
    JSON.stringify(relatorio, null, 2),
  );

  if (!COMMIT) {
    console.log("\nDRY-RUN concluido. Nada foi gravado. Revise o relatorio e rode com --commit quando estiver ok.");
  }

  await prisma.$disconnect();
}

/**
 * baixas_bovinos, eventos_sanitarios (+M2M) e movimentacoes referenciam
 * bovinos/invernadas por syncId (ou id local, no caso de baixas e
 * movimentacoes antigas) -- por isso rodam depois que os mapas de id de cada
 * fazenda ja estao completos.
 */
async function migrarDependentes(
  db: FirebaseFirestore.Firestore,
  fazendas: Array<{
    id: string;
    invernadaIdPorSyncId: Map<string, string>;
    bovinoIdPorSyncId: Map<string, string>;
    bovinoIdPorLocalId: Map<number, string>;
  }>,
  relatorio: {
    baixas: number;
    eventosSanitarios: number;
    movimentacoes: number;
    atividades: number;
    avisos: string[];
  },
  prisma: PrismaClient | null,
) {
  // OBS: o loop acima ja tem o id original da fazenda perdido (so guardamos o
  // novo uuid); refazemos a lista de fazendaId originais aqui separadamente
  // via collectionGroup pra nao precisar redesenhar a estrutura de dados.
  const invernadasSnap = await db.collectionGroup("invernadas").get();
  const fazendaIdOriginalPorNovoId = new Map<string, string>();
  for (const doc of invernadasSnap.docs) {
    const fazendaIdOriginal = doc.ref.parent.parent?.id;
    if (!fazendaIdOriginal) continue;
    // acha a fazenda (novo id) dona dessa invernada comparando o mapa de sync ids
    for (const fazenda of fazendas) {
      if (fazenda.invernadaIdPorSyncId.has(doc.id)) {
        fazendaIdOriginalPorNovoId.set(fazenda.id, fazendaIdOriginal);
      }
    }
  }

  for (const fazenda of fazendas) {
    const fazendaIdOriginal = fazendaIdOriginalPorNovoId.get(fazenda.id);
    if (!fazendaIdOriginal) continue; // fazenda sem nenhuma invernada -- nada a resolver aqui
    const ref = db.collection("fazendas").doc(fazendaIdOriginal);

    // baixas
    const baixasSnap = await ref.collection("baixas_bovinos").get();
    for (const doc of baixasSnap.docs) {
      const dados = doc.data();
      const bovinoId =
        (typeof dados.bovinoId === "number" && fazenda.bovinoIdPorLocalId.get(dados.bovinoId)) ||
        (typeof dados.bovinoId === "string" && fazenda.bovinoIdPorSyncId.get(dados.bovinoId));
      if (!bovinoId) {
        relatorio.avisos.push(`Baixa ${doc.id}: bovino ${dados.bovinoId} nao encontrado, pulando`);
        continue;
      }
      const dataBaixa = converterData(dados.dataBaixaMillis, dados.dataBaixa) ?? new Date();
      if (prisma) {
        await prisma.baixaBovino.create({
          data: {
            bovinoId,
            motivo: normalizarMotivoBaixa(dados.motivo),
            observacoes: dados.observacoes,
            dataBaixa,
          },
        });
      }
      relatorio.baixas += 1;
    }

    // eventos sanitarios + M2M
    const eventosSnap = await ref.collection("eventos_sanitarios").get();
    for (const doc of eventosSnap.docs) {
      const dados = doc.data();
      const bovinoIds: string[] = (dados.bovinoSyncIds ?? [])
        .map((syncId: string) => fazenda.bovinoIdPorSyncId.get(syncId))
        .filter((v: string | undefined): v is string => Boolean(v));
      if (bovinoIds.length === 0) {
        relatorio.avisos.push(`Evento ${doc.id}: nenhum bovino resolvido, pulando`);
        continue;
      }
      const invernadaId = dados.invernadaSyncId
        ? fazenda.invernadaIdPorSyncId.get(dados.invernadaSyncId)
        : undefined;
      const dataEvento = converterData(dados.dataEventoMillis, dados.dataEvento);
      if (prisma) {
        await prisma.eventoSanitario.create({
          data: {
            fazendaId: fazenda.id,
            tipo: normalizarTipoEvento(dados.tipo),
            dataEvento,
            invernadaId,
            produtoUtilizado: dados.produtoUtilizado,
            dosagem: dados.dosagem,
            responsavel: dados.responsavel,
            observacoes: dados.observacoes,
            bovinos: { createMany: { data: bovinoIds.map((bovinoId) => ({ bovinoId })) } },
          },
        });
      }
      relatorio.eventosSanitarios += 1;
    }

    // movimentacoes (doc id era o id local, sem syncId proprio)
    const movSnap = await ref.collection("movimentacoes").get();
    for (const doc of movSnap.docs) {
      const dados = doc.data();
      const bovinoId = dados.bovinoSyncId ? fazenda.bovinoIdPorSyncId.get(dados.bovinoSyncId) : undefined;
      const novaInvernadaId = dados.novaInvernadaSyncId
        ? fazenda.invernadaIdPorSyncId.get(dados.novaInvernadaSyncId)
        : undefined;
      if (!bovinoId || !novaInvernadaId) {
        relatorio.avisos.push(`Movimentacao ${doc.id}: bovino ou invernada de destino nao resolvidos, pulando`);
        continue;
      }
      const invernadaAnteriorId = dados.invernadaAnteriorSyncId
        ? fazenda.invernadaIdPorSyncId.get(dados.invernadaAnteriorSyncId)
        : undefined;
      const data = converterData(dados.dataMillis, dados.data) ?? new Date();
      if (prisma) {
        await prisma.movimentacaoInvernada.create({
          data: {
            fazendaId: fazenda.id,
            bovinoId,
            data,
            invernadaAnteriorId,
            novaInvernadaId,
            responsavel: dados.responsavel,
            observacoes: dados.observacoes,
          },
        });
      }
      relatorio.movimentacoes += 1;
    }
  }
}

main().catch((err) => {
  console.error("Migracao falhou:", err);
  process.exitCode = 1;
});
