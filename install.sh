#!/usr/bin/env bash
# install.sh — Bootstrap do "Hermes Advocacia by CCB".
# Uso (one-liner):
#   curl -fsSL https://raw.githubusercontent.com/kleinelizeu/advocacia-ccb/main/install.sh | sudo bash
#
# Clona/atualiza o repositório, cria o comando global 'hermes-advocacia' e abre o assistente.
# (Gerado a partir do installer-kit-ccb — não editar à mão; ajuste o produto.conf e rode kit-sync.)
set -euo pipefail

# ── Identidade (preenchida pelo kit-sync a partir do produto.conf) ────────────
PRODUTO="advocacia-ccb"
PRODUTO_NOME="Hermes Advocacia by CCB"
CLI_NAME="hermes-advocacia"
REPO_URL="${PRODUTO_REPO:-https://github.com/kleinelizeu/advocacia-ccb.git}"
DEST="${PRODUTO_DEST:-/opt/${PRODUTO}}"

c_ok()  { printf '\033[32m✔\033[0m %s\n' "$*"; }
c_err() { printf '\033[31m✘\033[0m %s\n' "$*" >&2; }
c_inf() { printf '→ %s\n' "$*"; }

if [[ "$(id -u)" -ne 0 ]]; then
  c_err "Rode como root:  curl -fsSL <url> | sudo bash"
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  c_inf "Instalando o git..."
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y >/dev/null 2>&1 && apt-get install -y git >/dev/null 2>&1
  fi
  command -v git >/dev/null 2>&1 || { c_err "Não consegui instalar o git. Instale-o e tente de novo."; exit 1; }
fi

if [[ -d "$DEST/.git" ]]; then
  c_inf "Atualizando o ${PRODUTO_NOME}..."
  git -C "$DEST" pull --ff-only >/dev/null 2>&1 || c_inf "(seguindo com a versão local)"
else
  c_inf "Baixando o ${PRODUTO_NOME}..."
  git clone --depth 1 "$REPO_URL" "$DEST" >/dev/null 2>&1 || { c_err "Falha ao baixar o repositório ($REPO_URL)."; exit 1; }
fi

chmod +x "$DEST/instalar.sh" "$DEST/doctor.sh" 2>/dev/null || true

# Comando global do produto
ln -sf "$DEST/instalar.sh" "/usr/local/bin/${CLI_NAME}"
c_ok "Comando '${CLI_NAME}' instalado."

# Precisa de terminal interativo para as perguntas. curl|bash não tem stdin.
if [[ -t 0 ]]; then
  exec bash "$DEST/instalar.sh"
elif [[ -e /dev/tty ]]; then
  exec bash "$DEST/instalar.sh" </dev/tty
else
  c_ok "Instalado! Agora rode o assistente com:"
  printf '\n    %s\n\n' "$CLI_NAME"
fi
