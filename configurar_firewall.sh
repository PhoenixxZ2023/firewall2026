#!/bin/bash

# Define o local do arquivo de log
LOG_FILE="/var/log/meu_firewall.log"

# Função para registrar mensagens na tela e no arquivo com data/hora
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Verifica se o usuário é root
if [ "$EUID" -ne 0 ]; then
  echo "Erro: Execute como root."
  exit 1
fi

log "=== Iniciando auditoria e configuração de Firewall ==="

# Função para configurar UFW
configurar_ufw() {
    log ">> UFW selecionado. Iniciando configuração..."
    
    log ">> Neutralizando Firewalld (prevenção de conflito)..."
    systemctl stop firewalld >> "$LOG_FILE" 2>&1
    systemctl disable firewalld >> "$LOG_FILE" 2>&1
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y ufw >> "$LOG_FILE" 2>&1
    
    log ">> Resetando regras anteriores..."
    ufw --force reset >> "$LOG_FILE" 2>&1
    
    log ">> Liberando porta SSH (Proteção contra perda de acesso)..."
    ufw allow ssh >> "$LOG_FILE" 2>&1
    
    log ">> Liberando portas TCP e UDP..."
    # Porta 1080 adicionada aqui:
    ufw allow 80,443,1080,1194,2052,7505,8080,8443,8799,8880/tcp >> "$LOG_FILE" 2>&1
    ufw allow 7100,7200,7300,7400,7500/udp >> "$LOG_FILE" 2>&1
    
    log ">> Ativando o UFW..."
    ufw --force enable >> "$LOG_FILE" 2>&1
    
    log ">> UFW configurado com sucesso!"
}

# Função para configurar Firewalld
configurar_firewalld() {
    log ">> Firewalld selecionado. Iniciando configuração..."
    
    log ">> Neutralizando UFW (prevenção de conflito)..."
    ufw disable >> "$LOG_FILE" 2>&1
    systemctl stop ufw >> "$LOG_FILE" 2>&1
    systemctl disable ufw >> "$LOG_FILE" 2>&1
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y firewalld >> "$LOG_FILE" 2>&1
    
    log ">> Iniciando o serviço Firewalld..."
    systemctl start firewalld >> "$LOG_FILE" 2>&1
    systemctl enable firewalld >> "$LOG_FILE" 2>&1
    
    log ">> Liberando porta SSH (Proteção contra perda de acesso)..."
    firewall-cmd --zone=public --permanent --add-service=ssh >> "$LOG_FILE" 2>&1
    
    log ">> Liberando portas TCP e UDP..."
    # Porta 1080 adicionada aqui:
    firewall-cmd --zone=public --permanent --add-port={80,443,1080,1194,2052,7505,8080,8443,8799,8880}/tcp >> "$LOG_FILE" 2>&1
    firewall-cmd --zone=public --permanent --add-port={7100,7200,7300,7400,7500}/udp >> "$LOG_FILE" 2>&1
    
    log ">> Recarregando as regras..."
    firewall-cmd --reload >> "$LOG_FILE" 2>&1
    
    log ">> Firewalld configurado com sucesso!"
}

# Lógica de detecção
if command -v ufw > /dev/null; then
    configurar_ufw
elif command -v firewall-cmd > /dev/null; then
    configurar_firewalld
else
    log ">> Nenhum firewall detectado nativamente. Instalando UFW..."
    configurar_ufw
fi

log "=== Segurança de rede aplicada com sucesso! ==="
