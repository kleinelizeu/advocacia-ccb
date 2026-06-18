#!/usr/bin/env bash
# instalar.sh — Wizard de instalação (gerado a partir do installer-kit-ccb).
# Transforma um Hermes já instalado em um agente de Instagram + Telegram.
# Uso:  bash instalar.sh            (roda o assistente do início / continua de onde parou)
#       bash instalar.sh doctor     (só o diagnóstico)
#       bash instalar.sh info        (reimprime URL do webhook, secret e nome do bot)
#       bash instalar.sh contexto    (reimprime o contexto do negócio p/ colar no bot)
set -euo pipefail

# Resolve symlinks (o comando do produto costuma ser um symlink em /usr/local/bin).
BASE_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Manifesto de identidade do produto (PRODUTO, CLI_NAME, PERFIL_PADRAO, TRACK, ...).
# shellcheck source=/dev/null
source "$BASE_DIR/produto.conf"

# Motor (installer-kit-ccb): 00-core, 01-deteccao, ... 90-checks (e 95-checks-extra em squads).
for f in "$BASE_DIR"/lib/*.sh; do source "$f"; done

# ── Subcomandos rápidos ───────────────────────────────────────────────────────
init_estado
carregar_estado
case "${1:-}" in
  doctor)   mostrar_banner; rodar_doctor; exit $? ;;
  info)     mostrar_banner; cartao_visita_completo; exit 0 ;;
  contexto) imprimir_contexto_para_colar; exit 0 ;;
esac

# ── Fluxo principal ───────────────────────────────────────────────────────────
mostrar_banner

cat <<'INTRO'
  Bem-vindo! Em poucos minutos você vai ter um agente que cuida do seu
  Instagram sozinho: cria posts com imagem e responde comentários e DMs,
  te avisando no Telegram. Vou te guiar passo a passo — sem termos técnicos.

  Você vai precisar de:
   • O Telegram instalado no celular
   • Uma conta no Zernio (zernio.com) com seu Instagram conectado
   • Uns 10 minutos

INTRO
confirmar "Vamos começar?" s || { echo "Sem problema. É só rodar de novo quando quiser."; exit 0; }

# oferecer_retomada — quando há estado anterior, pergunta o que fazer.
oferecer_retomada() {
  [[ -s "$ESTADO_PASSOS" ]] || return 0
  titulo "Encontrei uma configuração anterior nesta VPS."
  info "1) Continuar de onde parei (recomendado)"
  info "2) Refazer tudo do zero"
  info "3) Só rodar o diagnóstico (doctor)"
  local op; MENU_MAX=3
  perguntar op "O que você prefere? (1, 2 ou 3)" valida_opcao_menu "Digite 1, 2 ou 3."
  case "$op" in
    2) : > "$ESTADO_PASSOS"; dica "Ok, vamos refazer do começo (suas respostas anteriores viram sugestões)." ;;
    3) rodar_doctor; exit $? ;;
    *) dica "Beleza, continuando de onde paramos." ;;
  esac
}

# Se já existe instalação anterior, oferece menu de re-execução.
oferecer_retomada

executar_passo precheck      "Verificação do servidor"        passo_precheck
executar_passo credenciais   "Coleta das suas credenciais"    passo_credenciais
executar_passo negocio        "Configuração do seu negócio"    passo_negocio
executar_passo perfil         "Criação do agente (perfil)"     passo_perfil
executar_passo mcp            "Conexão com o Zernio (MCP)"     passo_mcp
# Agenda (Google Calendar) — só nos produtos com AGENDA="google" (o agente marca sozinho).
if [[ -n "${AGENDA:-}" ]]; then
  executar_passo agenda       "Conexão com a agenda (Google Calendar)" passo_agenda
fi
executar_passo webhook        "Configuração das respostas automáticas" passo_webhook
executar_passo exposicao      "Abertura segura para a internet" passo_exposicao
executar_passo painel_zernio  "Instruções do painel do Zernio" passo_painel_zernio

# Passo extra do esquadrão (só nos produtos squad; passo_squad vem de lib/80-*.sh).
if [[ "${TRACK:-solo}" == "squad" ]]; then
  executar_passo squad "Configuração do esquadrão (${SQUAD_FRAMEWORK:-})" passo_squad
fi

titulo "Verificação final"
rodar_doctor || true

passo_primeiros_passos
