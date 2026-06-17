#!/usr/bin/env bash
# 01-deteccao.sh — Pré-checagens e detecção do ambiente Hermes.
# Define: MODO (docker|nativo), CONTAINER/COMPOSE_DIR/CONFIG_FILE/WEBHOOK_PY etc.

VERSAO_TESTADA="0.16"   # versão do Hermes em que o kit foi validado

# Garante que estamos como root (Hermes nativo vive em /root; Docker precisa de socket).
checar_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    erro "Este assistente precisa rodar como root."
    dica "Tenta de novo assim:  sudo bash $0"
    return 1
  fi
}

# Garante dependências básicas; oferece instalar via apt se faltar.
checar_dependencias() {
  local faltando=()
  for cmd in curl openssl python3 grep sed; do
    command -v "$cmd" >/dev/null 2>&1 || faltando+=("$cmd")
  done
  if (( ${#faltando[@]} == 0 )); then
    ok "Ferramentas básicas presentes."
    return 0
  fi
  dica "Faltam algumas ferramentas: ${faltando[*]}"
  if command -v apt-get >/dev/null 2>&1 && confirmar "Posso instalá-las agora?" s; then
    apt-get update -y >/dev/null 2>&1
    apt-get install -y "${faltando[@]}" >/dev/null 2>&1
    ok "Instaladas."
  else
    erro "Sem essas ferramentas não dá pra continuar."
    return 1
  fi
}

# Garante que o comando 'hermes' esteja no PATH (root não-interativo costuma
# não ter ~/.local/bin). Retorna 0 se encontrou.
_localizar_hermes() {
  command -v hermes >/dev/null 2>&1 && return 0
  local c
  for c in "$HOME/.local/bin/hermes" /root/.local/bin/hermes /usr/local/bin/hermes; do
    if [[ -x "$c" ]]; then
      local d; d="$(dirname "$c")"
      export PATH="$d:$PATH"
      return 0
    fi
  done
  return 1
}

# Detecta Docker (container hermes-agent) ou instalação nativa.
detectar_hermes() {
  local achou_docker="" achou_nativo=""

  if command -v docker >/dev/null 2>&1; then
    CONTAINER="$(docker ps --format '{{.Names}}' 2>/dev/null | grep -m1 hermes-agent || true)"
    [[ -n "${CONTAINER:-}" ]] && achou_docker="1"
  fi
  _localizar_hermes && achou_nativo="1"

  if [[ -n "$achou_docker" && -n "$achou_nativo" ]]; then
    titulo "Encontrei o Hermes nas duas formas (Docker e instalação nativa)."
    info "1) Docker (container: $CONTAINER)"
    info "2) Nativo (systemd)"
    local op; MENU_MAX=2
    perguntar op "Qual você usa para este agente? (1 ou 2)" valida_opcao_menu "Digite 1 ou 2."
    [[ "$op" == "1" ]] && achou_nativo="" || achou_docker=""
  fi

  if [[ -n "$achou_docker" ]]; then
    _detectar_docker
  elif [[ -n "$achou_nativo" ]]; then
    _detectar_nativo
  else
    erro "Não encontrei o Hermes nesta VPS."
    dica "Instale o Hermes primeiro (material da CCB) e rode este assistente de novo."
    return 1
  fi
}

_detectar_docker() {
  salvar_var MODO "docker"
  salvar_var CONTAINER "$CONTAINER"

  COMPOSE_DIR="$(docker inspect "$CONTAINER" \
    --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' 2>/dev/null || true)"
  if [[ ! -d "$COMPOSE_DIR" ]]; then
    erro "Não consegui localizar a pasta do docker-compose do container $CONTAINER."
    return 1
  fi
  salvar_var COMPOSE_DIR "$COMPOSE_DIR"
  salvar_var COMPOSE_FILE "$COMPOSE_DIR/docker-compose.yml"
  salvar_var CONFIG_FILE  "$COMPOSE_DIR/data/config.yaml"
  salvar_var ENV_FILE     "$COMPOSE_DIR/.env"
  salvar_var DATA_DIR     "$COMPOSE_DIR/data"
  salvar_var WEBHOOK_PY   "/opt/hermes/gateway/platforms/webhook.py"  # caminho DENTRO do container
  salvar_var WEBHOOK_HOST "0.0.0.0"

  ok "Hermes em Docker detectado."
  info "Container: $CONTAINER"
  info "Pasta do compose: $COMPOSE_DIR"
  _checar_versao
}

_detectar_nativo() {
  salvar_var MODO "nativo"
  # O código pode estar em /usr/local/lib/hermes-agent (instalador) ou no clone
  # do git (ex.: /root/hermes-agent). Descobrimos pelo "Project:" do --version
  # e, como reserva, resolvendo o symlink do comando hermes.
  local proj=""
  proj="$(hermes --version 2>/dev/null | grep -iE '^Project:' | awk '{print $2}' | head -1 || true)"
  if [[ -z "$proj" || ! -d "$proj" ]]; then
    local real; real="$(readlink -f "$(command -v hermes)" 2>/dev/null || true)"
    # .../<projeto>/venv/bin/hermes -> sobe 3 níveis
    [[ -n "$real" ]] && proj="$(cd "$(dirname "$real")/../.." 2>/dev/null && pwd || true)"
  fi
  [[ -d "$proj" ]] || proj="/usr/local/lib/hermes-agent"
  salvar_var HERMES_LIB "$proj"
  salvar_var WEBHOOK_PY "$proj/gateway/platforms/webhook.py"
  salvar_var WEBHOOK_HOST "127.0.0.1"
  ok "Hermes nativo detectado."
  info "Código: $proj"
  _checar_versao
}

_checar_versao() {
  local v
  v="$(hermes --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
  [[ -z "$v" && "${MODO:-}" == "docker" ]] && \
    v="$(docker exec "$CONTAINER" hermes --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
  if [[ -n "$v" ]]; then
    salvar_var HERMES_VERSAO "$v"
    info "Versão do Hermes: $v"
    if [[ "$v" != ${VERSAO_TESTADA}* ]]; then
      dica "Este assistente foi testado na versão ${VERSAO_TESTADA}.x. A sua é diferente — pode haver pequenas diferenças."
      confirmar "Quer continuar mesmo assim?" s || { erro "Ok, parando aqui."; return 1; }
    fi
  else
    dica "Não consegui descobrir a versão do Hermes — vou seguir assim mesmo."
  fi
}

# Avisa se o Hermes ainda não tem um modelo de IA configurado.
# O agente clona o perfil ativo; sem modelo, ele não consegue responder.
checar_modelo() {
  local saida modelo
  saida="$(hermes_cli status 2>/dev/null || true)"
  modelo="$(echo "$saida" | grep -iE '^[[:space:]]*Model:' | head -1)"
  if [[ -z "$modelo" ]] || echo "$modelo" | grep -qiE 'not set|nao set|—|\(none\)'; then
    dica "O seu Hermes ainda NÃO tem um modelo de IA configurado."
    info "Sem isso, o agente liga, mas não consegue pensar nem responder."
    caixa "Antes, configure o cérebro do agente com:" \
          "    hermes setup" \
          "(escolha um provedor de IA e cole a chave, ex.: OpenRouter)"
    confirmar "Já configurei o modelo (ou quero continuar assim mesmo)?" s \
      || { erro "Tudo bem — rode 'hermes setup' e depois '${CLI_NAME}' de novo."; return 1; }
  else
    ok "Modelo de IA configurado."
  fi
}

# Passo agregador chamado pelo orquestrador.
passo_precheck() {
  passo "PREPARANDO — verificando seu servidor"
  checar_root          || return 1
  checar_dependencias  || return 1
  detectar_hermes      || return 1
  checar_modelo        || return 1
}
