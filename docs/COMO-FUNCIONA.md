# Como funciona (em linguagem simples)

O Hermes Advocacia liga três coisas: o **Instagram** do seu escritório, o **Zernio** e o seu **agente Hermes**, com o **Telegram** como seu "painel de controle".

## As duas demonstrações

### Demo 1 — Posts com imagem
Você pede um post pelo Telegram (ex.: "crie um post informativo explicando o que é uma audiência de conciliação, com uma imagem sóbria"). O agente escreve a legenda, gera a imagem e mostra para você aprovar. Aprovou, ele publica no Instagram pelo Zernio.

### Demo 2 — Respostas automáticas
Quando alguém comenta ou manda DM no Instagram do escritório, o Zernio avisa o seu agente na hora (*webhook*). O agente lê, responde seguindo as regras do escritório (de forma informativa, sem opinar sobre o caso, sem citar honorários, convidando para a consulta) e te manda um resumo no Telegram.

```
Comentário/DM no Instagram
        │
        ▼
     Zernio  ──(internet, HTTPS)──►  seu agente Hermes
        ▲                                  │
        │                                  ├─ responde no Instagram
        └────────── publica posts ◄────────┤
                                           └─ te avisa no Telegram
```

## Conformidade com a OAB (Provimento 205/2021 e Código de Ética)
O agente é configurado para se comunicar de forma **informativa, sóbria e discreta** e para **nunca** ultrapassar os limites éticos da advocacia. Por padrão, em qualquer situação, ele:
- **não divulga honorários, valores, tabelas, promoções ou descontos** — isso só é tratado em consulta reservada;
- **não promete nem estima resultado** de causa;
- **não capta clientela** nem usa linguagem de venda ("contrate já", "melhor advogado");
- **não opina sobre o caso concreto de ninguém** em público nem em DM (nada de "consulta jurídica" pela internet);
- **preserva o sigilo profissional** — não expõe nem guarda dados de quem entra em contato.
O que ele faz é dar informações gerais (áreas de atuação, como funciona a consulta, documentos) e convidar para **agendar uma consulta** no canal privado. Tudo isso fica escrito no "contexto do negócio", que você cola no bot.

## Por que precisa de "endereço HTTPS"
Para o Zernio falar com o seu agente pela internet, o agente precisa de um endereço seguro (https).

- **Docker:** o Traefik do seu Hermes cria esse endereço automaticamente (estável).
- **Nativo:** usamos o **Cloudflare Tunnel** (cloudflared). Esse endereço pode mudar se a VPS reiniciar — por isso existe o `hermes-advocacia doctor`, que detecta o novo e te avisa para atualizar no Zernio.

## Onde ficam suas informações
Tudo que você digita (tokens, chave do Zernio, dados do escritório) fica só na sua VPS, em `/root/.advocacia-ccb/`, com acesso restrito. As "instruções de trabalho" do agente você mesmo cola no bot do Telegram para ele guardar na memória.
