#!/usr/bin/env bash
# 40-webhook.sh — Liga o recebimento de comentários/DMs (webhook do Zernio).
# Concentra as correções do case:
#   #2 habilitar a plataforma no config.yaml (não só no .env)
#   #7 patch do header X-Zernio-Signature no webhook.py
#   #4 criar a rota SEM filtro de eventos
#   #5 prompt da rota contendo {__raw__}
#
# WEBHOOK_PORT e WEBHOOK_HOST vêm do 00-core/detecção (default 8644 / 127.0.0.1).

passo_webhook() {
  passo "LIGANDO AS RESPOSTAS AUTOMÁTICAS"

  # 1) Secret — gera só uma vez (mudar quebra o painel do Zernio).
  if [[ -z "${WEBHOOK_SECRET:-}" ]]; then
    WEBHOOK_SECRET="$(openssl rand -hex 32)"
    salvar_var WEBHOOK_SECRET "$WEBHOOK_SECRET"
    nota "Chave de segurança do webhook gerada."
  else
    nota "Reaproveitando a chave de segurança já existente."
  fi

  _habilitar_plataforma_webhook
  _aplicar_patch_assinatura
  _criar_rota
  ok "Respostas automáticas configuradas."
}

# Insere o bloco platforms.webhook no config.yaml (idempotente).
# Cria o arquivo se ele ainda não existir (no Hermes v0.16 o perfil pode não ter config.yaml).
_habilitar_plataforma_webhook() {
  local cfg="$CONFIG_FILE"
  if [[ -f "$cfg" ]] && grep -qE '^[[:space:]]+webhook:' "$cfg"; then
    ok "Plataforma de webhook já estava habilitada."
    return 0
  fi
  mkdir -p "$(dirname "$cfg")"
  [[ -f "$cfg" ]] && backup_arquivo "$cfg"
  WEBHOOK_HOST="${WEBHOOK_HOST:-127.0.0.1}" WEBHOOK_PORT="${WEBHOOK_PORT:-8644}" \
  WEBHOOK_SECRET="$WEBHOOK_SECRET" python3 - "$cfg" <<'PY'
import os, sys
path = sys.argv[1]
host = os.environ["WEBHOOK_HOST"]; port = os.environ["WEBHOOK_PORT"]; secret = os.environ["WEBHOOK_SECRET"]
bloco = (
    "  webhook:\n"
    "    enabled: true\n"
    "    extra:\n"
    f'      host: "{host}"\n'
    f"      port: {port}\n"
    f'      secret: "{secret}"\n'
)
try:
    src = open(path, encoding="utf-8").read()
except FileNotFoundError:
    src = ""
if not src.strip():
    src = "platforms:\n" + bloco
elif "\nplatforms:\n" in src:
    src = src.replace("\nplatforms:\n", "\nplatforms:\n" + bloco, 1)
elif src.startswith("platforms:\n"):
    src = src.replace("platforms:\n", "platforms:\n" + bloco, 1)
else:
    src = src.rstrip() + "\n\nplatforms:\n" + bloco
open(path, "w", encoding="utf-8").write(src)
PY
  if grep -qE '^[[:space:]]+webhook:' "$cfg"; then
    ok "Plataforma de webhook habilitada no agente."
  else
    erro "Não consegui habilitar o webhook no config.yaml."
    return 1
  fi
}

# Aplica o patch do X-Zernio-Signature. Persistente em ambos os modos.
_aplicar_patch_assinatura() {
  local patch_src="$BASE_DIR/modelos/apply_zernio_patch.py"
  if [[ "${MODO:-}" == "docker" ]]; then
    cp "$patch_src" "$DATA_DIR/apply_zernio_patch.py"
    _docker_entrypoint_wrapper
    ( cd "$COMPOSE_DIR" && docker compose up -d >/dev/null 2>&1 ) || true
    sleep 5
    docker exec "$CONTAINER" python3 /opt/data/apply_zernio_patch.py >/dev/null 2>&1 || true
    if docker exec "$CONTAINER" grep -q "X-Zernio-Signature" "$WEBHOOK_PY" 2>/dev/null; then
      ok "Reconhecimento da assinatura do Zernio aplicado (e persistente)."
    else
      dica "O patch de assinatura não confirmou agora — o doctor reaplica no fim."
    fi
  else
    # Nativo: roda direto no arquivo do host. Guarda cópia para o doctor reaplicar.
    cp "$patch_src" "$ESTADO_DIR/apply_zernio_patch.py"
    backup_arquivo "$WEBHOOK_PY"
    HERMES_WEBHOOK_PY="$WEBHOOK_PY" python3 "$patch_src" "$WEBHOOK_PY" >/dev/null 2>&1 || true
    if grep -q "X-Zernio-Signature" "$WEBHOOK_PY" 2>/dev/null; then
      ok "Reconhecimento da assinatura do Zernio aplicado."
      [[ -n "${GATEWAY_SVC:-}" ]] && systemctl restart "$GATEWAY_SVC" 2>/dev/null || true
    else
      dica "Não consegui aplicar o patch de assinatura automaticamente — o doctor tenta de novo."
    fi
  fi
}

# Adiciona entrypoint que reaplica o patch a cada start do container.
_docker_entrypoint_wrapper() {
  local cf="$COMPOSE_FILE"
  grep -q "apply_zernio_patch" "$cf" 2>/dev/null && return 0
  backup_arquivo "$cf"
  sed -i 's|    restart: unless-stopped|    restart: unless-stopped\n    entrypoint: ["/bin/sh", "-c", "python3 /opt/data/apply_zernio_patch.py 2>/dev/null; exec /entrypoint.sh"]|' "$cf"
}

# Cria a rota 'zernio' SEM --events e com prompt contendo {__raw__}.
_criar_rota() {
  local prompt
  prompt="$(cat "$BASE_DIR/modelos/prompt-rota-webhook.txt")"

  if hermes_cli webhook list 2>/dev/null | grep -qi zernio; then
    ok "Rota do webhook já existe."
    return 0
  fi

  if hermes_cli webhook subscribe zernio \
       --deliver telegram \
       --deliver-chat-id "$TELEGRAM_CHAT_ID" \
       --secret "$WEBHOOK_SECRET" \
       --prompt "$prompt" >/dev/null 2>&1; then
    ok "Rota do webhook criada."
  else
    dica "Não consegui criar a rota automaticamente (a CLI pode ter mudado)."
    dica "O doctor vai tentar de novo; se persistir, veja docs/PROBLEMAS-COMUNS.md."
  fi
}
