# Pacote visual Quaternius — CC0

Fonte oficial e licença: https://quaternius.com/packs/zombieapocalypsekit.html (Zombie Apocalypse Kit, março de 2024, CC0).

Espelho usado somente para baixar GLTF existentes: https://github.com/agentkaerf/FreeModels — commit fixo `db3df04d1e4714298a09510b26fb6de6645138a2`. Direitos da arte pertencem ao autor original; arquivos Quaternius são dedicados ao domínio público CC0.

**Instalação reproduzível:** `python3 tools/install_cc0_art.py` (antes de abrir/importar no Godot). Os 9 modelos são baixados para `assets/cc0/` e o manifest guarda SHA-256, tamanho, origem e nomes reais das animações. Não executa código de terceiros. Arquivos GLTF gerados e de tamanho potencialmente grande ficam fora do Git e são empacotados no `.pck` do Godot pelo CI. Um clone local sem instalação de assets usa automaticamente os personagens geométricos de fallback.

**Critério de qualidade:** modelos reais e animações substituem as primitivas quando disponíveis. Não alegar equivalência com o vídeo antes de avaliar capturas de tela e controle com teclado/mouse.

**Arma visível:** `rifle.gltf` (Quaternius, `Weapons/glTF/Rifle.gltf`) é instanciada à frente do torso do sobrevivente e possui um marcador no cano usado pelo sistema de tiro. O material original é CC0. O teste `smoke.gd` falha se o fuzil estiver ausente do personagem após o download.
