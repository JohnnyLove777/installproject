#!/bin/bash

# Função para solicitar informações ao usuário e armazená-las em variáveis
function solicitar_informacoes {
    # Loop para solicitar e verificar o dominio
    while true; do
        read -p "Digite o domínio (por exemplo, johnny.com.br): " DOMINIO
        if [[ $DOMINIO =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            echo "Por favor, insira um domínio válido no formato, por exemplo 'johnny.com.br'."
        fi
    done    

    # Solicitar e-mail do Gmail para SMTP
    while true; do
        read -p "Digite o e-mail do Gmail para cadastro do Typebot (sem espaços): " EMAIL_GMAIL
        if [[ $EMAIL_GMAIL =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            echo "Por favor, insira um endereço de e-mail válido sem espaços."
        fi
    done

    # Solicitar senha de app do Gmail
    while true; do
        read -p "Digite a senha de app do Gmail (exatamente 16 caracteres): " SENHA_APP_GMAIL
        if [[ ! $SENHA_APP_GMAIL =~ [[:space:]] && ${#SENHA_APP_GMAIL} -eq 16 ]]; then
            break
        else
            echo "A senha de app deve ter exatamente 16 caracteres e não pode conter espaços."
        fi
    done

    # Solicitar IP da VPS
    while true; do
        read -p "Digite o IP da VPS: " IP_VPS
        if [[ $IP_VPS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        else
            echo "Por favor, insira um IP válido."
        fi
    done

    # Geração da chave de autenticação segura
    AUTH_KEY=$(openssl rand -hex 16)
    echo "Sua chave de autenticação é: $AUTH_KEY"
    
    while true; do
        read -p "Confirme que você copiou a chave (y/n): " confirm
        if [[ $confirm == "y" ]]; then
            break
        else
            echo "Por favor, copie a chave antes de continuar."
        fi
    done

    # Armazena as informações
    EMAIL_GMAIL_INPUT=$EMAIL_GMAIL
    SENHA_APP_GMAIL_INPUT=$SENHA_APP_GMAIL
    DOMINIO_INPUT=$DOMINIO
    IP_VPS_INPUT=$IP_VPS
    AUTH_KEY_INPUT=$AUTH_KEY
}

# Função para instalar Evolution API, JohnnyZap, JohnnyDash e Typebot
function instalar_evolution_johnnyzap_typebot {
    sudo apt update
    sudo apt upgrade -y
    sudo apt-add-repository universe

    # Instalar dependências
    sudo apt install -y python2-minimal nodejs npm git curl apt-transport-https ca-certificates software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
    sudo apt update
    sudo apt install -y docker-ce docker-compose nginx certbot python3-certbot-nginx ffmpeg

    # Adicionar usuário ao grupo Docker
    sudo usermod -aG docker ${USER}

    # Solicitar informações
    solicitar_informacoes

    # Configurações NGINX
    cat <<EOF > /etc/nginx/sites-available/evolution
server {
    server_name evolution.$DOMINIO_INPUT;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
    }
}
EOF

    cat <<EOF > /etc/nginx/sites-available/johnnyzap
server {
    server_name server.$DOMINIO_INPUT;
    location / {
        proxy_pass http://127.0.0.1:3030;
        proxy_http_version 1.1;
    }
}
EOF

    cat <<EOF > /etc/nginx/sites-available/typebot
server {
    server_name typebot.$DOMINIO_INPUT;
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
    }
}
EOF

    cat <<EOF > /etc/nginx/sites-available/viewbot
server {
    server_name bot.$DOMINIO_INPUT;
    location / {
        proxy_pass http://127.0.0.1:3002;
        proxy_http_version 1.1;
    }
}
EOF

    cat <<EOF > /etc/nginx/sites-available/minio
server {
    server_name storage.$DOMINIO_INPUT;
    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
    }
}
EOF

    # Configuração para JohnnyDash
    cat <<EOF > /etc/nginx/sites-available/johnnydash
server {
    server_name johnnydash.$DOMINIO_INPUT;
    location / {
        proxy_pass http://127.0.0.1:3031;
        proxy_http_version 1.1;
    }
}
EOF

    # Copiar e ativar configurações
    sudo ln -s /etc/nginx/sites-available/evolution /etc/nginx/sites-enabled
    sudo ln -s /etc/nginx/sites-available/johnnyzap /etc/nginx/sites-enabled
    sudo ln -s /etc/nginx/sites-available/typebot /etc/nginx/sites-enabled
    sudo ln -s /etc/nginx/sites-available/viewbot /etc/nginx/sites-enabled
    sudo ln -s /etc/nginx/sites-available/minio /etc/nginx/sites-enabled
    sudo ln -s /etc/nginx/sites-available/johnnydash /etc/nginx/sites-enabled

    # Certificados SSL
    sudo certbot --nginx --email $EMAIL_GMAIL_INPUT --redirect --agree-tos -d evolution.$DOMINIO_INPUT -d server.$DOMINIO_INPUT -d typebot.$DOMINIO_INPUT -d bot.$DOMINIO_INPUT -d storage.$DOMINIO_INPUT -d johnnydash.$DOMINIO_INPUT

    # Evolution API Docker
    docker run --name evolution-api --detach \
    -p 8080:8080 \
    -e AUTHENTICATION_API_KEY=$AUTH_KEY_INPUT \
    atendai/evolution-api \
    node ./dist/src/main.js

    # JohnnyZap
    cd /
    git clone https://github.com/JohnnyLove777/johnnyzap-inteligente.git
    cd johnnyzap-inteligente
    npm install
    echo "IP_VPS=http://$IP_VPS_INPUT" > .env
    pm2 start ecosystem.config.js

    # JohnnyDash (assumindo que será um app separado rodando na porta 3031)
    echo "Instalando JohnnyDash..."
    # Aqui você pode adicionar os comandos para clonar e configurar o JohnnyDash da mesma forma que JohnnyZap, caso ele seja um projeto separado.

    # Typebot Docker Compose
    cat <<EOF > docker-compose.yml
version: '3.3'
services:
  typebot-db:
    image: postgres:13
    environment:
      - POSTGRES_DB=typebot
      - POSTGRES_PASSWORD=typebot
    volumes:
      - db_data:/var/lib/postgresql/data

  typebot-builder:
    image: baptistearno/typebot-builder:latest
    ports:
      - 3001:3000
    environment:
      - DATABASE_URL=postgresql://postgres:typebot@typebot-db:5432/typebot
      - NEXTAUTH_URL=https://typebot.$DOMINIO_INPUT
      - ADMIN_EMAIL=$EMAIL_GMAIL_INPUT
      - SMTP_USERNAME=$EMAIL_GMAIL_INPUT
      - SMTP_PASSWORD=$SENHA_APP_GMAIL_INPUT
      - S3_ENDPOINT=https://storage.$DOMINIO_INPUT
      - S3_ACCESS_KEY=minio
      - S3_SECRET_KEY=minio123

  typebot-viewer:
    image: baptistearno/typebot-viewer:latest
    ports:
      - 3002:3000
    environment:
      - NEXT_PUBLIC_VIEWER_URL=https://bot.$DOMINIO_INPUT

  minio:
    image: minio/minio
    ports:
      - '9000:9000'
    environment:
      MINIO_ROOT_USER: minio
      MINIO_ROOT_PASSWORD: minio123
volumes:
  db_data:
EOF

    # Iniciar contêineres
    docker compose up -d

    echo "Tudo instalado e configurado com sucesso!"
}

# Chamar função
instalar_evolution_johnnyzap_typebot
