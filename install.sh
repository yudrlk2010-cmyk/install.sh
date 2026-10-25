#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# ROBLOX REMOTE
# ==========================================

FIRESTORE_URL="https://firestore.googleapis.com/v1/projects/kernel-system-key-bd527/databases/(default)/documents:runQuery"

# Cores
VERDE="\033[1;32m"
VERMELHO="\033[1;31m"
AZUL="\033[1;34m"
AMARELO="\033[1;33m"
CIANO="\033[1;36m"
RESET="\033[0m"

# --- TELA 1: INSTALAÇÃO E CONEXÃO ---
clear
echo -e "${CIANO}=================================================="
echo -e "                 ROBLOX REMOTE"
echo -e "==================================================${RESET}"
echo -e "${AMARELO}Instalando dependencias...${RESET}"
pkg update -y > /dev/null 2>&1
pkg install android-tools -y > /dev/null 2>&1
echo -e "${VERDE}[OK] Dependencias instaladas!${RESET}\n"
sleep 1

echo -e "${CIANO}=================================================="
echo -e "             CONECTE SEU DISPOSITIVO"
echo -e "==================================================${RESET}"

while true; do
    echo -e "${AMARELO}IP, Porta e Codigo (6 digitos):${RESET}"
    read -p "> " IP_PORTA
    adb pair $IP_PORTA

    echo -e "\n${AMARELO}IP e Porta (abaixo do nome do dispositivo):${RESET}"
    read -p "> " IP_CONEXAO
    adb connect $IP_CONEXAO

    if adb devices | grep -q "device$"; then
        echo -e "\n${VERDE}[OK] Dispositivo conectado com sucesso!${RESET}"
        sleep 2
        break
    else
        echo -e "\n${VERMELHO}[ERRO] Falha na conexao. Verifique e tente novamente.${RESET}\n"
        sleep 2
    fi
done

# --- TELA 2: VALIDAÇÃO DA KEY ---
clear
echo -e "${CIANO}=================================================="
echo -e "                 ROBLOX REMOTE"
echo -e "==================================================${RESET}"
echo -e "${AMARELO}Digite sua Key de acesso:${RESET}"
read -p "> " USER_KEY

echo -e "\n${AMARELO}Verificando Key no servidor...${RESET}"

HWID=$(adb shell settings get secure android_id | tr -d '\r')

if [ -z "$HWID" ] || [[ "$HWID" == *"error"* ]]; then
    echo -e "${VERMELHO}[ERRO] Nao foi possivel ler o HWID. Tente novamente.${RESET}"
    read -p "Pressione Enter para sair..."
    exit 1
fi

RESPOSTA=$(curl -s -X POST "$FIRESTORE_URL" -H "Content-Type: application/json" -d "{\"structuredQuery\":{\"from\":[{\"collectionId\":\"keys\"}],\"where\":{\"fieldFilter\":{\"field\":{\"fieldPath\":\"key\"},\"op\":\"EQUAL\",\"value\":{\"stringValue\":\"$USER_KEY\"}}}}}")

if [[ "$RESPOSTA" == "[]" || "$RESPOSTA" == *"NOT_FOUND"* ]]; then
    echo -e "${VERMELHO}[ERRO] Key invalida ou nao encontrada!${RESET}"
    read -p "Pressione Enter para sair..."
    exit 1
fi

DOC_ID=$(echo "$RESPOSTA" | grep -o '"name": "[^"]*"' | cut -d'/' -f7 | tr -d '"')

if [[ "$RESPOSTA" == *'"stringValue": "livre"'* ]]; then
    curl -s -X PATCH "https://firestore.googleapis.com/v1/projects/kernel-system-key-bd527/databases/(default)/documents/keys/$DOC_ID?updateMask.fieldPaths=hwid&updateMask.fieldPaths=status" \
    -H "Content-Type: application/json" \
    -d "{\"fields\": {\"hwid\": {\"stringValue\": \"$HWID\"}, \"status\": {\"stringValue\": \"usada\"}}}" > /dev/null
    echo -e "${VERDE}[OK] Key autenticada e registrada neste aparelho!${RESET}"
    sleep 2
elif [[ "$RESPOSTA" == *"\"stringValue\": \"$HWID\""* ]]; then
    EXPIRA_RAW=$(echo "$RESPOSTA" | grep -o '"expiresAt": {[^}]*}' | grep -o '"timestampValue": "[^"]*"' | cut -d'"' -f4)
    if [[ -z "$EXPIRA_RAW" || "$EXPIRA_RAW" == "null" ]]; then
        echo -e "${VERDE}[OK] Key validada com sucesso!${RESET}"
        sleep 2
    else
        EXPIRA_FORMATADA=$(echo "$EXPIRA_RAW" | sed 's/T/ /; s/\..*//')
        DATA_ATUAL=$(date -u +"%Y-%m-%d %H:%M:%S")
        if [[ "$DATA_ATUAL" > "$EXPIRA_FORMATADA" ]]; then
            echo -e "${VERMELHO}[ERRO] Esta Key expirou!${RESET}"
            read -p "Pressione Enter para sair..."
            exit 1
        else
            echo -e "${VERDE}[OK] Key validada para este aparelho!${RESET}"
            sleep 2
        fi
    fi
else
    echo -e "${VERMELHO}[ERRO] Esta Key ja foi usada em outro aparelho.${RESET}"
    read -p "Pressione Enter para sair..."
    exit 1
fi

# --- TELA 3: PAINEL PRINCIPAL ---
while true; do
    clear
    echo -e "${CIANO}=================================================="
    echo -e "                 ROBLOX REMOTE"
    echo -e "==================================================${RESET}"
    echo -e " ${VERDE}[1]${RESET} Start Remote (Ativar Overlay)"
    echo -e " ${VERMELHO}[2]${RESET} Bypass (Remover VPN + Overlay)"
    echo -e " ${AMARELO}[3]${RESET} Sair"
    echo -e "${CIANO}--------------------------------------------------${RESET}"
    read -p "Escolha uma opcao: " OPCAO

    case $OPCAO in
        1)
            clear
            echo -e "${AMARELO}Iniciando Overlay Remoto...${RESET}"
            adb shell appops set com.vortexia.wire SYSTEM_ALERT_WINDOW allow
            adb shell am start-foreground-service -n com.vortexia.wire/com.vortexia.wire.OverlayService
            echo -e "${VERDE}[OK] Overlay ativado com sucesso!${RESET}"
            sleep 2
            ;;
        2)
            clear
            echo -e "${VERMELHO}=== BYPASS ===${RESET}"
            echo -e "${AMARELO}Removendo VPN e Overlay...${RESET}"
            
            adb shell am force-stop com.vortexia.wire
            adb shell pm clear com.vortexia.wire > /dev/null 2>&1
            adb shell am force-stop com.dts.freefireth > /dev/null 2>&1
            
            echo -e "${VERDE}[OK] VPN removida e aplicativos fechados!${RESET}"
            echo -e "${AMARELO}Fechando Termux...${RESET}"
            sleep 2
            exit 0 # Fecha o Termux automaticamente
            ;;
        3)
            echo -e "${AMARELO}Saindo...${RESET}"
            exit 0
            ;;
        *)
            echo -e "${VERMELHO}Opcao invalida! Tente novamente.${RESET}"
            sleep 1
            ;;
    esac
done
