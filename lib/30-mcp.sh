#!/usr/bin/env bash
# 30-mcp.sh — Conecta o agente ao Zernio via MCP.
# Tenta pela CLI; se não der, entrega uma mensagem pronta para o aluno colar no bot.

MCP_URL="https://mcp.zernio.com/mcp"

passo_mcp() {
  passo "CONECTANDO AO ZERNIO"

  if _mcp_ja_registrado; then
    ok "O Zernio já está conectado ao seu agente."
    return 0
  fi

  # Tentativa automática (best-effort). O 'mcp add' do Hermes é "discovery-first"
  # e pode pedir confirmação; alimentamos 'yes' e, se não registrar, caímos no
  # caminho manual (comprovado) sem travar.
  # NOTA (validado na VPS, Hermes 0.15.1): para o Zernio (MCP remoto com Bearer via
  # mcp-remote), o 'mcp add' por CLI NÃO funciona de forma confiável — o '-y' e o
  # '--header' quebram o argparse, e a forma --url/--auth também não registrou.
  # O caminho COMPROVADO (igual ao case original) é o fallback manual abaixo: o aluno
  # cola a mensagem no bot e o próprio agente configura o MCP. Mantemos a tentativa
  # automática mesmo assim (custa pouco) e caímos no manual sem travar.
  if hermes_cli mcp --help 2>/dev/null | grep -q ' add'; then
    info "Tentando conectar o Zernio automaticamente..."
    # --args precisa ser a ÚLTIMA opção; o header vai como um único argumento.
    yes 2>/dev/null | hermes_cli mcp add zernio --command npx \
         --args -y mcp-remote@latest "$MCP_URL" --header "Authorization: Bearer $ZERNIO_API_KEY" >/dev/null 2>&1 || true
    if _mcp_ja_registrado; then
      _reiniciar_gateway
      ok "Zernio conectado!"
      return 0
    fi
    dica "A conexão automática não confirmou — vamos pelo jeito manual (é rápido)."
  fi

  _mcp_manual
}

_mcp_ja_registrado() {
  hermes_cli mcp list 2>/dev/null | grep -qi zernio
}

_mcp_manual() {
  local msg
  msg="$(sed "s|__API_KEY__|$ZERNIO_API_KEY|" "$BASE_DIR/modelos/mensagem-mcp-telegram.txt")"
  titulo "Conecte o Zernio pelo Telegram (1 minuto):"
  info "1. Abra a conversa com o seu bot @${BOT_USERNAME:-seu_bot}"
  info "2. Copie e mande a mensagem abaixo (ela já contém a sua chave):"
  copiavel "$msg"
  info "3. Espere o agente responder confirmando as ferramentas do Zernio."
  confirmar "Já mandou e o agente confirmou a conexão?" s || \
    dica "Tudo bem, você pode conferir depois com '${CLI_NAME} doctor'."
}

_reiniciar_gateway() {
  if [[ "${MODO:-}" == "docker" ]]; then
    ( cd "$COMPOSE_DIR" && docker compose restart >/dev/null 2>&1 ) || true
  else
    systemctl restart "$GATEWAY_SVC" 2>/dev/null || true
  fi
  sleep 5
}
