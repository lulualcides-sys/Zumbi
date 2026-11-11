# Arsenal e Claude Code Game Studios — execução real no Zumbi

## Onde e como o GitHub Actions utiliza as ferramentas

O Arsenal do usuário é https://github.com/lulualcides-sys/Arsenal. Ele é um catálogo e biblioteca; registrar uma ferramenta não significa instalá-la.

O workflow .github/workflows/arsenal-qa.yml faz checkout de duas fontes em revisões fixas:
- Arsenal @ 94ebfdb3b7ff8c5ceb586016d47c4f5e9c939e4e
- Claude Code Game Studios @ abc0de79d6ceb0b5d7aa693945849b3937afbe6a (MIT)

Não executamos scripts arbitrários de nenhum desses repositórios. O CCGS é um processo de agentes que requer Claude Code; os guias de asset-audit e test-evidence-review são adaptados para verificações determinísticas locais, sem serviços de IA pagos.

### Ferramentas realmente executadas em CI

| Ferramenta | O que é executado | Evidência |
|---|---|---|
| Godot 4.7.2 | Importa glTF/GLB, roda testes e exporta HTML5 | Logs + preview real |
| Quaternius CC0 | Download validado e import de fuzil, zumbis e props | Manifest de assets |
| Soldado licenciado CC BY 4.0 | Download com SHA e validação de animações | Logs e fontes em assets/tactical/CREDITS.md |
| Python 3 | Auditoria de formato, tamanho real, animações e licenças, baseada no CCGS | build/qa/asset-audit.md + .json |
| Playwright | Instalação via npm de versão fixada, com Chromium no runner GitHub Actions | desktop.png, mobile.png, mobile-after-touch.png, browser-report.json |
| Chromium WebGL | Abre a exportação real, verifica canvas e requisições | Relatório do navegador |
| Emulação touch CDP | Envia toque, movimento e liberação reais ao browser, junto de testes Godot de movimento | Screenshot + logs |

### Critérios para não confundir testes com estética

Os relatórios distinguem PASS, FAIL e NOT ASSESSED. Compilar, carregar modelos ou exportar Web não confirma que a mão segura a arma corretamente, que o soldado se parece com o vídeo ou que o jogo rode bem num Android real.

A v0.6 visual ainda está bloqueada no PR #11. Esta integração de ferramentas é separada e não publica o jogo.

### Ferramentas do arsenal NÃO instaladas neste lote

PixelFX, Effekseer, LibreSprite e Pixelorama: principalmente VFX/pixel art 2D, não solucionam diretamente a rigagem 3D. REA: desnecessário pois já temos fontes. Blender: recomendado para construir um conjunto consistente soldado+arma+animações, mas ainda não integrado nem testado neste lote. Agentes Claude: não executados.

### Limites

GitHub Actions utiliza minutos de runner e transferência de dependências; não significa custo zero para qualquer plano. Playwright no Chromium simula um navegador móvel, não mede FPS de aparelho físico. GitHub Actions pode validar consistência técnica, mas a aprovação visual requer comparação de capturas com o vídeo e testes manuais.
