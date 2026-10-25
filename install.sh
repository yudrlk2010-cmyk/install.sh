#!/data/data/com.termux/files/usr/bin/bash
# Baixa sempre a versão atual do core.sh no Gist, sem prender em uma revisão antiga.
exec bash <(curl -fsSL "https://gist.githubusercontent.com/yudrlk2010-cmyk/e573323734d0f9f8cbcfd5e4d9a54862/raw/e3056ff07cced7a2bb01ea518ef31a900a00787d/core.sh?cache=$(date +%s)")
