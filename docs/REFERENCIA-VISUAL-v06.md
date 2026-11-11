# Auditoria visual — cena do video (11/11/2026)

## Referencia observada no video fornecido pelo usuario
- Capturas do video de 720x1280 mostram soldado 3D com armadura clara e colete/preto, movimentos independentes de mira.
- Camera predominantemente de cima (superior inclinada), com chão azul-marinho, grade muito discreta, poucos obstaculos e cerca de madeira que se quebra ao receber tiros.
- Modelo e arma com aparencia articulada; nao ha posicao comprovada de câmera em graus ou arquivo fonte acessivel.

## Problemas da versão publicada anterior, confirmados por captura real Godot
- Camera muito lateral e obliqua em relação à referencia.
- Piso cinza com faixas amarelas, multiplos barris azuis, cercas grandes e aparência de protótipo.
- Zumbis coloridos com silhueta de cartoon, em conflito com o soldado tatico.
- Arma renderizada mas com risco de deslocamento porque acompanha o corpo, nao foi presa a um osso da mao.
- Arquivo inteiro com dezenas de animações era usado nos zumbis, com risco de custo desnecessário de importacao/memoria.

## Correções deste lote
- Camera mais alta, apenas ligeiramente inclinada na direcao do jogador; piso escuro plano com grade fosca.
- Remoção das faixas de pista, barris azuis, postes e cercas em excesso; cerca principal composta por ripas finas e pontas.
- Inimigos usam a mesma familia de modelo humano militar animado, com textura de roupa envelhecida e variacao sutil de tamanho, nunca modelos cartoon.
- Versao derivada `infected.glb` com seis animacoes de movimento/combate, gerada sem copiar ou executar software externo.
- Limite de zumbis simultaneos reduzido de 26 para 14 em prol do desempenho Web mobile.

## Portas de qualidade antes de publicar
1. Godot Actions passa em importacao, GDScript, smoke, testes mobile e exportacao Web.
2. Arquivo de screenshot real `build/preview.png` analisado em comparação com a referencia.
3. Soldado e arma legiveis, zumbis humanoides, chao escuro sem marcacoes de transito.
4. Sem erros de script no render, sem regressao de toque e tiro automatico.
5. **Ainda pendente:** anexar arma a esqueleto da mão com IK/transformos e validar taxa de quadros em celular real. Nao afirmar paridade 1:1.

## Licenças
Modelo militar e movimentos conforme `assets/tactical/CREDITS.md`; Quaternius CC0 para arma e props. A versão derivada infectada conserva a licença e a atribuição da fonte original (CC BY 4.0).
