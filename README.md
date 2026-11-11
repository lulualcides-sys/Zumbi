# Zombie Outbreak — Godot 3D

Shooter de sobrevivencia contra zumbis em **Godot 4.7.2**, com camera 3/4 superior, orientacao independente da mira, ondas de inimigos, impacto dos tiros e cercas destrutiveis. Codigo e modelos procedurais sao originais.

## O que funciona na versao 0.2
- Sobrevivente low-poly com capacete, colete, mochila, arma e membros animados proceduralmente.
- Camera 3/4 ortografica com acompanhamento suave. WASD e rotacao pelo mouse independentes.
- Disparo continuo (hitscan), particulas de impacto, rastro, recuo, carregador de 32 e recarga temporizada.
- Zumbis low-poly com variantes, locomocao, perseguidor simples, dano por proximidade e efeitos de morte.
- Cerca de madeira dividida em partes com vida, destrocos e outras caixas destrutiveis.
- Ondas progressivas, HUD, pontuacao, medkits e municao como pickups.
- Testes no GitHub Actions e exportacao HTML5.

## Controles
WASD: movimento. Shift: correr. Mouse: mirar; clique esquerdo: atirar. R: recarregar. Enter: recomeçar apos morrer.

## Abrir no Godot
1. Instale Godot 4.7.2.
2. Abra \`project.godot\` e execute F5 (ou selecione \`scenes/Main.tscn\`).
3. Para build web em CI, acesse [Actions](https://github.com/lulualcides-sys/Zumbi/actions) e o artefato \`zombie-outbreak-godot-web\`.

## Referencias e processo
- [Mapa de requisitos do video](docs/REFERENCIA-VIDEO.md).
- [Arsenal](https://github.com/lulualcides-sys/Arsenal) para ferramentas e referencias.
- [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios), MIT: usamos a metodologia (brief, implementacao focada e QA). O agente Claude nao foi instalado nem precisa de tokens pagos para este build.

## Estado real
O codigo pode compilar e exportar via GitHub Actions, mas a avaliacao humana da jogabilidade, o equilibrio e a paridade visual com o video exigem playtest. Personagens ainda sao geometria low-poly (nao modelos 3D finais). IA ainda nao usa NavigationServer3D. Sem audio profissional, fases/campanha ou compatibilidade completa com toque em celular. Nenhum codigo do Pokemon Torre 2 e alterado.
