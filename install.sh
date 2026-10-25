#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# ROBLOX REMOTE
# ==========================================

FIRESTORE_URL="https://firestore.googleapis.com/v1/projects/kernel-system-key-bd527/databases/(default)/documents:runQuery"

VERDE="\033[1;32m"
VERMELHO="\033[1;31m"
AZUL="\033[1;34m"
AMARELO="\033[1;33m"
RESET="\033[0m"

# --- INSTALAÇÃO DO ADB ---
pkg update -y > /dev/null 2>&1
pkg install android-tools -y > /dev/null 2>&1

# --- PAREAMENTO OBRIGATÓRIO ---
clear
echo -e "${AZUL}=================================================="
echo -e "                 ROBLOX REMOTE"
echo -e "==================================================${RESET}"
echo -e "${AMARELO}Pareie seu dispositivo para liberar a tela de inserir a Key.${RESET}\n"

while true; do
    read -p "Digite o IP e a Porta de Pareamento (ex: 192.168.1.7:40000): " IP_PORTA
    adb pair $IP_PORTA
    
    echo -e "\nAgora digite o IP e a Porta de Conexao (ex: 192.168.1.7:5555): "
    read -p "> " IP_CONEXAO
    adb connect $IP_CONEXAO
    
    if adb devices | grep -q "device$"; then
        echo -e "\n${VERDE}[OK] Dispositivo pareado com sucesso!${RESET}"
        sleep 2
        break
    else
        echo -e "\n${VERMELHO}[ERRO] Falha ao parear. Tente novamente.${RESET}"
        sleep 2
    fi
done

# --- VALIDAÇÃO DA KEY ---
clear
echo -e "${AZUL}=================================================="
echo -e "                 ROBLOX REMOTE"
echo -e "==================================================${RESET}"
echo -e "${AMARELO}Digite sua Key de acesso:${RESET}"
read -p "> " USER_KEY

echo -e "\nVerificando Key no servidor..."

HWID=$(adb shell settings get secure android_id | tr -d '\r')

if [ -z "$HWID" ] || [[ "$HWID" == *"error"* ]]; then
    echo -e "${VERMELHO}[ERRO] Nao foi possivel ler o HWID. Tente novamente.${RESET}"
    exit 1
fi

RESPOSTA=$(curl -s -X POST "$FIRESTORE_URL" -H "Content-Type: application/json" -d "{\"structuredQuery\":{\"from\":[{\"collectionId\":\"keys\"}],\"where\":{\"fieldFilter\":{\"field\":{\"fieldPath\":\"key\"},\"op\":\"EQUAL\",\"value\":{\"stringValue\":\"$USER_KEY\"}}}}}")

if [[ "$RESPOSTA" == "[]" || "$RESPOSTA" == *"NOT_FOUND"* ]]; then
    echo -e "${VERMELHO}[ERRO] Key invalida ou nao encontrada!${RESET}"
    exit 1
fi

DOC_ID=$(echo "$RESPOSTA" | grep -o '"name": "[^"]*"' | cut -d'/' -f7 | tr -d '"')

# --- VERIFICAÇÃO DO HWID E EXPIRAÇÃO ---
if [[ "$RESPOSTA" == *'"stringValue": "livre"'* ]]; then
    # Key livre: salva o HWID e marca como usada
    curl -s -X PATCH "https://firestore.googleapis.com/v1/projects/kernel-system-key-bd527/databases/(default)/documents/keys/$DOC_ID?updateMask.fieldPaths=hwid&updateMask.fieldPaths=status" \
    -H "Content-Type: application/json" \
    -d "{\"fields\": {\"hwid\": {\"stringValue\": \"$HWID\"}, \"status\": {\"stringValue\": \"usada\"}}}" > /dev/null

    echo -e "${VERDE}[OK] Key autenticada e registrada neste aparelho!${RESET}"
    sleep 2
elif [[ "$RESPOSTA" == *"\"stringValue\": \"$HWID\""* ]]; then
    # Key já usada no mesmo aparelho: verifica se expirou
    EXPIRA_RAW=$(echo "$RESPOSTA" | grep -o '"expiresAt": {[^}]*}' | grep -o '"timestampValue": "[^"]*"' | cut -d'"' -f4)
    
    if [[ -z "$EXPIRA_RAW" || "$EXPIRA_RAW" == "null" ]]; then
        echo -e "${VERDE}[OK] Key validada (sem expiracao).${RESET}"
        sleep 2
    else
        # Converte a data do Firestore (2026-10-24T23:19:32.707Z) pro formato do sistema
        EXPIRA_FORMATADA=$(echo "$EXPIRA_RAW" | sed 's/T/ /; s/\..*//')
        DATA_ATUAL=$(date -u +"%Y-%m-%d %H:%M:%S")
        
        # Compara as datas
        if [[ "$DATA_ATUAL" > "$EXPIRA_FORMATADA" ]]; then
            echo -e "${VERMELHO}[ERRO] Esta Key expirou!${RESET}"
            exit 1
        else
            echo -e "${VERDE}[OK] Key validada para este aparelho!${RESET}"
            sleep 2
        fi
    fi
else
    echo -e "${VERMELHO}[ERRO] Esta Key ja foi usada em outro aparelho.${RESET}"
    exit 1
fi

# --- MENU PRINCIPAL ---
while true; do
    clear
    echo -e "${AZUL}=================================================="
    echo -e "                 ROBLOX REMOTE"
    echo -e "==================================================${RESET}"
    echo -e "1. Instalar ADB (Android Tools)"
    echo -e "2. Baixar e Instalar APK Roblox"
    echo -e "3. Start Remote (Ativar Overlay)"
    echo -e "4. Bypass (Limpar VPN e Fechar)"
    echo -e "5. Sair"
    echo -e "--------------------------------------------------"
    read -p "Escolha uma opcao: " OPCAO

    case $OPCAO in
        1)
            clear
            echo -e "${AMARELO}Instalando ADB...${RESET}"
            pkg install android-tools -y > /dev/null 2>&1
            echo -e "${VERDE}ADB instalado com sucesso!${RESET}"
            sleep 2
            ;;
        2)
            clear
            echo -e "${AMARELO}=== BAIXAR APK ===${RESET}"
            echo -e "Copie o link abaixo e cole no seu navegador Chrome para baixar:\n"
            echo -e "${AZUL}https://www.mediafire.com/file/z1f1nllekuqb36q/Roblox.apk/file${RESET}\n"
            read -p "Caminho do APK: " CAMINHO_APK
            if [ -f "$CAMINHO_APK" ]; then
                adb install -r "$CAMINHO_APK"
                echo -e "${VERDE}APK instalado com sucesso!${RESET}"
            else
                echo -e "${VERMELHO}[ERRO] Arquivo nao encontrado.${RESET}"
            fi
            sleep 3
            ;;
        3)
            clear
            echo -e "${AMARELO}Iniciando Overlay Remoto...${RESET}"
            adb shell appops set com.vortexia.wire SYSTEM_ALERT_WINDOW allow
            adb shell am start-foreground-service -n com.vortexia.wire/com.vortexia.wire.OverlayService
            echo -e "${VERDE}Overlay ativado com sucesso!${RESET}"
            sleep 3
            ;;
        4)
            clear
            echo -e "${VERMELHO}=== BYPASS ===${RESET}"
            echo -e "${AMARELO}Tem certeza que deseja limpar a VPN e fechar o app? (s/n)${RESET}"
            read -p "> " CONFIRMA
            if [[ "$CONFIRMA" == "s" || "$CONFIRMA" == "S" ]]; then
                echo -e "\n${AMARELO}Apagando perfil de VPN...${RESET}"
                adb shell am force-stop com.vortexia.wire
                adb shell pm clear com.vortexia.wire > /dev/null 2>&1
                
                echo -e "${AMARELO}Fechando aplicativos...${RESET}"
                adb shell am force-stop com.dts.freefireth > /dev/null 2>&1
                
                echo -e "${VERDE}[OK] VPN limpa e aplicativos fechados!${RESET}"
                sleep 2
                exit 0
            else
                echo -e "${AMARELO}Bypass cancelado.${RESET}"
                sleep 2
            fi
            ;;
        5)
            echo -e "${VERDE}Saindo...${RESET}"
            exit 0
            ;;
        *)
            echo -e "${VERMELHO}Opcao invalida!${RESET}"
            sleep 1
            ;;
    esac
done
