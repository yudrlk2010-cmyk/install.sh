#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# ROBLOX REMOTE
# ==========================================

# URL DA API DO FIRESTORE
FIRESTORE_URL="https://firestore.googleapis.com/v1/projects/kernel-system-key-bd527/databases/(default)/documents:runQuery"

# Cores
VERDE="\033[1;32m"
VERMELHO="\033[1;31m"
AZUL="\033[1;34m"
AMARELO="\033[1;33m"
RESET="\033[0m"

# --- INSTALAÇÃO DO ADB (SILENCIOSA) ---
pkg update -y > /dev/null 2>&1
pkg install android-tools -y > /dev/null 2>&1

# --- PAREAMENTO OBRIGATÓRIO ---
clear
echo -e "${AZUL}=================================================="
echo -e "                 ROBLOX REMOTE"
echo -e "==================================================${RESET}"
echo -e "${AMARELO}Pareie seu dispositivo para liberar a tela de inserir a Key.${RESET}\n"

# Fica num loop até o dispositivo conectar
while true; do
    read -p "Digite o IP e a Porta de Pareamento (ex: 192.168.1.7:40000): " IP_PORTA
    adb pair $IP_PORTA
    
    echo -e "\nAgora digite o IP e a Porta de Conexao (ex: 192.168.1.7:5555): "
    read -p "> " IP_CONEXAO
    adb connect $IP_CONEXAO
    
    # Verifica se o dispositivo conectou
    if adb devices | grep -q "device$"; then
        echo -e "\n${VERDE}[OK] Dispositivo pareado com sucesso!${RESET}"
        sleep 2
        break
    else
        echo -e "\n${VERMELHO}[ERRO] Falha ao parear. Verifique se a Depuracao sem fio esta ativada.${RESET}"
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

# Pega o HWID do celular via ADB
HWID=$(adb shell settings get secure android_id | tr -d '\r')

if [ -z "$HWID" ] || [[ "$HWID" == *"error"* ]]; then
    echo -e "${VERMELHO}[ERRO] Nao foi possivel ler o HWID. Tente novamente.${RESET}"
    exit 1
fi

# Consulta no Firestore
RESPOSTA=$(curl -s -X POST "$FIRESTORE_URL" -H "Content-Type: application/json" -d "{\"structuredQuery\":{\"from\":[{\"collectionId\":\"keys\"}],\"where\":{\"fieldFilter\":{\"field\":{\"fieldPath\":\"key\"},\"op\":\"EQUAL\",\"value\":{\"stringValue\":\"$USER_KEY\"}}}}}")

# Verifica se a key existe
if [[ "$RESPOSTA" == "[]" || "$RESPOSTA" == *"NOT_FOUND"* ]]; then
    echo -e "${VERMELHO}[ERRO] Key invalida ou nao encontrada!${RESET}"
    exit 1
fi

# Extrai o ID do documento
DOC_ID=$(echo "$RESPOSTA" | grep -o '"name": "[^"]*"' | cut -d'/' -f7 | tr -d '"')

# Lógica de HWID
if [[ "$RESPOSTA" == *'"stringValue": "livre"'* ]]; then
    # Key livre: salva o HWID e marca como usada
    curl -s -X PATCH "https://firestore.googleapis.com/v1/projects/kernel-system-key-bd527/databases/(default)/documents/keys/$DOC_ID?updateMask.fieldPaths=hwid&updateMask.fieldPaths=status" \
    -H "Content-Type: application/json" \
    -d "{\"fields\": {\"hwid\": {\"stringValue\": \"$HWID\"}, \"status\": {\"stringValue\": \"usada\"}}}" > /dev/null

    echo -e "${VERDE}[OK] Key autenticada e registrada neste aparelho!${RESET}"
    sleep 2
elif [[ "$RESPOSTA" == *"\"stringValue\": \"$HWID\""* ]]; then
    # Key já usada, mas o HWID é o mesmo: libera
    echo -e "${VERDE}[OK] Key validada para este aparelho!${RESET}"
    sleep 2
else
    # Key usada em outro celular
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
    echo -e "4. Sair"
    echo -e "--------------------------------------------------"
    read -p "Escolha uma opcao: " OPCAO

    case $OPCAO in
        1)
            clear
            echo -e "${AMARELO}Verificando ADB...${RESET}"
            pkg install android-tools -y > /dev/null 2>&1
            echo -e "${VERDE}ADB ja instalado e pronto para uso!${RESET}"
            sleep 2
            ;;
        2)
            clear
            echo -e "${AMARELO}=== BAIXAR APK ===${RESET}"
            echo -e "Copie o link abaixo e cole no seu navegador Chrome para baixar:\n"
            echo -e "${AZUL}https://www.mediafire.com/file/z1f1nllekuqb36q/Roblox.apk/file${RESET}\n"
            echo -e "Depois de baixar o APK no Chrome, volte aqui e digite o caminho do arquivo."
            echo -e "Geralmente ele fica em: ~/storage/downloads/Roblox.apk"
            read -p "Caminho do APK: " CAMINHO_APK
            
            if [ -f "$CAMINHO_APK" ]; then
                echo -e "${AMARELO}Instalando APK...${RESET}"
                adb install -r "$CAMINHO_APK"
                echo -e "${VERDE}APK instalado com sucesso!${RESET}"
            else
                echo -e "${VERMELHO}[ERRO] Arquivo nao encontrado no caminho informado.${RESET}"
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
            echo -e "${VERDE}Saindo...${RESET}"
            exit 0
            ;;
        *)
            echo -e "${VERMELHO}Opcao invalida!${RESET}"
            sleep 1
            ;;
    esac
done
