#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "mcp>=1.2.0",
#   "google-api-python-client>=2.100",
#   "google-auth>=2.30",
# ]
# ///
"""MCP de Google Calendar dos instaladores CCB — dá ao agente o poder de AGENDAR sozinho.

Auth por SERVICE ACCOUNT, SEM domain-wide delegation: basta compartilhar a agenda do
negócio com o e-mail do service account (Configurações da agenda → Compartilhar →
"Fazer alterações em eventos"). Funciona com Gmail pessoal. Sem token que expira → o
agente agenda de forma autônoma, indefinidamente.

Variáveis de ambiente:
  GOOGLE_APPLICATION_CREDENTIALS = caminho do JSON do service account
  GOOGLE_CALENDAR_ID             = id da agenda (e-mail) onde criar/listar eventos

Roda self-contained (o uv instala as deps via PEP 723):
  uv run gcal_mcp.py
Ferramentas expostas: consultar_disponibilidade, listar_eventos, criar_evento.
"""
import os
from google.oauth2 import service_account
from googleapiclient.discovery import build
from mcp.server.fastmcp import FastMCP

SCOPES = ["https://www.googleapis.com/auth/calendar"]
CAL_PADRAO = os.environ.get("GOOGLE_CALENDAR_ID", "primary")

mcp = FastMCP("google-calendar-ccb")


def _servico():
    caminho = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "")
    if not caminho or not os.path.exists(caminho):
        raise RuntimeError(
            "GOOGLE_APPLICATION_CREDENTIALS não aponta para o JSON do service account."
        )
    creds = service_account.Credentials.from_service_account_file(caminho, scopes=SCOPES)
    return build("calendar", "v3", credentials=creds, cache_discovery=False)


@mcp.tool()
def consultar_disponibilidade(inicio_iso: str, fim_iso: str, calendario: str = "") -> str:
    """Mostra os intervalos OCUPADOS da agenda entre inicio_iso e fim_iso (RFC3339 com fuso,
    ex.: 2026-06-20T09:00:00-03:00). Use para achar um horário livre ANTES de marcar."""
    cal = calendario or CAL_PADRAO
    body = {"timeMin": inicio_iso, "timeMax": fim_iso, "items": [{"id": cal}]}
    fb = _servico().freebusy().query(body=body).execute()
    ocupados = fb.get("calendars", {}).get(cal, {}).get("busy", [])
    if not ocupados:
        return f"A agenda ({cal}) está LIVRE entre {inicio_iso} e {fim_iso}."
    linhas = [f"- ocupado: {b['start']} → {b['end']}" for b in ocupados]
    return "Horários OCUPADOS (o resto está livre):\n" + "\n".join(linhas)


@mcp.tool()
def listar_eventos(inicio_iso: str, fim_iso: str, calendario: str = "") -> str:
    """Lista os eventos já marcados na agenda no período (RFC3339)."""
    cal = calendario or CAL_PADRAO
    resp = _servico().events().list(
        calendarId=cal, timeMin=inicio_iso, timeMax=fim_iso,
        singleEvents=True, orderBy="startTime", maxResults=50,
    ).execute()
    itens = resp.get("items", [])
    if not itens:
        return "Nenhum evento no período."
    out = []
    for e in itens:
        ini = e.get("start", {}).get("dateTime", e.get("start", {}).get("date", "?"))
        out.append(f"- {ini}: {e.get('summary', '(sem título)')} [id {e.get('id')}]")
    return "\n".join(out)


@mcp.tool()
def criar_evento(titulo: str, inicio_iso: str, fim_iso: str, descricao: str = "",
                 fuso: str = "America/Sao_Paulo", calendario: str = "") -> str:
    """Cria (marca) um evento na agenda do negócio. inicio_iso/fim_iso em RFC3339
    (ex.: 2026-06-20T15:00:00-03:00). Retorna o link do evento criado.
    Confirme o horário com a pessoa ANTES de chamar esta ferramenta."""
    cal = calendario or CAL_PADRAO
    body = {
        "summary": titulo,
        "description": descricao,
        "start": {"dateTime": inicio_iso, "timeZone": fuso},
        "end": {"dateTime": fim_iso, "timeZone": fuso},
    }
    ev = _servico().events().insert(calendarId=cal, body=body).execute()
    return f"Evento criado com sucesso: {ev.get('htmlLink')} (id {ev.get('id')})"


if __name__ == "__main__":
    mcp.run()
