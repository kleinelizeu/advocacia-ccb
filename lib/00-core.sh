#!/usr/bin/env bash
# 00-core.sh — Fundação do wizard (installer-kit-ccb).
# Banner, UI, perguntas, validadores, estado e idempotência.
# Carregado por instalar.sh e doctor.sh DEPOIS do produto.conf (não executa nada sozinho).
#
# Identidade do produto vem do produto.conf (sourçado antes deste arquivo):
#   PRODUTO, PRODUTO_NOME, CLI_NAME, PERFIL_PADRAO, NICHO, TRACK, SQUAD_FRAMEWORK, ...

# ── Identidade (fallbacks defensivos caso produto.conf falte) ──────────────────
PRODUTO="${PRODUTO:-hermes-ccb}"
PRODUTO_NOME="${PRODUTO_NOME:-Hermes by CCB}"
CLI_NAME="${CLI_NAME:-hermes-ccb}"
PERFIL_PADRAO="${PERFIL_PADRAO:-agente}"
TRACK="${TRACK:-solo}"

# ── Estado / diretórios ───────────────────────────────────────────────────────
ESTADO_DIR="${ESTADO_DIR:-/root/.${PRODUTO}}"
ESTADO_CONFIG="$ESTADO_DIR/config"
ESTADO_PASSOS="$ESTADO_DIR/passos"
ESTADO_CONTEXTO="$ESTADO_DIR/business-context.md"

# ── Nomes derivados (evitam colisão de dois produtos na mesma VPS) ─────────────
WEBHOOK_PORT="${WEBHOOK_PORT:-8644}"
TUNEL_UNIT="cloudflared-${CLI_NAME}"
TUNEL_LOG="/var/log/${TUNEL_UNIT}.log"

# Versão (lida do arquivo VERSION na raiz do repo, se existir)
WIZARD_VERSAO="$(cat "${BASE_DIR:-.}/VERSION" 2>/dev/null || echo "1.0.0")"

# ── Cores (desligam se não for terminal) ──────────────────────────────────────
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
  C_CIANO=$'\033[36m'; C_VERDE=$'\033[32m'
  C_VERM=$'\033[31m';  C_AMAR=$'\033[33m'; C_CINZA=$'\033[90m'
else
  C_RESET=''; C_BOLD=''; C_CIANO=''; C_VERDE=''; C_VERM=''; C_AMAR=''; C_CINZA=''
fi

# ── Saídas formatadas ─────────────────────────────────────────────────────────
titulo()  { printf '\n%s%s%s\n' "$C_CIANO$C_BOLD" "$*" "$C_RESET"; }
ok()      { printf '%s✔%s %s\n' "$C_VERDE" "$C_RESET" "$*"; }
erro()    { printf '%s✘%s %s\n' "$C_VERM" "$C_RESET" "$*" >&2; }
dica()    { printf '%s→%s %s\n' "$C_AMAR" "$C_RESET" "$*"; }
passo()   { printf '\n%s▸ %s%s\n' "$C_CIANO$C_BOLD" "$*" "$C_RESET"; }
info()    { printf '  %s\n' "$*"; }
nota()    { printf '%s  %s%s\n' "$C_CINZA" "$*" "$C_RESET"; }

# Caixa para destacar algo que o aluno precisa anotar/copiar.
caixa() {
  local linha
  printf '%s' "$C_AMAR"
  printf '  ┌%s┐\n' "$(printf '─%.0s' {1..64})"
  for linha in "$@"; do
    printf '  │ %-62.62s │\n' "$linha"
  done
  printf '  └%s┘\n' "$(printf '─%.0s' {1..64})"
  printf '%s' "$C_RESET"
}

# Valor para o aluno copiar: impresso sozinho, sem prefixo, fácil de selecionar.
copiavel() { printf '\n%s\n\n' "$*"; }

# Mascara um segredo: mostra começo e fim, oculta o meio.
mascarar() {
  local s="$1"
  local n=${#s}
  if (( n <= 10 )); then printf '%s' "********"; return; fi
  printf '%s…%s' "${s:0:6}" "${s: -4}"
}

# ── Banner ────────────────────────────────────────────────────────────────────
# Usa o arquivo banner.txt do produto (arte ASCII). Se não houver, mostra um
# quadro simples com o nome do produto. Nunca falha.
mostrar_banner() {
  printf '%s' "$C_CIANO$C_BOLD"
  local arte="${BASE_DIR:-.}/${BANNER_FILE:-banner.txt}"
  if [[ -f "$arte" ]]; then
    cat "$arte"
  else
    local titulo_txt="  ${PRODUTO_NOME}  "
    local borda; borda="$(printf '═%.0s' $(seq 1 ${#titulo_txt}))"
    printf '\n  ╔%s╗\n  ║%s║\n  ╚%s╝\n' "$borda" "$titulo_txt" "$borda"
  fi
  printf '%s' "$C_RESET"
  printf '%s            by CCB — Comunidade Claw Brasil%s   %sv%s%s\n\n' \
    "$C_BOLD" "$C_RESET" "$C_CINZA" "$WIZARD_VERSAO" "$C_RESET"
}

# ── Confirmação sim/não ───────────────────────────────────────────────────────
# confirmar "pergunta" [s|n default]  → retorna 0 (sim) ou 1 (não)
confirmar() {
  local pergunta="$1" padrao="${2:-s}" resp dica_resp
  [[ "$padrao" == "s" ]] && dica_resp="[S/n]" || dica_resp="[s/N]"
  while true; do
    printf '%s %s ' "$pergunta" "$dica_resp"
    read -r resp </dev/tty || resp=""
    resp="${resp:-$padrao}"
    case "${resp,,}" in
      s|sim|y|yes) return 0 ;;
      n|nao|não|no) return 1 ;;
      *) dica "Responda com 's' (sim) ou 'n' (não)." ;;
    esac
  done
}

# ── Pergunta com validação ────────────────────────────────────────────────────
# perguntar VAR "texto" [fn_validacao] ["dica de erro"] [--opcional] [--segredo]
# Reaproveita valor já salvo no estado oferecendo como default (Enter mantém).
perguntar() {
  local var="$1" texto="$2" valida="${3:-}" dica_erro="${4:-}"
  shift 4 2>/dev/null || shift $#
  local opcional="" segredo=""
  for flag in "$@"; do
    [[ "$flag" == "--opcional" ]] && opcional="1"
    [[ "$flag" == "--segredo" ]] && segredo="1"
  done

  local atual="${!var:-}"
  local entrada prompt_extra=""
  if [[ -n "$atual" ]]; then
    if [[ -n "$segredo" ]]; then
      prompt_extra=" ${C_CINZA}[Enter mantém: $(mascarar "$atual")]${C_RESET}"
    else
      prompt_extra=" ${C_CINZA}[Enter mantém: $atual]${C_RESET}"
    fi
  fi

  while true; do
    printf '%s%s\n> ' "$texto" "$prompt_extra"
    read -r entrada </dev/tty || entrada=""
    entrada="${entrada:-$atual}"

    if [[ -z "$entrada" ]]; then
      if [[ -n "$opcional" ]]; then printf -v "$var" '%s' ""; return 0; fi
      dica "Esse campo é obrigatório. Tenta de novo?"; continue
    fi

    if [[ -n "$valida" ]] && ! "$valida" "$entrada"; then
      [[ -n "$dica_erro" ]] && dica "$dica_erro"
      continue
    fi

    printf -v "$var" '%s' "$entrada"
    return 0
  done
}

# ── Validadores ───────────────────────────────────────────────────────────────
valida_token_telegram() { [[ "$1" =~ ^[0-9]{8,10}:[A-Za-z0-9_-]{35}$ ]]; }
valida_chat_id()        { [[ "$1" =~ ^-?[0-9]{5,15}$ ]]; }
valida_api_zernio()     { [[ "$1" =~ ^sk_[A-Za-z0-9_-]{10,}$ ]]; }
valida_instagram()      { [[ "$1" =~ ^@?[A-Za-z0-9._]{1,30}$ ]]; }
valida_nome_perfil()    { [[ "$1" =~ ^[a-z][a-z0-9]{1,15}$ ]]; }
valida_nao_vazio()      { [[ -n "${1// }" ]]; }
valida_opcao_menu()     { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= ${MENU_MAX:-9} )); }

# ── Persistência do estado ────────────────────────────────────────────────────
init_estado() {
  mkdir -p "$ESTADO_DIR"
  chmod 700 "$ESTADO_DIR"
  touch "$ESTADO_CONFIG" "$ESTADO_PASSOS"
  chmod 600 "$ESTADO_CONFIG" "$ESTADO_PASSOS"
}

carregar_estado() {
  [[ -f "$ESTADO_CONFIG" ]] && source "$ESTADO_CONFIG" || true
}

# salvar_var NOME "valor" — grava/atualiza no config (KEY=VALUE com aspas).
salvar_var() {
  local nome="$1" valor="$2"
  printf -v "$nome" '%s' "$valor"
  local tmp; tmp="$(mktemp)"
  [[ -f "$ESTADO_CONFIG" ]] && grep -v "^${nome}=" "$ESTADO_CONFIG" > "$tmp" 2>/dev/null || true
  printf '%s=%q\n' "$nome" "$valor" >> "$tmp"
  mv "$tmp" "$ESTADO_CONFIG"
  chmod 600 "$ESTADO_CONFIG"
}

# ── Markers de passos concluídos ──────────────────────────────────────────────
passo_concluido()  { grep -qxF "$1" "$ESTADO_PASSOS" 2>/dev/null; }
marcar_concluido() { passo_concluido "$1" || echo "$1" >> "$ESTADO_PASSOS"; }
desmarcar()        { local t; t="$(mktemp)"; grep -vxF "$1" "$ESTADO_PASSOS" > "$t" 2>/dev/null || true; mv "$t" "$ESTADO_PASSOS"; }

# executar_passo NOME "descrição" funcao
# Pula se já concluído; senão executa e marca em caso de sucesso.
executar_passo() {
  local nome="$1" desc="$2" fn="$3"
  if passo_concluido "$nome"; then
    ok "Já feito: $desc (pulando)"
    return 0
  fi
  if "$fn"; then
    marcar_concluido "$nome"
  else
    erro "Falhou em: $desc"
    dica "Você pode rodar de novo com '${CLI_NAME}' que ele continua daqui."
    exit 1
  fi
}

# ── Backup de arquivo antes de editar ─────────────────────────────────────────
backup_arquivo() {
  local f="$1" ts
  ts="$(date +%Y%m%d%H%M%S)"
  [[ -f "$f" ]] && cp "$f" "${f}.bak.${ts}" && nota "backup: ${f}.bak.${ts}"
}

# ── Abstração CLI do Hermes (Docker vs nativo) ────────────────────────────────
# Depende de MODO, CONTAINER (docker) ou PERFIL_BIN (nativo), definidos na detecção.
hermes_cli() {
  if [[ "${MODO:-}" == "docker" ]]; then
    docker exec "$CONTAINER" hermes "$@"
  else
    "${PERFIL_BIN:-hermes}" "$@"
  fi
}
