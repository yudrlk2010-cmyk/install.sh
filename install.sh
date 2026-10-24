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

clear
echo -e "${AZUL}=================================================="
echo -e "                 ROBLOX REMOTE"
echo -e "==================================================${RESET}\n"

# 1. VALIDAÇÃO DA KEY
echo -e "${AMARELO}Digite sua Key de acesso:${RESET}"
read -p "> " USER_KEY

echo -e "\nVerificando Key no servidor..."

# Faz a requisição no Firestore direto, sem arquivo
RESPOSTA=$(curl -s -X POST "$FIRESTORE_URL" -H "Content-Type: application/json" -d "{\"structuredQuery\":{\"from\":[{\"collectionId\":\"keys\"}],\"where\":{\"fieldFilter\":{\"field\":{\"fieldPath\":\"key\"},\"op\":\"EQUAL\",\"value\":{\"stringValue\":\"$USER_KEY\"}}}}}")

# Verifica se a key foi encontrada
if [[ "$RESPOSTA" == "[]" || "$RESPOSTA" == *"NOT_FOUND"* ]]; then
    echo -e "${VERMELHO}[ERRO] Key invalida ou nao encontrada!${RESET}"
    exit 1
fi

# Verifica o status da key (tem que ser "livre")
if [[ "$RESPOSTA" == *'"status":'* && "$RESPOSTA" == *'"stringValue": "livre"'* ]]; then
    echo -e "${VERDE}[OK] Key autenticada com sucesso!${RESET}"
    sleep 2
else
    echo -e "${VERMELHO}[ERRO] Esta Key ja foi usada ou esta desativada.${RESET}"
    exit 1
fi

# 2. MENU PRINCIPAL
while true; do
    clear
    echo -e "${AZUL}=================================================="
    echo -e "                 ROBLOX REMOTE"
    echo -e "==================================================${RESET}"
    echo -e "1. Instalar ADB (Android Tools)"
    echo -e "2. Parear ADB (Wireless Debugging)"
    echo -e "3. Baixar e Instalar APK Roblox"
    echo -e "4. Start Remote (Ativar Overlay)"
    echo -e "5. Sair"
    echo -e "--------------------------------------------------"
    read -p "Escolha uma opcao: " OPCAO

    case $OPCAO in
        1)
            clear
            echo -e "${AMARELO}Instalando ADB...${RESET}"
            pkg update -y > /dev/null 2>&1
            pkg install android-tools -y > /dev/null 2>&1
            echo -e "${VERDE}ADB instalado com sucesso!${RESET}"
            sleep 2
            ;;
        2)
            clear
            echo -e "${AMARELO}=== PAREAMENTO ADB ===${RESET}"
            echo -e "Va em Configuracoes > Opcoes do Desenvolvedor > Depuracao sem fio."
            echo -e "Toque em 'Parear dispositivo'.\n"
            
            read -p "Digite o IP e a Porta de Pareamento (ex: 192.168.1.7:40000): " IP_PORTA
            adb pair $IP_PORTA
            
            echo -e "\nAgora digite o IP e a Porta de Conexao (ex: 192.168.1.7:5555): "
            read -p "> " IP_CONEXAO
            adb connect $IP_CONEXAO
            sleep 2
            ;;
        3)
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
        4)
            clear
            echo -e "${AMARELO}Iniciando Overlay Remoto...${RESET}"
            adb shell appops set com.vortexia.wire SYSTEM_ALERT_WINDOW allow
            adb shell am start-foreground-service -n com.vortexia.wire/com.vortexia.wire.OverlayService
            echo -e "${VERDE}Overlay ativado com sucesso!${RESET}"
            sleep 3
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
