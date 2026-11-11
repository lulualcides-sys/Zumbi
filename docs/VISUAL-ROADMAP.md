# V0.3 — padrão visual inspirado no vídeo enviado (11/11/2026)

O vídeo mostra protótipo 3D com soldado de proporções humanas, camera 3/4 relativamente próxima, movimentação independente da direção de mira, tiro com impacto visual e cercas quebrando em fragmentos. Não é um FPS em primeira pessoa nem uma câmera isométrica matemática perfeita.

## Correções prioritárias sobre 0.2

- **Personagem**: substituir os cubos por personagem de malha 3D com UV, capacete/roupa reais e animações; fonte Quaternius 2024 CC0. Usar variantes de zumbi do mesmo pack. Não reproduzir a identidade exata da figura do vídeo.
- **Animação**: o pacote oficial inclui clips Idle_Gun, Walk_Gun, Run_Gun e múltiplas animações de zombie. Deve tocar a animação coerente com deslocamento, sem recomeçar todo frame.
- **Enquadramento**: zoom de 18 para 13.9 unidades ortográficas, elevação menos vertical (offset 15.5/13.4); comparar screenshot real e ajustar depois.
- **Ambiente**: rua de baixa saturação, luz noturna, real props GLTF para barris, pallets, barreiras e contêiner. Exigir material/tamanho legíveis no WebGL.
- **Combate**: preservar mira separada do WASD, hitscan, partículas e colisões aprovadas na v0.2. Próxima etapa exigirá tiros ligados a animações e efeitos melhores.
- **Destruição**: cercas segmentadas com dano próprio e fragmentos finos; preservar legibilidade.

## Evidência exigida para publicar

- Source e licença verificadas: https://quaternius.com/packs/zombieapocalypsekit.html — CC0 1.0; espelho fixado em `agentkaerf/FreeModels@db3df04d1e4714298a09510b26fb6de6645138a2`.
- GitHub Actions baixa apenas 8 arquivos glTF sem executar scripts externos, verifica versão GLTF e recursos externos, registra SHA-256, importa via Godot e exige o modelo CC0 realmente instanciado.
- Testes de lógica e export Web completos; screenshot real do Godot via Xvfb opcional, nunca trocar screenshot de execução por arte conceitual.
- O clone local continua jogável com fallback de baixa qualidade sem assets; execute `python3 tools/install_cc0_art.py` antes de importar no editor.

## Não concluído

Ainda faltam: animações de reação a tiro e morte, personagens com qualidade artística equivalente ao vídeo, screenshot/QA comparativo, som, iluminação avançada, IA com NavigationServer e testes humanos. Nenhuma alteração no Pokémon Torre 2.
