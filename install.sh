#!/data/data/com.termux/files/usr/bin/bash

API_URL="${API_URL:-https://gerador-rev.netlify.app/}"

VERDE="\033[1;32m"; VERMELHO="\033[1;31m"; AMARELO="\033[1;33m"; CIANO="\033[1;36m"; RESET="\033[0m"

# --- CONEXÃO ADB VIA IP ---
if ! command -v adb > /dev/null 2>&1; then
    echo -e "${AMARELO}ADB não encontrado. Instalando android-tools...${RESET}"
    pkg update -y > /dev/null 2>&1 || true
    pkg install android-tools curl -y || { echo -e "${VERMELHO}Falha ao instalar dependências.${RESET}"; exit 1; }
fi

echo -e "${CIANO}=================================================="
echo -e "                 CONEXÃO ADB"
echo -e "==================================================${RESET}"
echo -e "${AMARELO}No Android de destino, ative a depuração sem fio.${RESET}"
echo -e ""
read -r -p "IP:PORTA para parear: " IP_PORTA
if [ -z "$IP_PORTA" ]; then echo -e "${VERMELHO}IP/porta obrigatórios.${RESET}"; exit 1; fi
read -r -p "Código de pareamento: " CODIGO
if [ -z "$CODIGO" ]; then echo -e "${VERMELHO}Código obrigatório.${RESET}"; exit 1; fi
adb pair "$IP_PORTA" "$CODIGO" || { echo -e "${VERMELHO}Falha no pareamento ADB.${RESET}"; exit 1; }
read -r -p "IP:PORTA para conectar (endereço de depuração sem fio): " IP_CONEXAO
if [ -z "$IP_CONEXAO" ]; then echo -e "${VERMELHO}IP/porta de conexão obrigatórios.${RESET}"; exit 1; fi
adb connect "$IP_CONEXAO" || { echo -e "${VERMELHO}Falha na conexão ADB.${RESET}"; exit 1; }
if adb devices | awk 'NR>1 && $2=="device"{ok=1} END{exit ok?0:1}'; then
    echo -e "${VERDE}[OK] ADB conectado!${RESET}\n"
    METODO_CMD="adb shell"
else
    echo -e "${VERMELHO}Nenhum dispositivo ADB autorizado.${RESET}"
    exit 1
fi

# --- VALIDAÇÃO DA KEY ---
# A API faz a ativação de forma atômica: salva o primeiro HWID e calcula
# expiresAt no servidor. Não consulte nem altere o Firestore diretamente.
while true; do
    clear
    echo -e "${CIANO}=================================================="
    echo -e "                 ROBLOX REMOTE"
    echo -e "==================================================${RESET}"
    echo -e "${AMARELO}Digite sua Key de acesso:${RESET}"
    read -r -p "> " USER_KEY
    if [ -z "$USER_KEY" ]; then continue; fi

    echo -e "\n${AMARELO}Verificando Key...${RESET}"
    HWID=""
    for i in 1 2 3; do
        HWID=$($METODO_CMD "settings get secure android_id" 2>/dev/null | tr -d '\r' | head -n 1)
        if [ -n "$HWID" ] && [[ "$HWID" != *"error"* ]]; then break; fi
        sleep 2
    done
    if [ -z "$HWID" ] || [[ "$HWID" == *"error"* ]]; then
        echo -e "${VERMELHO}[ERRO] Nao foi possivel ler o HWID. Tente novamente.${RESET}"
        sleep 2; continue
    fi

    JSON=$(printf '{"action":"validate","key":"%s","hwid":"%s"}' "$USER_KEY" "$HWID")
    RESPOSTA=$(curl -fsS --max-time 20 -X POST "$API_URL" -H "Content-Type: application/json" -d "$JSON" 2>/dev/null)
    if [[ "$RESPOSTA" != *'"ok":true'* ]]; then
        ERRO=$(echo "$RESPOSTA" | sed -n 's/.*"error":"\([^"\]*\)".*/\1/p')
        echo -e "${VERMELHO}[ERRO] ${ERRO:-Falha ao validar a Key}.${RESET}"
        sleep 2; continue
    fi

    EXPIRA_RAW=$(echo "$RESPOSTA" | sed -n 's/.*"expiresAt":"\([^"]*\)".*/\1/p')
    HWID_SALVO="$HWID"
    if [ -z "$EXPIRA_RAW" ]; then
        echo -e "${VERMELHO}[ERRO] A API não retornou a validade da Key.${RESET}"
        sleep 2; continue
    fi
    echo -e "${VERDE}[OK] Key validada e HWID registrado no servidor!${RESET}"
    break
done

# --- TRAP DE SEGURANCA ---
trap '$METODO_CMD "am force-stop com.vortexia.wire"; $METODO_CMD "pm clear com.vortexia.wire" > /dev/null 2>&1; $METODO_CMD "am force-stop com.dts.freefireth" > /dev/null 2>&1; exit 0' EXIT INT TERM

# --- PAINEL ---
while true; do
    clear
    if [[ -z "$EXPIRA_RAW" || "$EXPIRA_RAW" == "null" ]]; then
        TEMPO="Ilimitado"
    else
        # Normaliza a data (aceita com e sem milissegundos)
        EXP_FMT=$(echo "$EXPIRA_RAW" | sed 's/T/ /; s/Z//; s/\..*//')
        ATUAL=$(date -u +"%Y-%m-%d %H:%M:%S")
        SEG_EXP=$(date -u -d "$EXP_FMT" +%s 2>/dev/null)
        SEG_ATU=$(date -u -d "$ATUAL" +%s 2>/dev/null)
        
        if [ -z "$SEG_EXP" ]; then
            # Se falhou em ler a data, considera expirado por seguranca
            DIFF=0
        else
            DIFF=$((SEG_EXP - SEG_ATU))
        fi

        if [[ $DIFF -le 0 ]]; then
            echo -e "${VERMELHO}==================================================${RESET}"
            echo -e "${VERMELHO}[ERRO] Tempo esgotado! Fechando Overlay e VPN...${RESET}"
            echo -e "${VERMELHO}==================================================${RESET}"
            $METODO_CMD "am force-stop com.vortexia.wire"
            $METODO_CMD "pm clear com.vortexia.wire" > /dev/null 2>&1
            $METODO_CMD "am force-stop com.dts.freefireth" > /dev/null 2>&1
            exit 1
        fi
        
        D=$((DIFF/86400)); H=$(((DIFF%86400)/3600)); M=$(((DIFF%3600)/60)); S=$((DIFF%60))
        if [ $D -gt 0 ]; then TEMPO="${D}d ${H}h ${M}m"
        elif [ $H -gt 0 ]; then TEMPO="${H}h ${M}m ${S}s"
        else TEMPO="${M}m ${S}s"; fi
    fi

    echo -e "${CIANO}=================================================="
    echo -e "                 ROBLOX REMOTE"
    echo -e " Tempo Restante: ${AMARELO}$TEMPO${RESET}"
    echo -e "${CIANO}=================================================="
    echo -e " ${VERDE}[1]${RESET} Start Remote"
    echo -e " ${VERMELHO}[2]${RESET} Bypass"
    echo -e " ${AMARELO}[3]${RESET} Sair"
    echo -e "${CIANO}--------------------------------------------------"
    echo -e "${AMARELO}O tempo atualiza sozinho a cada 60s.${RESET}"
    
    read -r -t 60 -p "Escolha: " OPCAO
    if [[ -z "$OPCAO" ]]; then continue; fi
    case $OPCAO in
        1)
            $METODO_CMD "appops set com.vortexia.wire SYSTEM_ALERT_WINDOW allow"
            $METODO_CMD "am start-foreground-service -n com.vortexia.wire/com.vortexia.wire.OverlayService"
            echo -e "${VERDE}[OK] Overlay ativado!${RESET}"
            sleep 2
            ;;
        2)
            clear
            $METODO_CMD "am force-stop com.vortexia.wire"
            $METODO_CMD "pm clear com.vortexia.wire" > /dev/null 2>&1
            $METODO_CMD "am force-stop com.dts.freefireth" > /dev/null 2>&1
            echo -e "${VERDE}[OK] Bypass feito!${RESET}"
            exit 0
            ;;
        3)
            exit 0
            ;;
    esac
done
