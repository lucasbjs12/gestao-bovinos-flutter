import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';

// Papéis do cenário: dono1 é dono da fazenda 'dono1' (fazendaId == uid),
// capataz1 é membro com papel capataz, intruso1 não é membro.
let env;

const FAZENDA = 'dono1';

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'gestaobovinos-rules-test',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () =>
  await env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  // Estado-base criado por fora das rules: capataz já é membro,
  // e existe um bovino para os testes de edição/exclusão.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `fazendas/${FAZENDA}/membros/capataz1`), {
      papel: 'capataz',
      nome: 'João',
    });
    await setDoc(doc(db, `fazendas/${FAZENDA}/bovinos/bov-1`), {
      numeroBrinco: 'B001',
      syncId: 'bov-1',
    });
    await setDoc(doc(db, `fazendas/${FAZENDA}/atividades/atv-1`), {
      autorUid: 'capataz1',
      descricao: 'Salvou o bovino B001',
    });
  });
});

const como = (uid) => env.authenticatedContext(uid).firestore();

describe('fazendas — papéis', () => {
  it('dono lê, cria e edita bovinos', async () => {
    const db = como('dono1');
    await assertSucceeds(getDoc(doc(db, `fazendas/${FAZENDA}/bovinos/bov-1`)));
    await assertSucceeds(setDoc(doc(db, `fazendas/${FAZENDA}/bovinos/bov-2`), { numeroBrinco: 'B002' }));
    await assertSucceeds(updateDoc(doc(db, `fazendas/${FAZENDA}/bovinos/bov-1`), { numeroBrinco: 'B001x' }));
  });

  it('dono exclui bovinos', async () => {
    await assertSucceeds(deleteDoc(doc(como('dono1'), `fazendas/${FAZENDA}/bovinos/bov-1`)));
  });

  it('capataz lê, cria e edita bovinos', async () => {
    const db = como('capataz1');
    await assertSucceeds(getDoc(doc(db, `fazendas/${FAZENDA}/bovinos/bov-1`)));
    await assertSucceeds(setDoc(doc(db, `fazendas/${FAZENDA}/bovinos/bov-3`), { numeroBrinco: 'B003' }));
    await assertSucceeds(updateDoc(doc(db, `fazendas/${FAZENDA}/bovinos/bov-1`), { numeroBrinco: 'B001y' }));
  });

  it('capataz NÃO exclui bovinos (ação de dono)', async () => {
    await assertFails(deleteDoc(doc(como('capataz1'), `fazendas/${FAZENDA}/bovinos/bov-1`)));
  });

  it('intruso não lê nem escreve nada da fazenda', async () => {
    const db = como('intruso1');
    await assertFails(getDoc(doc(db, `fazendas/${FAZENDA}/bovinos/bov-1`)));
    await assertFails(setDoc(doc(db, `fazendas/${FAZENDA}/bovinos/bov-x`), { numeroBrinco: 'X' }));
  });
});

describe('membros — escalação de privilégio', () => {
  it('capataz NÃO se promove a dono nem convida ninguém', async () => {
    const db = como('capataz1');
    await assertFails(updateDoc(doc(db, `fazendas/${FAZENDA}/membros/capataz1`), { papel: 'dono' }));
    await assertFails(setDoc(doc(db, `fazendas/${FAZENDA}/membros/amigo1`), { papel: 'capataz' }));
  });

  it('dono adiciona e remove membros com papel válido', async () => {
    const db = como('dono1');
    await assertSucceeds(setDoc(doc(db, `fazendas/${FAZENDA}/membros/novo1`), { papel: 'capataz' }));
    await assertSucceeds(deleteDoc(doc(db, `fazendas/${FAZENDA}/membros/capataz1`)));
  });

  it('dono NÃO cria membro com papel inventado', async () => {
    await assertFails(setDoc(doc(como('dono1'), `fazendas/${FAZENDA}/membros/novo2`), { papel: 'superadmin' }));
  });
});

describe('atividades — diário imutável', () => {
  it('capataz registra atividade em nome próprio', async () => {
    await assertSucceeds(setDoc(doc(como('capataz1'), `fazendas/${FAZENDA}/atividades/atv-2`), {
      autorUid: 'capataz1',
      descricao: 'Moveu o brinco B001',
    }));
  });

  it('capataz NÃO registra atividade em nome de outro', async () => {
    await assertFails(setDoc(doc(como('capataz1'), `fazendas/${FAZENDA}/atividades/atv-3`), {
      autorUid: 'dono1',
      descricao: 'Forjada',
    }));
  });

  it('ninguém edita uma atividade — nem o dono', async () => {
    await assertFails(updateDoc(doc(como('capataz1'), `fazendas/${FAZENDA}/atividades/atv-1`), { descricao: 'Adulterada' }));
    await assertFails(updateDoc(doc(como('dono1'), `fazendas/${FAZENDA}/atividades/atv-1`), { descricao: 'Adulterada' }));
  });

  it('dono exclui atividades (exclusão de conta / LGPD)', async () => {
    await assertSucceeds(deleteDoc(doc(como('dono1'), `fazendas/${FAZENDA}/atividades/atv-1`)));
  });
});

describe('convites — geração e ingresso', () => {
  const CODIGO = 'BOV-TESTE';
  const futuro = new Date(Date.now() + 48 * 3600 * 1000);
  const passado = new Date(Date.now() - 3600 * 1000);

  async function semRules(fn) {
    await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
  }

  it('dono cria convite para a própria fazenda', async () => {
    await assertSucceeds(setDoc(doc(como('dono1'), `convites/${CODIGO}`), {
      fazendaId: 'dono1', papel: 'capataz', usado: false,
      expiraEm: futuro,
    }));
  });

  it('ninguém cria convite para a fazenda de outro', async () => {
    await assertFails(setDoc(doc(como('intruso1'), `convites/OUTRO`), {
      fazendaId: 'dono1', papel: 'capataz', usado: false, expiraEm: futuro,
    }));
  });

  it('convidado entra com convite válido e vira capataz', async () => {
    await semRules((db) => setDoc(doc(db, `convites/${CODIGO}`), {
      fazendaId: 'dono1', papel: 'capataz', usado: false, expiraEm: futuro,
    }));
    // cria o próprio doc de membro apresentando o convite
    await assertSucceeds(setDoc(doc(como('novato1'), `fazendas/dono1/membros/novato1`), {
      papel: 'capataz', conviteCodigo: CODIGO, nome: 'Novato',
    }));
    // marca o convite como usado em nome próprio
    await assertSucceeds(updateDoc(doc(como('novato1'), `convites/${CODIGO}`), {
      usado: true, usadoPor: 'novato1',
    }));
  });

  it('convite expirado não deixa entrar', async () => {
    await semRules((db) => setDoc(doc(db, `convites/EXPIRADO`), {
      fazendaId: 'dono1', papel: 'capataz', usado: false, expiraEm: passado,
    }));
    await assertFails(setDoc(doc(como('novato2'), `fazendas/dono1/membros/novato2`), {
      papel: 'capataz', conviteCodigo: 'EXPIRADO',
    }));
  });

  it('convite já usado não deixa entrar', async () => {
    await semRules((db) => setDoc(doc(db, `convites/USADO`), {
      fazendaId: 'dono1', papel: 'capataz', usado: true, expiraEm: futuro,
    }));
    await assertFails(setDoc(doc(como('novato3'), `fazendas/dono1/membros/novato3`), {
      papel: 'capataz', conviteCodigo: 'USADO',
    }));
  });

  it('sem convite não dá para se autoinserir como membro', async () => {
    await assertFails(setDoc(doc(como('novato4'), `fazendas/dono1/membros/novato4`), {
      papel: 'capataz', conviteCodigo: 'NAO-EXISTE',
    }));
  });

  it('convite não permite entrar como dono', async () => {
    await semRules((db) => setDoc(doc(db, `convites/COMODONO`), {
      fazendaId: 'dono1', papel: 'capataz', usado: false, expiraEm: futuro,
    }));
    await assertFails(setDoc(doc(como('novato5'), `fazendas/dono1/membros/novato5`), {
      papel: 'dono', conviteCodigo: 'COMODONO',
    }));
  });
});

describe('usuarios — regressão da assinatura', () => {
  it('usuário cria o próprio doc apenas sem privilégios', async () => {
    const db = como('novo1');
    await assertSucceeds(setDoc(doc(db, 'usuarios/novo1'), {
      isAdmin: false, status: 'pendente', nome: 'Novo', email: 'n@n.com',
    }));
    await assertFails(setDoc(doc(como('novo2'), 'usuarios/novo2'), {
      isAdmin: true, status: 'ativo',
    }));
  });

  it('usuário comum não altera o próprio status', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'usuarios/novo1'), { isAdmin: false, status: 'pendente' });
    });
    await assertFails(updateDoc(doc(como('novo1'), 'usuarios/novo1'), { status: 'ativo' }));
  });
});
