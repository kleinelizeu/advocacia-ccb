# Problemas comuns (e como resolver)

A maioria se resolve rodando:

```bash
hermes-advocacia doctor
```

---

### "Comentei/mandei DM e o agente não respondeu"
**Quase sempre não é bug.** O Zernio só dispara o webhook para interações de **outra** pessoa. Teste de **outra conta** do Instagram.

### "As respostas pararam de funcionar do nada" (instalação nativa)
O endereço do túnel (Cloudflare) provavelmente **mudou** (a VPS reiniciou). Rode `hermes-advocacia doctor`: ele mostra o **endereço novo**. Atualize no painel do Zernio em *Webhooks → seu webhook → Endpoint URL*.

### "O bot do Telegram não responde"
O token pode ter sido revogado no @BotFather. Rode `hermes-advocacia` de novo e cole o token atual.

### "O agente citou um valor de honorários / prometeu resultado / opinou sobre um caso"
**Isso não pode acontecer** — viola o Código de Ética e o Provimento 205/2021 da OAB. As regras (nunca divulgar honorários, nunca prometer resultado, nunca opinar sobre caso concreto, preservar o sigilo) ficam no contexto do negócio. Rode `hermes-advocacia contexto`, confira se o texto com os **limites éticos da OAB** está lá e cole de novo no bot pedindo "salve isso na sua memória". Se persistir, rode `hermes-advocacia` e reforce o campo "o que o agente NUNCA deve fazer".

### "O agente está fazendo captação / usando linguagem de venda"
A comunicação deve ser **informativa, sóbria e discreta** (sem "contrate já", "melhor advogado", promoções). Reaplique o contexto com `hermes-advocacia contexto` e, se quiser, ajuste o tom de voz rodando `hermes-advocacia` (use os tons sóbrios, não informais).

### "O agente respondeu 'qual contato? qual interação?'"
A rota do webhook está sem os dados do evento. O assistente cria a rota com o marcador `{__raw__}`. Rode `hermes-advocacia doctor` para recriar.

### "O Zernio mostra 200/sucesso, mas o agente não age"
A rota não pode ter **filtro de eventos**. O assistente cria a rota **sem filtro**. Rode `hermes-advocacia doctor`.

### "O Zernio mostra 401 (não autorizado)"
A **chave de segurança** (Signing Secret) no painel do Zernio difere da que está na VPS. Rode `hermes-advocacia info` para ver a chave certa e cole no Zernio.

### "Depois de atualizar o Hermes, parou" (instalação nativa)
Atualizar o Hermes apaga o ajuste da assinatura (`X-Zernio-Signature`). Rode `hermes-advocacia doctor` — ele reaplica.

### "Depois de um `docker compose down/up`, parou" (Docker)
O assistente já deixa um ajuste que reaplica sozinho a cada reinício do container. Se ainda falhar, rode `hermes-advocacia doctor`.

### "A resposta demora vários minutos"
Depende do modelo de IA configurado no seu Hermes. Modelos gratuitos costumam ser mais lentos. Configure um modelo mais rápido no perfil.

### "O agente diz que marcou, mas não aparece nada na agenda" / erro de permissão
Quase sempre a agenda foi compartilhada com o robô **só como leitura**. Abra *calendar.google.com → Configurações e compartilhamento*, ache o e-mail do robô (`...iam.gserviceaccount.com`) e troque a permissão para **"Fazer alterações nos eventos"**.
**Agenda de empresa (Google Workspace):** se esse campo estiver **bloqueado/cinza**, é a política do Workspace barrando edição por conta externa — use uma agenda de **Gmail pessoal** (sem a trava) ou libere em *admin.google.com → Apps → Google Workspace → Agenda → Opções de compartilhamento externo*. *(Sintoma técnico: erro 403 "writer access".)*

### "O agente não consegue acessar a agenda / erro de credencial"
Confira que você **compartilhou a agenda com o e-mail do robô** e que o JSON colado é o da conta de serviço certa. Rode `hermes-advocacia doctor` (ele reconecta) ou `hermes-advocacia` (passo da agenda).

---

Se nada disso resolver, leve a saída do `hermes-advocacia doctor` para a comunidade.
