# Como gravar o `demo.gif` (15–30s)

O README mostra `docs/imagens/demo.gif` no topo. Grave uma demo curta assim:

1. **Roteiro (15–30s):** abra o Telegram do bot, mande "Crie um post informativo explicando o que é
   uma audiência de conciliação, com uma imagem sóbria — me mostra antes de publicar" e mostre o
   agente respondendo; OU mostre um comentário/DM chegando no Instagram ("quanto custa um divórcio?")
   e o agente respondendo dentro da ética (sem citar valor, convidando para a consulta) + o aviso no Telegram.
2. **Gravar a tela:**
   - macOS: QuickTime (gravação de tela) → exporte com [Gifski](https://gif.ski/).
   - Windows: [ScreenToGif](https://www.screentogif.com/).
   - Terminal: `asciinema rec` + [`agg`](https://github.com/asciinema/agg) para virar GIF.
3. **Otimize** para < 5 MB (largura ~800px, 10–15 fps).
4. Salve como `docs/imagens/demo.gif` e dê commit.

Enquanto não houver o GIF, o link fica quebrado de propósito (lembrete visual).
