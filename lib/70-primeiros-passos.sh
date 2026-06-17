#!/usr/bin/env bash
# 70-primeiros-passos.sh — Mensagem final: salvar o contexto e testar as 2 demos.

passo_primeiros_passos() {
  passo "PRONTO! SEU AGENTE ESTÁ NO AR 🎉"

  titulo "1) Ensine o agente sobre o seu negócio"
  info "Abra o bot @${BOT_USERNAME:-seu_bot} no Telegram, cole a mensagem abaixo"
  info "e em seguida peça: \"Salve isso na sua memória como o contexto do meu negócio\"."
  echo
  if [[ -f "$ESTADO_CONTEXTO" ]]; then
    cat "$ESTADO_CONTEXTO"
  fi
  echo
  nota "(Para ver isto de novo depois:  ${CLI_NAME} contexto)"

  titulo "2) Teste o primeiro post (Demo 1)"
  info "No Telegram, mande algo como:"
  copiavel "Crie um post pro Instagram sobre [um tema do seu negócio], com uma imagem bonita. Me mostra antes de publicar."
  info "O agente cria a legenda + imagem e pede sua aprovação antes de publicar."

  titulo "3) Teste as respostas automáticas (Demo 2)"
  info "Peça para ALGUÉM (outra conta) comentar ou mandar DM no seu Instagram."
  dica "Da SUA própria conta o Zernio não gera evento — use outra conta para testar."
  info "Em instantes o agente responde no Instagram e te avisa aqui no Telegram."

  echo
  nota "A primeira resposta pode levar alguns minutos, dependendo do modelo do seu Hermes."
  echo
  titulo "Comandos úteis"
  info "${CLI_NAME} doctor    -> conferir se está tudo certo / corrigir problemas"
  info "${CLI_NAME} info      -> ver endereço do webhook, chave e nome do bot"
  info "${CLI_NAME} contexto  -> ver de novo o texto do seu negócio para colar"
  echo
  ok "Bom trabalho! Qualquer coisa, rode  ${CLI_NAME} doctor."
}
