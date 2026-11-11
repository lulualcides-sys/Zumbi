# Zombie Outbreak — shooter de sobrevivência em Godot 4

Projeto autoral em desenvolvimento: câmera 3/4 inclinada, movimentação WASD independente da mira, inimigos zumbis, recarga, dano e objetos destrutíveis.

## Executar
1. Instalar Godot **4.7.2 stable**.
2. Abrir o `project.godot` no Godot e executar o projeto (F5).
3. WASD mover • Shift correr • Mouse mirar e atirar • R recarregar • Enter reiniciar após morrer.

## Processo automatizado
O workflow [Godot CI](.github/workflows/godot-ci.yml) instala Godot e os templates de exportação **somente no servidor do GitHub**, importa o projeto, executa teste de carregamento e tenta produzir um build Web como artefato.

## Arsenal e Game Studios
- [Arsenal](https://github.com/lulualcides-sys/Arsenal): referências de VFX, QA, animações e desenvolvimento.
- [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) (MIT): metodologia de planejamento, revisão e QA. Nesta fase é referência; **Claude Code não foi instalado nem executado**, portanto não exige token da Anthropic.
- Os meshes atuais são originais e procedurais; não incorporam assets de terceiros.

## Limitações
Protótipo técnico, sem o acabamento visual do vídeo. IA usa perseguição simples sem navmesh; personagens não têm animações finais. Exportação, desempenho e jogabilidade dependem de testes. Nenhuma mudança no Pokémon Torre 2.
