# Hermes Advocacia by CCB

![Demonstração](docs/imagens/demo.gif)

> **Falta o GIF de demonstração.** Grave 15–30s mostrando você pedindo um post informativo pelo
> Telegram e o agente respondendo um comentário/DM no Instagram (convidando para agendar consulta).
> Exporte como GIF e salve em `docs/imagens/demo.gif` (ferramentas: QuickTime + Gifski, ScreenToGif,
> ou `asciinema`+`agg`). Veja [docs/imagens/COMO-GRAVAR-O-GIF.md](docs/imagens/COMO-GRAVAR-O-GIF.md).

## 1. O que é
Um agente que cuida do Instagram do seu **escritório de advocacia**: responde dúvidas gerais, faz a triagem e encaminha o agendamento de consultas — sempre **dentro dos limites da OAB** e controlado pelo seu **Telegram**, sem você precisar mexer em código.

## 2. Benefícios
- **Atende na hora, 24/7, com sobriedade.** Aquela dúvida do fim de semana ("vocês atuam em inventário?") não fica sem resposta — e quem espera procura outro escritório.
- **Triagem antes de chegar em você.** O agente identifica de forma genérica a área/assunto e convida para a consulta; só te chama no Telegram quando é alguém querendo agendar ou um caso que precisa de você.
- **Respeita a ética da OAB por padrão.** Nunca divulga honorários, nunca promete resultado, nunca faz captação nem opina sobre o caso de ninguém em público. Comunicação informativa e discreta.
- **Preserva o sigilo profissional.** Não pede nem guarda dados do caso, número de processo ou documentos pelo Direct.
- **Padroniza a primeira conversa.** Sempre formal, sempre dentro das suas regras — sem improviso que possa comprometer o escritório.

## 3. Casos de uso reais
- **"Vocês atuam em direito trabalhista?"** — o agente informa se é uma das áreas de atuação, explica que cada caso é analisado em consulta e convida a agendar. Não opina sobre nenhum caso.
- **"Quanto custa uma ação de divórcio?"** — explica, sem citar valor, que honorários são tratados apenas em consulta reservada (pois dependem da análise do caso) e convida a agendar. Te avisa no Telegram.
- **Pessoa relatando detalhes do caso na DM** — o agente **não opina** nem diz se há direito; acolhe com sobriedade, preserva o sigilo, explica que a análise séria é feita em consulta e convida a agendar. Te avisa no Telegram.
- **"Eu ganho essa causa?"** — **nunca promete resultado**; explica de forma sóbria que ninguém sério garante êxito e que a viabilidade é avaliada na consulta. Convida a agendar.
- **"Quais documentos eu levo na consulta?"** — responde a dúvida operacional, de forma informativa, e confirma o convite para agendar.

Veja os roteiros completos em [docs/CASOS-DE-USO.md](docs/CASOS-DE-USO.md).

## 4. Pré-requisitos
1. Uma **VPS** com o **Hermes Agent já instalado** (Docker **ou** nativo). (Material da CCB.)
2. O Hermes com um **modelo de IA configurado** (`hermes setup`).
3. **Telegram** no celular.
4. Uma conta no **Zernio** (zernio.com) com o **Instagram do escritório conectado**.

## 5. Como instalar (1 comando)
Conecte na sua VPS por SSH e cole:

```bash
curl -fsSL https://raw.githubusercontent.com/kleinelizeu/advocacia-ccb/main/install.sh | sudo bash
```

O assistente abre sozinho e te guia. Depois, a qualquer momento:

```bash
hermes-advocacia            # roda/continua o assistente
hermes-advocacia doctor     # confere tudo e corrige problemas comuns
hermes-advocacia info       # mostra endereço do webhook, chave e nome do bot
hermes-advocacia contexto   # mostra o texto do escritório para colar no bot
```

## 6. Como usar no dia a dia
No Telegram do seu bot, é só pedir em português normal:
- "Crie um post informativo explicando o que é uma audiência de conciliação, com uma imagem sóbria. Me mostra antes de publicar."
- "Responde quem comentou perguntando preço explicando que honorários são tratados só na consulta e convidando para agendar."
- "Quantas pessoas me mandaram DM hoje querendo agendar uma consulta?"
- "Muda meu tom de voz para mais acolhedor, mas mantendo a formalidade."

## 7. Perguntas frequentes + comandos
**Preciso saber programar?** Não. O assistente faz tudo e explica onde clicar.

**O agente vai dar orientação jurídica ou opinar sobre o caso da pessoa?** Não. Por padrão ele só dá informações **gerais** (áreas, como funciona a consulta, documentos) e convida para agendar. Nunca opina sobre caso concreto, nunca promete resultado.

**E os honorários, ele fala o valor?** Nunca. A OAB veda divulgar honorários em público; o agente sempre remete à consulta reservada.

**Mexe no meu Hermes que já uso?** Cria um agente **separado** (`advocacia`), sem mexer no que você já tem.

**Onde ficam minhas senhas e chaves?** Só na **sua VPS**, em `/root/.advocacia-ccb/` (protegida).

**Testei do meu próprio Instagram e não respondeu.** Normal: o Zernio só dispara para **outra** pessoa.

**As respostas pararam.** Rode `hermes-advocacia doctor` — costuma detectar e corrigir.

Mais detalhes em [docs/COMO-FUNCIONA.md](docs/COMO-FUNCIONA.md), [docs/CASOS-DE-USO.md](docs/CASOS-DE-USO.md) e [docs/PROBLEMAS-COMUNS.md](docs/PROBLEMAS-COMUNS.md).
