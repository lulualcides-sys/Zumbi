# Zombie Outbreak — brief v0.1

**Objetivo:** shooter 3D com câmera 3/4 inclinada (não FPS), movimentação independente da mira e sobrevivência a hordas de zumbis. Referência audiovisual: vídeo fornecido pelo proprietário do Arsenal em 11/11/2026; inspiração de mecânica, sem cópia de arte ou código.

## Primeira versão implementada
- Godot 4.7.2, GDScript, renderização GL Compatibility para facilitar exportação Web.
- Arena procedural 3D, WASD, corrida, câmera acompanhando e mouse independente da movimentação.
- Fogo contínuo, recarga, munição, dano por raycast, zumbis perseguindo, HP, pontuação e reinício.
- Obstáculos destrutíveis com detritos geométricos simples.
- Sem modelos, sons ou sprites proprietários; todos os meshes são primitivas de Godot.

## Próximas etapas (não implementadas)
- Personagem e zumbis animados de qualidade (licenças verificadas).
- Sistema de armas, recarga sincronizada e animações de impacto.
- IA de navegação com NavMesh (o protótipo usa perseguição direta).
- Cenários detalhados, ciclo de ondas, loot e progressão.
- QA visual, desempenho real, playtest e publicação separada.

## Princípios
Não tocar no código do Pokémon Torre 2. Não executar agentes de terceiros com permissão de escrever/push sem revisão. Claude Code Game Studios é um processo de gestão/QA, não um sistema instalado neste chat nem garantia de jogo pronto. O fluxo Godot do framework não é validado pelos próprios autores com a mesma profundidade que o fluxo Web.
