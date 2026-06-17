#!/usr/bin/env bash
# 10-credenciais.sh — Coleta token do Telegram, chat ID do dono e API key do Zernio.
# Cada item vem com um mini-tutorial de onde conseguir, antes da pergunta.

EXEMPLO_BOT_NOME="${EXEMPLO_BOT_NOME:-Atendente do Meu Negócio}"

# Confere de verdade que o token do Telegram funciona (e descobre o @ do bot).
_testar_bot_telegram() {
  local token="$1" resp
  resp="$(curl -s --max-time 15 "https://api.telegram.org/bot${token}/getMe" 2>/dev/null || true)"
  if echo "$resp" | grep -q '"ok":true'; then
    BOT_USERNAME="$(echo "$resp" | grep -oE '"username":"[^"]+"' | head -1 | cut -d'"' -f4)"
    return 0
  fi
  return 1
}

passo_credenciais() {
  passo "PASSO 1 DE 4 — Criar o robô (bot) do seu agente no Telegram"
  printf '  Seu agente conversa com você pelo Telegram. Vamos criar um "bot" (grátis):\n\n'
  printf '   1. Abra o Telegram e procure por:  @BotFather\n'
  printf '   2. Mande a mensagem:  /newbot\n'
  printf '   3. Dê um nome (ex.: "%s")\n' "$EXEMPLO_BOT_NOME"
  printf '   4. Dê um nome de usuário terminando em "bot"\n'
  printf '   5. O BotFather devolve um TOKEN parecido com:\n'
  printf '      1234567890:AAEhBOweik6ad9r_QXMENQOcrGoyXqNDdPk\n'
  while true; do
    perguntar TELEGRAM_BOT_TOKEN "Cole aqui o TOKEN do seu bot:" \
      valida_token_telegram "Isso não parece um token (formato: 1234567890:AAE...). Copia de novo?" --segredo
    if _testar_bot_telegram "$TELEGRAM_BOT_TOKEN"; then
      ok "Bot encontrado: @${BOT_USERNAME}"
      salvar_var TELEGRAM_BOT_TOKEN "$TELEGRAM_BOT_TOKEN"
      salvar_var BOT_USERNAME "$BOT_USERNAME"
      break
    else
      dica "Não consegui falar com esse bot. O token pode estar incompleto ou ter sido revogado."
      TELEGRAM_BOT_TOKEN=""   # força reperguntar do zero
    fi
  done

  passo "PASSO 2 DE 4 — Descobrir o seu número de identificação no Telegram"
  cat <<'EOT'
  O agente precisa saber QUEM é o dono (você) para te mandar os avisos.

   1. No Telegram, procure por:  @userinfobot
   2. Mande qualquer mensagem (um "oi")
   3. Ele responde com o seu "Id" — um número parecido com 987443079
EOT
  perguntar TELEGRAM_CHAT_ID "Digite o seu Id:" \
    valida_chat_id "Isso precisa ser só números (ex.: 987443079). Tenta de novo?"
  salvar_var TELEGRAM_CHAT_ID "$TELEGRAM_CHAT_ID"
  ok "Anotado."

  passo "PASSO 3 DE 4 — Chave do Zernio (a ponte com o Instagram)"
  cat <<'EOT'
  O Zernio é o serviço que conecta o agente ao seu Instagram.

   1. Crie sua conta em:  https://zernio.com  (se ainda não tem)
   2. Conecte seu Instagram:  Dashboard -> Connections -> Instagram
      (faça login com a conta do SEU NEGÓCIO)
   3. Crie uma chave:  https://zernio.com/dashboard/api-keys
      -> Create API Key -> copie o código que começa com "sk_"
EOT
  perguntar ZERNIO_API_KEY "Cole aqui a sua API key do Zernio:" \
    valida_api_zernio "A chave do Zernio começa com 'sk_'. Copia de novo?" --segredo
  salvar_var ZERNIO_API_KEY "$ZERNIO_API_KEY"
  ok "Chave guardada."

  ok "Credenciais coletadas! Elas ficam guardadas só aqui na sua VPS, em $ESTADO_DIR."
}
