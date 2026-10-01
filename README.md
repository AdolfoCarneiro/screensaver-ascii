# screensaver-ascii

Um protetor de tela de terminal para **KDE Plasma 6 (Wayland)** feito em Python puro: quando o PC fica parado,
um Konsole em tela cheia abre e começa um rodízio de 18 cenas animadas em ASCII e meio-bloco (`▀▄`), que se
dissolvem umas nas outras com um efeito de glitch. Mexeu no mouse ou no teclado, ele some.

E, se você quiser, o mesmo rodízio vira um **vídeo de fundo na tela de bloqueio**.

![Synthwave](docs/synthwave.png)

| | |
|---|---|
| ![Matrix](docs/matrix.png) | ![Clawd caçando bugs](docs/clawd.png) |
| ![Tetris jogando sozinho](docs/tetris.png) | ![Clawd no espaço](docs/clawdespaco.png) |

## Cenas

| Cena | O que é |
|---|---|
| `Matrix` | chuva de katakana, claro |
| `Plasma` | plasma colorido clássico da demoscene |
| `Tunel` | túnel xadrez girando |
| `Estrelas` | campo de estrelas em warp |
| `Fogo` | fogo subindo do chão |
| `Ondas` | gotas caindo num lago escuro |
| `Vida` | Jogo da Vida de Conway |
| `Rosca` | o famoso donut 3D girando |
| `Hex` | "hacker" despejando hex e mensagens de filme |
| `Synthwave` | sol, montanhas e grade retrô |
| `Pokemon` | batalha no estilo FireRed/LeafGreen (precisa baixar os sprites, veja abaixo) |
| `Clawd` | o mascote do Claude Code caçando bugs no meio do código |
| `ClawdSoneca` | Clawd tirando um cochilo |
| `ClawdFesta` | Clawd na balada |
| `ClawdEspaco` | Clawd de jetpack no espaço |
| `Tetris` | Tetris jogando sozinho |
| `DVD` | o logo do DVD quicando (vai bater no canto?) |
| `Labirinto` | labirinto 3D em raycasting, estilo Wolfenstein |

Algumas cenas ainda podem vir **combinadas** (uma por cima da outra) e com paletas de cores sorteadas.

### Easter eggs

Tem. São raros, são bobos e são de gosto duvidoso — algo pode **voar** pela tela quando você menos espera.
Não vou estragar a surpresa; se não aguentar de curiosidade, rode com `SS_OVOS=1`.

## Requisitos

- Fedora (testado no 44) com **KDE Plasma 6 no Wayland** e **Konsole**
- `python3` (só biblioteca padrão para o screensaver em si)
- `swayidle` — `sudo dnf install swayidle`
- Fonte **Hack Nerd Font Mono** (recomendada; os perfis do Konsole usam ela) — [nerdfonts.com](https://www.nerdfonts.com/font-downloads)
- Opcional, para a cena de Pokémon: `python3-pillow` e internet
- Opcional, para o vídeo da tela de bloqueio: `python3-pillow`, `ffmpeg` com `libx264` (o do RPM Fusion) e o
  plugin **Smart Video Wallpaper Reborn** (`sudo dnf install plasma-smart-video-wallpaper-reborn`)

## Instalação

```bash
git clone https://github.com/AdolfoCarneiro/screensaver-ascii.git
cd screensaver-ascii
./instalar.sh               # o básico
./instalar.sh --pokemon     # + baixa os sprites da cena de Pokémon
./instalar.sh --bloqueio    # + vídeo na tela de bloqueio
```

O instalador pode rodar quantas vezes quiser. Ele copia:

| Arquivo | Para |
|---|---|
| `screensaver-ascii`, `screensaver-iniciar`, `screensaver-parar` | `~/.local/bin/` |
| `baixar-pokemon.py` | `~/.local/share/screensaver-ascii/` |
| `konsole/*` (perfis `Screensaver`, `ScreensaverMini` e o esquema de cores preto) | `~/.local/share/konsole/` |
| `systemd/screensaver.service` (e, com `--bloqueio`, `screensaver-video.*`) | `~/.config/systemd/user/` |

e liga o `screensaver.service`.

## Uso

Depois de instalado não precisa fazer nada: é só largar o PC. Para testar na hora:

```bash
konsole --profile Screensaver --fullscreen -e ~/.local/bin/screensaver-ascii
```

Opções úteis (rodando dentro de um terminal qualquer):

| Opção | O que faz |
|---|---|
| `--cena Nome` | fixa uma cena só (ex.: `--cena Tetris`) |
| `--proxima Nome` | força qual vai ser a próxima cena |
| `--bench` | mede quantos ms cada cena gasta por quadro |
| `--video SAIDA.mp4 --minutos N` | grava o rodízio num vídeo 1920x1080 (sem precisar de terminal) |
| `SS_DURACAO=5` | cada cena dura 5 s (bom pra ver tudo rápido) |
| `SS_OVOS=1` | modo demo dos easter eggs |
| `SS_DEBUG=1` | mostra no stderr por que ele saiu |

Exemplo: `SS_DURACAO=6 screensaver-ascii --cena Clawd`.

## Como funciona

- O `screensaver.service` roda `swayidle -w timeout 150 screensaver-iniciar resume screensaver-parar`.
  Ou seja: **2min30** parado, abre o Konsole em tela cheia com o perfil `Screensaver`; mexeu, fecha.
- O **bloqueio de tela continua sendo do KDE**, no tempo que estiver em *Configurações › Tela de bloqueio*
  (deixe maior que 2min30, senão bloqueia antes do screensaver aparecer). Quando a tela bloqueia, o screensaver
  percebe (via `org.freedesktop.ScreenSaver`) e sai sozinho.
- Os tempos de desligar a tela/suspender ficam em *Configurações › Energia*; ajuste do seu jeito.
- Com `--bloqueio`, a tela de bloqueio usa o plugin Smart Video Wallpaper Reborn tocando
  `~/.local/share/screensaver-ascii/bloqueio.mp4` em loop. O instalador grava isso no `~/.config/kscreenlockerrc`
  com `kwriteconfig6`. Sempre que o screensaver entra e o vídeo tem mais de 20h, um vídeo novo é gerado em
  prioridade mínima (`screensaver-video.service`). Também dá para usar o timer diário:
  `systemctl --user enable --now screensaver-video.timer`.

### "Access denied" do Konsole (é normal)

A cena de Pokémon roda na resolução do GBA, então durante ela o screensaver troca a fonte do Konsole para o perfil
`ScreensaverMini` via D-Bus (`org.kde.konsole.Session.setProfile`). O Konsole responde **`AccessDenied`** (essa API
fica marcada como "sensível" e desligada), **mas aplica a troca mesmo assim**. O programa confirma pela mudança de
tamanho do terminal e ignora o erro. Se a troca não acontecer, a cena é pulada.

## Pokémon: sprites baixados por você

Nenhum sprite vem neste repositório. O `baixar-pokemon.py` (rodado por `./instalar.sh --pokemon`) baixa os sprites
de FireRed/LeafGreen dos 151 de Kanto da [PokeAPI](https://pokeapi.co/) **na sua máquina** e monta o cache
`~/.local/share/screensaver-ascii/pokemon.json`. Sem esse arquivo, a cena simplesmente não entra no rodízio.

## Desinstalar

```bash
./instalar.sh --desinstalar
rm -rf ~/.local/share/screensaver-ascii   # sprites e vídeo, se quiser
```

Se usou `--bloqueio`, escolha outro fundo em *Configurações › Tela de bloqueio*.

Na mão: `systemctl --user disable --now screensaver.service screensaver-video.timer` e apague os arquivos da tabela
de instalação.

## Aviso

Projeto de fã, sem fins lucrativos. **Não é afiliado, patrocinado ou endossado** pela Nintendo, Game Freak,
Creatures Inc. ou The Pokémon Company, nem pela Anthropic. Pokémon e seus personagens são marcas das respectivas
donas; Claude, Claude Code e o Clawd são da Anthropic. O código é MIT (veja `LICENSE`); isso não cobre nenhum
material de terceiros que o script baixa.

---

## English

**screensaver-ascii** is a terminal screensaver for KDE Plasma 6 (Wayland) on Fedora, in pure Python. After 2.5
minutes idle, `swayidle` opens a fullscreen Konsole that cycles through 18 animated ASCII/half-block scenes (Matrix,
plasma, tunnel, starfield, fire, ripples, Game of Life, spinning donut, hacker hex, synthwave, a FireRed-style
Pokémon battle, four Claude Code mascot scenes, self-playing Tetris, bouncing DVD logo, raycaster maze) with glitchy
dissolve transitions. Any input closes it. Optionally the same show is rendered into a video and used as the
lock-screen background via the Smart Video Wallpaper Reborn plugin. There are rare, silly easter eggs
(`SS_OVOS=1` to see them).

Install: `./instalar.sh` (`--pokemon` downloads sprites from PokeAPI on your own machine; `--bloqueio` sets up the
lock-screen video; `--desinstalar` removes it). Requires `python3`, `konsole`, `swayidle`; Hack Nerd Font Mono is
recommended. Code and comments are in Portuguese.

Fan project, not affiliated with Nintendo, Game Freak, The Pokémon Company or Anthropic. No sprites are
distributed here. MIT licensed.
