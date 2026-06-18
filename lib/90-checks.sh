#!/usr/bin/env bash
# 90-checks.sh — Diagnóstico (doctor) com auto-correção quando seguro.
# Compartilhado entre o wizard (verificação final) e o comando '<cli> doctor'.
#
# Squads adicionam checagens extras definindo a função checks_extra em
# lib/95-checks-extra.sh (vendorizada só nos produtos squad). Se a função não
# existir, o hook é um no-op.

DOC_FALHAS=0

_chk()  { printf '  %s✔%s %s\n' "$C_VERDE" "$C_RESET" "$*"; }
_fix()  { printf '  %s⚙%s %s\n' "$C_AMAR"  "$C_RESET" "$*"; }
_bad()  { printf '  %s✘%s %s\n' "$C_VERM"  "$C_RESET" "$*"; DOC_FALHAS=$((DOC_FALHAS+1)); }

rodar_doctor() {
  carregar_estado
  type _localizar_hermes >/dev/null 2>&1 && { _localizar_hermes 2>/dev/null || true; }
  titulo "DIAGNÓSTICO — conferindo se está tudo no lugar"
  DOC_FALHAS=0

  check_hermes
  if [[ -z "${MODO:-}" ]]; then
    echo
    dica "Ainda não configurei nada nesta VPS. Rode primeiro:  ${CLI_NAME}"
    return 0
  fi
  check_perfil
  check_gateway
  check_bot_telegram
  check_token_distinto
  check_config_webhook
  check_porta
  check_patch
  check_rota
  check_prompt_raw
  check_exposicao
  check_post_assinado
  check_mcp

  # Agenda (Google Calendar) — só quando AGENDA está ligada no produto.conf.
  if [[ -n "${AGENDA:-}" ]] && declare -F check_agenda >/dev/null 2>&1; then
    check_agenda
  fi

  # Hook de checagens extras (squads). No-op se não existir.
  if declare -F checks_extra >/dev/null 2>&1; then
    checks_extra
  fi

  echo
  if (( DOC_FALHAS == 0 )); then
    ok "Tudo certo! Seu agente está pronto."
  else
    dica "$DOC_FALHAS item(ns) precisam de atenção (veja os ✘ acima e docs/PROBLEMAS-COMUNS.md)."
  fi
  cartao_visita
  return 0
}

check_hermes() {
  if [[ "${MODO:-}" == "docker" ]]; then
    CONTAINER="$(docker ps --format '{{.Names}}' 2>/dev/null | grep -m1 hermes-agent || true)"
    [[ -n "$CONTAINER" ]] && _chk "Hermes (Docker) rodando: $CONTAINER" || _bad "Container do Hermes não está rodando."
  elif [[ "${MODO:-}" == "nativo" ]]; then
    if command -v hermes >/dev/null 2>&1 || [[ -d "${HERMES_LIB:-/dev/null}" ]]; then
      _chk "Hermes (nativo) instalado."
    else _bad "Não encontrei o Hermes nativo."; fi
  else
    _bad "Ambiente do Hermes não detectado (rode o assistente: ${CLI_NAME})."
  fi
}

check_perfil() {
  [[ "${MODO:-}" == "nativo" ]] || { _chk "Agente: container padrão."; return; }
  if [[ -d "${PERFIL_DIR:-/dev/null}" ]]; then _chk "Agente '${PERFIL:-$PERFIL_PADRAO}' existe."
  else _bad "Agente '${PERFIL:-$PERFIL_PADRAO}' não encontrado — rode '${CLI_NAME}' para criar."; fi
}

check_gateway() {
  [[ -n "${MODO:-}" ]] || { return; }
  if [[ "${MODO:-}" == "docker" ]]; then
    docker ps --format '{{.Names}} {{.Status}}' | grep -q "^${CONTAINER:-__x__}.*Up" \
      && _chk "Agente ligado." || { _fix "Religando o container..."; ( cd "${COMPOSE_DIR:-/tmp}" && docker compose up -d >/dev/null 2>&1 ) || _bad "Não consegui religar."; }
  else
    if systemctl is-active --quiet "${GATEWAY_SVC:-__x__}"; then _chk "Agente ligado (serviço ativo)."
    else _fix "Religando o agente..."; systemctl restart "${GATEWAY_SVC:-__x__}" 2>/dev/null && _chk "Religado." || _bad "Serviço do agente não sobe."; fi
  fi
}

check_bot_telegram() {
  [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]] || { _bad "Token do Telegram não configurado."; return; }
  if curl -s --max-time 10 "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" | grep -q '"ok":true'; then
    _chk "Bot do Telegram responde (@${BOT_USERNAME:-?})."
  else
    _bad "O bot do Telegram não respondeu (token pode ter sido revogado — rode '${CLI_NAME}')."
  fi
}

# Vazamento do --clone: token do perfil igual ao de outro perfil (ex.: default).
check_token_distinto() {
  [[ "${MODO:-}" == "nativo" ]] || return 0
  local outro="/root/.hermes/.env"
  [[ -f "$outro" && -f "${ENV_FILE:-/dev/null}" ]] || { _chk "Token do agente conferido."; return; }
  local t_outro
  t_outro="$(grep -oiE 'TELEGRAM[A-Z_]*TOKEN=.*' "$outro" 2>/dev/null | head -1 | cut -d= -f2-)"
  if [[ -n "$t_outro" && "$t_outro" == *"${TELEGRAM_BOT_TOKEN:-__nada__}"* ]]; then
    _bad "O token do Telegram parece ser o mesmo de outro agente (herança do clone). Rode '${CLI_NAME}' para corrigir."
  else
    _chk "Token do agente é exclusivo dele."
  fi
}

check_config_webhook() {
  [[ -f "${CONFIG_FILE:-/dev/null}" ]] || { _bad "config.yaml do agente não encontrado."; return; }
  if grep -qE '^[[:space:]]+webhook:' "$CONFIG_FILE"; then
    _chk "Plataforma de webhook habilitada."
  else
    _fix "Habilitando a plataforma de webhook..."; _habilitar_plataforma_webhook >/dev/null 2>&1 \
      && _chk "Habilitada." || _bad "Falhou ao habilitar o webhook."
  fi
}

check_porta() {
  local porta="${WEBHOOK_PORT:-8644}"
  if [[ "${MODO:-}" == "docker" ]]; then
    docker exec "$CONTAINER" curl -sf "http://localhost:${porta}/health" >/dev/null 2>&1 \
      && _chk "Webhook escutando na porta ${porta}." || _bad "Webhook não respondeu na porta ${porta}."
  else
    ss -tlnp 2>/dev/null | grep -q ":${porta}" && _chk "Webhook escutando na porta ${porta}." \
      || _bad "Nada escutando na porta ${porta} (o agente subiu?)."
  fi
}

check_patch() {
  local presente=""
  if [[ "${MODO:-}" == "docker" ]]; then
    docker exec "$CONTAINER" grep -q "X-Zernio-Signature" "${WEBHOOK_PY}" 2>/dev/null && presente=1
  else
    grep -q "X-Zernio-Signature" "${WEBHOOK_PY:-/dev/null}" 2>/dev/null && presente=1
  fi
  if [[ -n "$presente" ]]; then
    _chk "Reconhecimento da assinatura do Zernio presente."
  else
    _fix "Reaplicando o reconhecimento da assinatura..."
    _aplicar_patch_assinatura >/dev/null 2>&1
    if [[ "${MODO:-}" == "docker" ]]; then
      docker exec "$CONTAINER" grep -q "X-Zernio-Signature" "${WEBHOOK_PY}" 2>/dev/null && _chk "Reaplicado." || _bad "Não consegui reaplicar o patch."
    else
      grep -q "X-Zernio-Signature" "${WEBHOOK_PY}" 2>/dev/null && _chk "Reaplicado." || _bad "Não consegui reaplicar o patch."
    fi
  fi
}

check_rota() {
  if hermes_cli webhook list 2>/dev/null | grep -qi zernio; then
    _chk "Rota do webhook existe."
  else
    _fix "Recriando a rota do webhook..."; _criar_rota >/dev/null 2>&1
    hermes_cli webhook list 2>/dev/null | grep -qi zernio && _chk "Recriada." || _bad "Rota do webhook ausente."
  fi
}

# A rota precisa do {__raw__} no prompt e NÃO pode ter filtro de eventos.
check_prompt_raw() {
  local subs=""
  if [[ "${MODO:-}" == "nativo" ]]; then
    subs="${PERFIL_DIR}/webhook_subscriptions.json"
  else
    subs="$DATA_DIR/webhook_subscriptions.json"
  fi
  [[ -f "$subs" ]] || { _chk "Configuração da rota (sem verificação detalhada)."; return; }
  grep -q '{__raw__}' "$subs" 2>/dev/null && _chk "Rota envia os dados do evento ao agente ({__raw__})." \
    || _bad "A rota não contém {__raw__} — o agente não recebe os dados. Rode '${CLI_NAME}'."
  if grep -qE '"events"[[:space:]]*:[[:space:]]*\[[^]]+\]' "$subs" 2>/dev/null; then
    _bad "A rota tem filtro de eventos (deve ficar vazio). Veja docs/PROBLEMAS-COMUNS.md."
  fi
}

check_exposicao() {
  if [[ "${MODO:-}" == "docker" ]]; then
    [[ -n "${WEBHOOK_URL:-}" ]] && _chk "Endereço público: $WEBHOOK_URL" || _bad "Endereço público não definido."
    return
  fi
  if systemctl is-active --quiet "$TUNEL_UNIT"; then
    local url
    url="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNEL_LOG" 2>/dev/null | tail -1 || true)"
    if [[ -n "$url" ]]; then
      local nova="${url}/webhooks/zernio"
      if [[ "$nova" != "${WEBHOOK_URL:-}" ]]; then
        salvar_var WEBHOOK_URL "$nova"
        _fix "O endereço do túnel MUDOU."
        caixa "ATUALIZE no painel do Zernio (Webhooks):" "$nova"
      else
        _chk "Túnel ativo: $nova"
      fi
    else
      _bad "Túnel ativo mas sem endereço no log ainda."
    fi
  else
    _fix "Religando o túnel..."; systemctl restart "$TUNEL_UNIT" 2>/dev/null
    _bad "Túnel estava parado — religado. Rode o doctor de novo em 1 min para pegar o endereço."
  fi
}

# Teste de ponta: POST assinado com o secret salvo deve dar 202.
check_post_assinado() {
  [[ -n "${WEBHOOK_URL:-}" && -n "${WEBHOOK_SECRET:-}" ]] || { _chk "Teste de ponta a ponta pulado (sem endereço/secret)."; return; }
  local corpo='{"ping":true}' sig code
  sig="$(printf '%s' "$corpo" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" -hex 2>/dev/null | awk '{print $NF}')"
  code="$(curl -so /dev/null -w '%{http_code}' --max-time 15 -X POST "$WEBHOOK_URL" \
          -H 'Content-Type: application/json' -H "X-Zernio-Signature: $sig" -d "$corpo" 2>/dev/null || echo 000)"
  case "$code" in
    202|200) _chk "Teste de ponta a ponta OK (o webhook aceitou um evento de teste)." ;;
    401) _bad "Webhook rejeitou a assinatura (401). A chave aqui difere da do painel do Zernio. Use '${CLI_NAME} info' para ver a chave certa." ;;
    404) _bad "Endereço não encontrou a rota (404). Rode '${CLI_NAME}' para recriar a rota." ;;
    000) _bad "Não consegui acessar o endereço público (túnel/Traefik podem estar fora do ar)." ;;
    *)   _fix "Resposta inesperada do webhook (HTTP $code) — pode ser só demora; tente o doctor de novo." ;;
  esac
}

check_mcp() {
  if hermes_cli mcp list 2>/dev/null | grep -qi zernio; then
    _chk "Zernio conectado (MCP)."
  else
    _bad "Zernio não aparece conectado. Veja a mensagem para colar no bot com '${CLI_NAME}' (passo do Zernio)."
  fi
}

# ── Cartão de visita / subcomandos ────────────────────────────────────────────
cartao_visita() {
  titulo "Seu agente"
  info "Bot do Telegram : @${BOT_USERNAME:-?}"
  info "Endereço webhook: ${WEBHOOK_URL:-(ainda não definido)}"
  info "Chave do webhook: $(mascarar "${WEBHOOK_SECRET:-}")   (completa: ${CLI_NAME} info)"
  echo
  dica "Para testar as respostas automáticas, comente ou mande DM de OUTRA conta do Instagram —"
  dica "da sua própria conta o Zernio NÃO gera evento (não é bug)."
}

cartao_visita_completo() {
  cartao_visita
  echo
  titulo "Valores completos (guarde com cuidado)"
  info "Chave do webhook (Signing Secret): ${WEBHOOK_SECRET:-(nenhuma)}"
}

imprimir_contexto_para_colar() {
  if [[ -f "$ESTADO_CONTEXTO" ]]; then
    titulo "Cole isto no seu bot do Telegram e peça: 'Salve isso na sua memória como o contexto do meu negócio'"
    echo
    cat "$ESTADO_CONTEXTO"
  else
    erro "Ainda não há um contexto de negócio gerado. Rode '${CLI_NAME}' primeiro."
  fi
}
