#!/bin/bash
# Instalador do screensaver-ascii (Fedora + KDE Plasma 6 no Wayland, com Konsole).
# Pode rodar quantas vezes quiser: só copia arquivos e (re)liga o serviço.
#
#   ./instalar.sh              instala o screensaver
#   ./instalar.sh --pokemon    + baixa os sprites pra cena de Pokémon (precisa de internet e python3-pillow)
#   ./instalar.sh --bloqueio   + gera o vídeo e põe ele de fundo na tela de bloqueio
#   ./instalar.sh --desinstalar
set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
DADOS="$HOME/.local/share/screensaver-ascii"
KONSOLE="$HOME/.local/share/konsole"
UNIDADES="$HOME/.config/systemd/user"
VIDEO="$DADOS/bloqueio.mp4"
PLUGIN="luisbocanegra.smart.video.wallpaper.reborn"

POKEMON=0
BLOQUEIO=0
DESINSTALAR=0
for arg in "$@"; do
  case "$arg" in
    --pokemon) POKEMON=1 ;;
    --bloqueio) BLOQUEIO=1 ;;
    --desinstalar) DESINSTALAR=1 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "opção desconhecida: $arg (veja --help)" >&2; exit 1 ;;
  esac
done

ok()    { printf '  \e[32m✓\e[0m %s\n' "$*"; }
aviso() { printf '  \e[33m!\e[0m %s\n' "$*"; }
erro()  { printf '  \e[31m✗\e[0m %s\n' "$*" >&2; }
tem()   { command -v "$1" >/dev/null 2>&1; }

if [ "$DESINSTALAR" = 1 ]; then
  echo "Desinstalando…"
  systemctl --user disable --now screensaver.service screensaver-video.timer 2>/dev/null || true
  rm -f "$BIN/screensaver-ascii" "$BIN/screensaver-iniciar" "$BIN/screensaver-parar"
  rm -f "$UNIDADES/screensaver.service" "$UNIDADES/screensaver-video.service" "$UNIDADES/screensaver-video.timer"
  rm -f "$KONSOLE/Screensaver.profile" "$KONSOLE/ScreensaverMini.profile" "$KONSOLE/ScreensaverPreto.colorscheme"
  systemctl --user daemon-reload
  ok "programas, perfis do Konsole e serviços removidos"
  aviso "$DADOS (sprites/vídeo) ficou; apague na mão se quiser: rm -rf $DADOS"
  aviso "se usou --bloqueio, volte o fundo da tela de bloqueio em Configurações › Tela de bloqueio"
  exit 0
fi

echo "Conferindo dependências…"
falta=0
tem python3 && ok "python3" || { erro "python3 não encontrado"; falta=1; }
tem konsole && ok "konsole" || { erro "konsole não encontrado (sudo dnf install konsole)"; falta=1; }
tem swayidle && ok "swayidle" || { erro "swayidle não encontrado: sudo dnf install swayidle"; falta=1; }
tem gdbus && ok "gdbus" || aviso "gdbus não encontrado: a troca de fonte na cena de Pokémon não vai funcionar"
if fc-list 2>/dev/null | grep -qi "Hack Nerd Font Mono"; then
  ok "Hack Nerd Font Mono"
else
  aviso "Hack Nerd Font Mono não encontrada: funciona com outra fonte, mas fica mais bonito com ela"
  aviso "  baixe em https://www.nerdfonts.com/font-downloads (Hack) e extraia em ~/.local/share/fonts/HackNerdFont/"
fi
[ "$falta" = 1 ] && { erro "instale o que falta e rode de novo"; exit 1; }

echo "Copiando arquivos…"
mkdir -p "$BIN" "$DADOS" "$KONSOLE" "$UNIDADES"
install -m 755 "$AQUI/screensaver-ascii" "$AQUI/screensaver-iniciar" "$AQUI/screensaver-parar" "$BIN/"
install -m 755 "$AQUI/baixar-pokemon.py" "$DADOS/"
install -m 644 "$AQUI"/konsole/* "$KONSOLE/"
install -m 644 "$AQUI/systemd/screensaver.service" "$UNIDADES/"
ok "programas em $BIN, perfis em $KONSOLE"

systemctl --user daemon-reload
systemctl --user enable screensaver.service >/dev/null 2>&1
systemctl --user restart screensaver.service
ok "screensaver.service ligado (entra depois de 2min30 parado)"

if [ "$POKEMON" = 1 ]; then
  echo "Baixando sprites de Pokémon (PokeAPI)…"
  if python3 -c "import PIL" 2>/dev/null; then
    python3 "$DADOS/baixar-pokemon.py" && ok "cena de Pokémon liberada"
  else
    erro "precisa do Pillow: sudo dnf install python3-pillow"
  fi
fi

if [ "$BLOQUEIO" = 1 ]; then
  echo "Configurando o vídeo da tela de bloqueio…"
  pronto=1
  if ! tem ffmpeg || ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -q libx264; then
    erro "precisa do ffmpeg com libx264 (o do RPM Fusion: sudo dnf swap ffmpeg-free ffmpeg --allowerasing)"
    pronto=0
  fi
  python3 -c "import PIL" 2>/dev/null || { erro "precisa do Pillow: sudo dnf install python3-pillow"; pronto=0; }
  tem kwriteconfig6 || { erro "kwriteconfig6 não encontrado (vem com o Plasma 6)"; pronto=0; }
  if [ ! -d "/usr/share/plasma/wallpapers/$PLUGIN" ] && [ ! -d "$HOME/.local/share/plasma/wallpapers/$PLUGIN" ]; then
    erro "falta o plugin Smart Video Wallpaper Reborn: sudo dnf install plasma-smart-video-wallpaper-reborn"
    pronto=0
  fi
  if [ "$pronto" = 1 ]; then
    install -m 644 "$AQUI/systemd/screensaver-video.service" "$AQUI/systemd/screensaver-video.timer" "$UNIDADES/"
    systemctl --user daemon-reload
    if [ ! -f "$VIDEO" ]; then
      aviso "gerando um vídeo de 25 min em prioridade mínima (demora, roda em segundo plano)"
      aviso "  acompanhe com: journalctl --user -fu screensaver-video.service"
      systemctl --user start --no-block screensaver-video.service
    fi
    G=(--file kscreenlockerrc --group Greeter)
    W=("${G[@]}" --group Wallpaper --group "$PLUGIN" --group General)
    kwriteconfig6 "${G[@]}" --key WallpaperPlugin "$PLUGIN"
    kwriteconfig6 "${W[@]}" --key VideoUrls \
      "[{\"filename\":\"file://$VIDEO\",\"enabled\":true,\"duration\":0,\"customDuration\":0,\"playbackRate\":0.0,\"loop\":true}]"
    kwriteconfig6 "${W[@]}" --key FillMode 2
    kwriteconfig6 "${W[@]}" --key ResumeLastVideo false
    ok "tela de bloqueio aponta pra $VIDEO"
    aviso "o vídeo é refeito sozinho quando o screensaver entra e ele tem mais de 20h"
    aviso "  (ou ligue o timer diário: systemctl --user enable --now screensaver-video.timer)"
  fi
fi

echo
echo "Pronto! Teste agora com:  konsole --profile Screensaver --fullscreen -e ~/.local/bin/screensaver-ascii"
[ -f "$DADOS/pokemon.json" ] || echo "Dica: ./instalar.sh --pokemon libera a cena de batalha Pokémon."
