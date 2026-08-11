"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { Nfc, AlertCircle, Beef, Radio } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { bovinosApi } from "@/lib/api/bovinos";
import { buscarTodasPaginas } from "@/lib/api/pagination";
import { PageHeader } from "@/components/ui/PageHeader";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";

// Web NFC ainda é experimental e não faz parte do lib.dom.d.ts padrão do
// TypeScript — declaração mínima só do que usamos aqui.
interface NDEFReadingEvent extends Event {
  serialNumber: string;
}
interface NDEFReaderLike extends EventTarget {
  scan(): Promise<void>;
  onreading: ((event: NDEFReadingEvent) => void) | null;
  onreadingerror: ((event: Event) => void) | null;
}

interface Leitura {
  id: string;
  serialNumber: string;
  horario: string;
  bovino: { id: string; numeroBrinco: string; nomeAnimal?: string | null } | null;
}

export default function RfidPage() {
  const { fazendaId } = useAuth();
  const [suportado, setSuportado] = useState<boolean | null>(null);
  const [lendo, setLendo] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [leituras, setLeituras] = useState<Leitura[]>([]);
  const readerRef = useRef<NDEFReaderLike | null>(null);
  // Cache dos bovinos da fazenda pra resolver o codigoEpc de cada leitura
  // sem bater na API a cada tag lida (não há filtro por codigoEpc na API).
  const bovinosRef = useRef<{ id: string; numeroBrinco: string; nomeAnimal: string | null; codigoEpc: string | null }[]>([]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setSuportado(typeof window !== "undefined" && "NDEFReader" in window);
  }, []);

  useEffect(() => {
    if (!fazendaId) return;
    buscarTodasPaginas((page) => bovinosApi.listar(fazendaId, { page, pageSize: 100 })).then(
      (todosBovinos) => {
        bovinosRef.current = todosBovinos.map((b) => ({
          id: b.id,
          numeroBrinco: b.numeroBrinco,
          nomeAnimal: b.nomeAnimal,
          codigoEpc: b.codigoEpc,
        }));
      }
    );
  }, [fazendaId]);

  async function iniciarLeitura() {
    if (!fazendaId) return;
    setErro(null);
    try {
      const NDEFReaderCtor = (
        window as unknown as { NDEFReader: new () => NDEFReaderLike }
      ).NDEFReader;
      const reader = new NDEFReaderCtor();
      readerRef.current = reader;
      await reader.scan();
      setLendo(true);
      reader.onreading = async (event: NDEFReadingEvent) => {
        const serial = event.serialNumber || "desconhecido";
        const encontrado = bovinosRef.current.find((b) => b.codigoEpc === serial);
        setLeituras((prev) => [
          {
            id: `${serial}-${Date.now()}`,
            serialNumber: serial,
            horario: new Date().toLocaleTimeString("pt-BR"),
            bovino: encontrado
              ? { id: encontrado.id, numeroBrinco: encontrado.numeroBrinco, nomeAnimal: encontrado.nomeAnimal }
              : null,
          },
          ...prev,
        ]);
      };
      reader.onreadingerror = () => {
        setErro("Não foi possível ler a tag. Aproxime o celular novamente.");
      };
    } catch (err) {
      setLendo(false);
      if (err instanceof Error && err.name === "NotAllowedError") {
        setErro("Permissão de NFC negada. Habilite o NFC e autorize o acesso.");
      } else {
        setErro("Não foi possível iniciar a leitura NFC.");
      }
    }
  }

  function pararLeitura() {
    setLendo(false);
    readerRef.current = null;
  }

  return (
    <div className="max-w-lg">
      <PageHeader
        title="Leitura RFID"
        subtitle="Aproxime o celular de uma tag NFC/RFID para identificar o animal"
      />

      {suportado === false && (
        <Card className="p-6 mb-5">
          <div className="flex items-start gap-3">
            <AlertCircle size={18} className="text-warning shrink-0 mt-0.5" />
            <div>
              <p className="text-sm font-semibold text-text mb-1">
                Leitura NFC não disponível neste navegador
              </p>
              <p className="text-xs text-muted">
                A Web NFC API funciona apenas no Chrome para Android, em conexão HTTPS.
                Em outros navegadores ou dispositivos, use o app para leitura RFID.
              </p>
            </div>
          </div>
        </Card>
      )}

      {suportado && (
        <Card className="p-6 mb-5">
          {erro && (
            <div className="flex items-start gap-2 bg-danger-bg rounded-lg px-3.5 py-2.5 text-sm text-danger mb-4">
              <AlertCircle size={16} className="shrink-0 mt-0.5" />
              {erro}
            </div>
          )}
          {!lendo ? (
            <Button icon={<Nfc size={16} />} onClick={iniciarLeitura} className="w-full">
              Iniciar leitura
            </Button>
          ) : (
            <div className="flex flex-col items-center gap-4 py-4">
              <div className="w-16 h-16 rounded-full bg-g50 flex items-center justify-center text-g800 animate-pulse">
                <Radio size={28} />
              </div>
              <p className="text-sm text-muted">Aproxime uma tag NFC…</p>
              <Button variant="secondary" size="sm" onClick={pararLeitura}>
                Parar leitura
              </Button>
            </div>
          )}
        </Card>
      )}

      <Card className="overflow-hidden">
        {leituras.length === 0 ? (
          <EmptyState
            icon={<Beef size={20} />}
            title="Nenhuma leitura nesta sessão"
            description="As tags lidas aparecem aqui, com o animal correspondente se houver."
          />
        ) : (
          <div className="divide-y divide-border-soft">
            {leituras.map((l) => (
              <div key={l.id} className="flex items-center justify-between px-5 py-3.5">
                <div>
                  {l.bovino ? (
                    <Link
                      href={`/bovinos/${l.bovino.id}`}
                      className="text-sm font-semibold text-g800 hover:underline"
                    >
                      {l.bovino.numeroBrinco}
                      {l.bovino.nomeAnimal ? ` · ${l.bovino.nomeAnimal}` : ""}
                    </Link>
                  ) : (
                    <span className="text-sm text-muted">Nenhum bovino com este código</span>
                  )}
                  <div className="text-xs text-muted-2 font-mono">{l.serialNumber}</div>
                </div>
                <span className="text-xs text-muted-2">{l.horario}</span>
              </div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}
