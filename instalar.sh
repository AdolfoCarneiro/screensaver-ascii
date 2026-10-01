#!/bin/bash
# Instalador do screensaver-ascii (Fedora, Arch/CachyOS, Omarchy, Debian/Ubuntu; KDE Plasma ou Hyprland).
# Pode rodar quantas vezes quiser: só copia arquivos e (re)liga o gatilho de ociosidade.
#
#   ./instalar.sh              instala o screensaver
#   ./instalar.sh --pokemon    + baixa os sprites pra cena de Pokémon (precisa de internet e do Pillow)
#   ./instalar.sh --bloqueio   + gera o vídeo e põe ele de fundo na tela de bloqueio (só KDE Plasma 6)
#   ./instalar.sh --hypridle   usa o hypridle (padrão no Hyprland) em vez do swayidle
#   ./instalar.sh --swayidle   usa o swayidle mesmo no Hyprland
#   ./instalar.sh --desinstalar
set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
DADOS="$HOME/.local/share/screensaver-ascii"
KONSOLE="$HOME/.local/share/konsole"
UNIDADES="$HOME/.config/systemd/user"
HYPR="$HOME/.config/hypr"
HYPRIDLE="$HYPR/hypridle.conf"
HYPRLAND="$HYPR/hyprland.conf"
VIDEO="$DADOS/bloqueio.mp4"
PLUGIN="luisbocanegra.smart.video.wallpaper.reborn"
INICIO="# >>> screensaver-ascii"
FIM="# <<< screensaver-ascii"
DESLIGADO="# (screensaver-ascii) "

POKEMON=0
BLOQUEIO=0
DESINSTALAR=0
IDLE=""
for arg in "$@"; do
  case "$arg" in
    --pokemon) POKEMON=1 ;;
    --bloqueio) BLOQUEIO=1 ;;
    --desinstalar) DESINSTALAR=1 ;;
    --hypridle) IDLE=hypridle ;;
    --swayidle) IDLE=swayidle ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "opção desconhecida: $arg (veja --help)" >&2; exit 1 ;;
  esac
done

ok()    { printf '  \e[32m✓\e[0m %s\n' "$*"; }
aviso() { printf '  \e[33m!\e[0m %s\n' "$*"; }
erro()  { printf '  \e[31m✗\e[0m %s\n' "$*" >&2; }
tem()   { command -v "$1" >/dev/null 2>&1; }

# pergunta "texto" [s|n]: o segundo argumento é a resposta padrão (Enter, ou quando não tem terminal pra perguntar)
pergunta() {
  local padrao="${2:-n}" r opcoes="[s/N]"
  [ "$padrao" = s ] && opcoes="[S/n]"
  if [ ! -t 0 ]; then
    [ "$padrao" = s ]
    return
  fi
  read -r -p "  ? $1 $opcoes " r || r=""
  [ -z "$r" ] && r="$padrao"
  [[ "$r" =~ ^[sSyY] ]]
}

# ---------------------------------------------------------------- onde estamos

if tem pacman; then DISTRO=arch
elif tem dnf; then DISTRO=fedora
elif tem apt-get; then DISTRO=debian
else DISTRO=outra
fi

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || [[ "${XDG_CURRENT_DESKTOP:-}" == *Hyprland* ]]; then
  DESKTOP=hyprland
elif [[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* ]]; then
  DESKTOP=kde
else
  DESKTOP="${XDG_CURRENT_DESKTOP:-desconhecido}"
fi
OMARCHY=0
[ -d "$HOME/.local/share/omarchy" ] && OMARCHY=1

# mesmo critério do screensaver-iniciar
escolher_terminal() {
  if [ -n "${SCREENSAVER_TERMINAL:-}" ]; then echo "$SCREENSAVER_TERMINAL"; return; fi
  if [ "$DESKTOP" = kde ] && tem konsole; then echo konsole; return; fi
  for t in alacritty kitty ghostty foot wezterm konsole; do
    tem "$t" && { echo "$t"; return; }
  done
  return 0
}

# nome do pacote em cada distro: pacote <coisa>
pacote() {
  case "$DISTRO:$1" in
    arch:python) echo python ;;
    *:python) echo python3 ;;
    *:swayidle) echo swayidle ;;
    *:hypridle) echo hypridle ;;
    arch:pillow) echo python-pillow ;;
    fedora:pillow) echo python3-pillow ;;
    debian:pillow) echo python3-pil ;;
    arch:fonte) echo ttf-hack-nerd ;;
    debian:fonte) echo fonts-hack ;;
    fedora:fonte) echo "" ;;   # não tem no repositório: baixar do nerdfonts.com
    *:ffmpeg) echo ffmpeg ;;
    *:terminal) [ "$DESKTOP" = kde ] && echo konsole || echo alacritty ;;
    *) echo "" ;;
  esac
}

# oferece instalar os pacotes (sempre pergunta antes de usar sudo)
instalar_pacotes() {
  [ "$#" = 0 ] && return 0
  local cmd
  case "$DISTRO" in
    arch) cmd=(sudo pacman -S --needed "$@") ;;
    fedora) cmd=(sudo dnf install "$@") ;;
    debian) cmd=(sudo apt-get install "$@") ;;
    *) aviso "instale pelo gerenciador de pacotes da sua distro: $*"; return 0 ;;
  esac
  aviso "falta: $*  →  ${cmd[*]}"
  if pergunta "Rodar esse comando agora?" n; then
    "${cmd[@]}" || erro "a instalação falhou"
  fi
}

# tira os blocos que o instalador pôs nos arquivos do Hyprland e religa o screensaver do Omarchy
limpar_hypr() {
  local f
  for f in "$HYPRIDLE" "$HYPRLAND"; do
    [ -f "$f" ] || continue
    if grep -qF "$INICIO" "$f" || grep -qF "$DESLIGADO" "$f"; then
      sed -i -e "/^$INICIO\$/,/^$FIM\$/d" -e "s/^$DESLIGADO//" "$f"
      ok "removido de $f"
    fi
  done
}

if [ "$BLOQUEIO" = 1 ] && [ "$DESKTOP" != kde ] && [ "$DESINSTALAR" = 0 ]; then
  erro "--bloqueio só funciona no KDE Plasma 6 (usa a tela de bloqueio do Plasma e o plugin Smart Video Wallpaper Reborn)"
  erro "aqui o desktop é: $DESKTOP. Rode sem --bloqueio."
  exit 1
fi

if [ "$DESINSTALAR" = 1 ]; then
  echo "Desinstalando…"
  systemctl --user disable --now screensaver.service screensaver-video.timer 2>/dev/null || true
  rm -f "$BIN/screensaver-ascii" "$BIN/screensaver-iniciar" "$BIN/screensaver-parar"
  rm -f "$UNIDADES/screensaver.service" "$UNIDADES/screensaver-video.service" "$UNIDADES/screensaver-video.timer"
  rm -f "$KONSOLE/Screensaver.profile" "$KONSOLE/ScreensaverMini.profile" "$KONSOLE/ScreensaverPreto.colorscheme"
  systemctl --user daemon-reload 2>/dev/null || true
  ok "programas, perfis do Konsole e serviços removidos"
  limpar_hypr
  aviso "$DADOS (sprites/vídeo) ficou; apague na mão se quiser: rm -rf $DADOS"
  aviso "se usou --bloqueio, volte o fundo da tela de bloqueio em Configurações › Tela de bloqueio"
  aviso "se usava o hypridle, reinicie ele pra valer: killall hypridle; hyprctl dispatch exec hypridle"
  exit 0
fi

TERMINAL="$(escolher_terminal)"
if [ -z "$IDLE" ]; then
  if [ "$DESKTOP" = hyprland ]; then IDLE=hypridle; else IDLE=swayidle; fi
fi

echo "Sistema: distro=$DISTRO, desktop=$DESKTOP$([ "$OMARCHY" = 1 ] && echo " (Omarchy)"), terminal=${TERMINAL:-nenhum}, gatilho=$IDLE"
echo "Conferindo dependências…"
faltam=()
tem python3 && ok "python3" || { erro "python3 não encontrado"; faltam+=("$(pacote python)"); }
if [ -n "$TERMINAL" ]; then
  ok "terminal: $TERMINAL"
else
  erro "nenhum terminal suportado (konsole, alacritty, kitty, ghostty, foot, wezterm)"
  faltam+=("$(pacote terminal)")
fi
tem "$IDLE" && ok "$IDLE" || { erro "$IDLE não encontrado"; faltam+=("$(pacote "$IDLE")"); }
fonte_ok=0
fc-list 2>/dev/null | grep -qi "Hack Nerd Font Mono" && fonte_ok=1
if [ "$fonte_ok" = 1 ]; then
  ok "Hack Nerd Font Mono"
else
  aviso "Hack Nerd Font Mono não encontrada: funciona com outra fonte, mas fica mais bonito com ela"
  if [ -n "$(pacote fonte)" ]; then
    faltam+=("$(pacote fonte)")
  else
    aviso "  baixe em https://www.nerdfonts.com/font-downloads (Hack) e extraia em ~/.local/share/fonts/HackNerdFont/"
  fi
fi
if [ "$POKEMON" = 1 ] && ! python3 -c "import PIL" 2>/dev/null; then
  aviso "a cena de Pokémon precisa do Pillow pra baixar os sprites"
  faltam+=("$(pacote pillow)")
fi
case "$TERMINAL" in
  konsole) tem gdbus && ok "gdbus" || aviso "gdbus não encontrado: a troca de fonte na cena de Pokémon não vai funcionar" ;;
  kitty|alacritty) ok "$TERMINAL troca a fonte sozinho na cena de Pokémon" ;;
  "") ;;
  *) aviso "$TERMINAL não troca a fonte com o programa rodando: a cena de Pokémon só entra se a tela já tiver 240x80 células" ;;
esac
if [ "${#faltam[@]}" -gt 0 ]; then
  instalar_pacotes "${faltam[@]}"
  [ -z "$TERMINAL" ] && TERMINAL="$(escolher_terminal)"
fi
falta=0
tem python3 || { erro "ainda falta o python3"; falta=1; }
[ -n "$TERMINAL" ] || { erro "ainda falta um terminal"; falta=1; }
tem "$IDLE" || { erro "ainda falta o $IDLE"; falta=1; }
[ "$falta" = 1 ] && { erro "instale o que falta e rode de novo"; exit 1; }

echo "Copiando arquivos…"
mkdir -p "$BIN" "$DADOS"
install -m 755 "$AQUI/screensaver-ascii" "$AQUI/screensaver-iniciar" "$AQUI/screensaver-parar" "$BIN/"
install -m 755 "$AQUI/baixar-pokemon.py" "$DADOS/"
ok "programas em $BIN"
if tem konsole; then
  mkdir -p "$KONSOLE"
  install -m 644 "$AQUI"/konsole/* "$KONSOLE/"
  ok "perfis do Konsole em $KONSOLE"
fi

if [ "$IDLE" = swayidle ]; then
  mkdir -p "$UNIDADES"
  install -m 644 "$AQUI/systemd/screensaver.service" "$UNIDADES/"
  systemctl --user daemon-reload
  systemctl --user enable screensaver.service >/dev/null 2>&1
  systemctl --user restart screensaver.service
  ok "screensaver.service ligado (swayidle; entra depois de 2min30 parado)"
  if [ "$DESKTOP" = hyprland ]; then
    aviso "no Hyprland o serviço depende do graphical-session.target (ok com uwsm, como no Omarchy)"
  fi
else
  # hypridle: o screensaver vira um listener no hypridle.conf (e o swayidle fica desligado)
  if systemctl --user is-enabled screensaver.service >/dev/null 2>&1; then
    systemctl --user disable --now screensaver.service >/dev/null 2>&1 || true
    aviso "screensaver.service (swayidle) desligado: quem chama agora é o hypridle"
  fi
  mkdir -p "$HYPR"
  if [ -f "$HYPRIDLE" ] && grep -qF "$INICIO" "$HYPRIDLE"; then
    ok "hypridle.conf já tem o screensaver"
  elif pergunta "Adicionar o screensaver no $HYPRIDLE (entra depois de 2min30 parado)?" s; then
    cat >> "$HYPRIDLE" <<EOF

$INICIO
listener {
    timeout = 150
    on-timeout = $BIN/screensaver-iniciar
    on-resume = $BIN/screensaver-parar
}
$FIM
EOF
    ok "listener adicionado em $HYPRIDLE"
  else
    aviso "não mexi no hypridle.conf; o bloco pra colar está no README (seção Hyprland)"
  fi
  # Omarchy (ou quem copiou a config dele) já tem um screensaver no mesmo tempo: os dois abririam juntos
  if [ -f "$HYPRIDLE" ] && grep -v "^$DESLIGADO" "$HYPRIDLE" | grep -q "omarchy-launch-screensaver"; then
    aviso "seu hypridle.conf também chama o screensaver do Omarchy (omarchy-launch-screensaver)"
    if pergunta "Comentar o listener do Omarchy pra usar só este? (o --desinstalar desfaz)" n; then
      awk -v pre="$DESLIGADO" '
        /^[[:space:]]*listener[[:space:]]*\{/ { bloco = 1; buf = $0 "\n"; tem = 0; next }
        bloco { buf = buf $0 "\n"; if ($0 ~ /omarchy-launch-screensaver/) tem = 1
                if ($0 ~ /^[[:space:]]*\}/) { n = split(buf, l, "\n")
                  for (i = 1; i < n; i++) print (tem ? pre : "") l[i]
                  bloco = 0 }
                next }
        { print }
        END { if (bloco) printf "%s", buf }' "$HYPRIDLE" > "$HYPRIDLE.tmp" && mv "$HYPRIDLE.tmp" "$HYPRIDLE"
      ok "listener do Omarchy comentado"
    else
      aviso "comente na mão o listener com omarchy-launch-screensaver, senão os dois abrem juntos"
    fi
  fi
  if systemctl --user is-active hypridle.service >/dev/null 2>&1; then
    systemctl --user restart hypridle.service && ok "hypridle reiniciado"
  else
    aviso "reinicie o hypridle pra ler a config nova: killall hypridle; hyprctl dispatch exec hypridle"
  fi
fi

if [ "$DESKTOP" = hyprland ] && [ -f "$HYPRLAND" ]; then
  if grep -qF "$INICIO" "$HYPRLAND"; then
    ok "hyprland.conf já tem as regras de janela do screensaver"
  elif pergunta "Adicionar regras de janela (tela cheia, opaca, sem animação) no $HYPRLAND?" n; then
    cat >> "$HYPRLAND" <<EOF

$INICIO
windowrulev2 = fullscreen, class:^(.*screensaver-ascii)\$
windowrulev2 = noanim, class:^(.*screensaver-ascii)\$
windowrulev2 = opacity 1.0 override 1.0 override, class:^(.*screensaver-ascii)\$
$FIM
EOF
    ok "regras adicionadas em $HYPRLAND (o Hyprland recarrega sozinho)"
  fi
fi

if [ "$POKEMON" = 1 ]; then
  echo "Baixando sprites de Pokémon (PokeAPI)…"
  if python3 -c "import PIL" 2>/dev/null; then
    python3 "$DADOS/baixar-pokemon.py" && ok "cena de Pokémon liberada"
  else
    erro "precisa do Pillow (pacote: $(pacote pillow))"
  fi
fi

if [ "$BLOQUEIO" = 1 ]; then
  echo "Configurando o vídeo da tela de bloqueio…"
  pronto=1
  if ! tem ffmpeg || ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -q libx264; then
    case "$DISTRO" in
      fedora) erro "precisa do ffmpeg com libx264 (o do RPM Fusion: sudo dnf swap ffmpeg-free ffmpeg --allowerasing)" ;;
      *) erro "precisa do ffmpeg com libx264 (pacote: $(pacote ffmpeg))" ;;
    esac
    pronto=0
  fi
  python3 -c "import PIL" 2>/dev/null || { erro "precisa do Pillow (pacote: $(pacote pillow))"; pronto=0; }
  tem kwriteconfig6 || { erro "kwriteconfig6 não encontrado (vem com o Plasma 6)"; pronto=0; }
  if [ ! -d "/usr/share/plasma/wallpapers/$PLUGIN" ] && [ ! -d "$HOME/.local/share/plasma/wallpapers/$PLUGIN" ]; then
    case "$DISTRO" in
      fedora) erro "falta o plugin Smart Video Wallpaper Reborn: sudo dnf install plasma-smart-video-wallpaper-reborn" ;;
      *) erro "falta o plugin Smart Video Wallpaper Reborn (no AUR, ou pela loja do Plasma: Configurar papel de parede › Baixar novos plugins)" ;;
    esac
    pronto=0
  fi
  if [ "$pronto" = 1 ]; then
    mkdir -p "$UNIDADES"
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
echo "Pronto! Teste agora com:  ~/.local/bin/screensaver-iniciar   (qualquer tecla fecha)"
echo "  outro terminal:          SCREENSAVER_TERMINAL=kitty ~/.local/bin/screensaver-iniciar"
[ -f "$DADOS/pokemon.json" ] || echo "Dica: ./instalar.sh --pokemon libera a cena de batalha Pokémon."
