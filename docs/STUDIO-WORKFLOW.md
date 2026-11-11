# Guia de desenvolvimento e QA — Zombie Outbreak

Adaptação seletiva do processo [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) (MIT). **Não são copiados os agentes, hooks ou a configuração Claude**, pois seus comandos exigem Claude Code e não são executados automaticamente no GitHub Actions.

## Porta de qualidade
- Cena principal abre e carrega câmera, jogador e inimigos
- Mecânicas essenciais respondem e não produzem erro de parser
- Exportação Web compila com Godot 4.7.2 estável
- Alterações de arte e gameplay avaliadas em protótipo/PR antes de publicar
- Licença dos assets externos documentada e testada antes de utilização

## Backlog priorizado
1. Corrigir todas as falhas reais de CI e concluir um smoke test positivo.
2. Mecânica de tiros, colisão e movimentos, com avaliação jogável.
3. Animações e modelos originais de sobrevivente/zumbi.
4. Navmesh/IA de hordas, agressividade, áudio e impactos.
5. Cenário noturno, iluminação, clima, progressão, loot e otimização.

## Instruções de segurança
Não executar scripts de agentes de terceiros diretamente com credenciais do GitHub; não carregar tokens de Anthropic neste protótipo; não autorizar push em outros repositórios.
