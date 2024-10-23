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

    # Solicitar email para configurar o provider do Chatwoot
    while true; do
        read -p "Digite o e-mail do remetente para o Chatwoot (ex: seuemail@seudominio.com): " EMAIL_CHATWOOT
        if [[ $EMAIL_CHATWOOT =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            echo "Por favor, insira um endereço de e-mail válido sem espaços."
        fi
    done

    # Solicitar a API Key do SendGrid
    while true; do
        read -p "Digite a SendGrid API Key: " SENDGRID_API_KEY
        if [[ ! -z "$SENDGRID_API_KEY" ]]; then
            break
        else
            echo "A API Key não pode estar vazia."
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
    EMAIL_CHATWOOT_INPUT=$EMAIL_CHATWOOT
    SENDGRID_API_KEY_INPUT=$SENDGRID_API_KEY
    DOMINIO_INPUT=$DOMINIO
    IP_VPS_INPUT=$IP_VPS
    AUTH_KEY_INPUT=$AUTH_KEY
}

# Função para instalar Evolution API, JohnnyZap, JohnnyDash, Typebot e Chatwoot
function instalar_sistemas {
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
      - S3_SECRET_KEY=min
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

    # Instalar e configurar Chatwoot
    instalar_chatwoot

    echo "Tudo instalado e configurado com sucesso!"
}

# Função para instalar Chatwoot
function instalar_chatwoot {
    echo "Instalando Chatwoot..."

    # Instalar dependências
    apt update && apt upgrade -y
    apt install -y curl
    curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    NODE_MAJOR=20
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    apt update
    apt install -y postgresql postgresql-contrib redis-server nginx nginx-full certbot python3-certbot-nginx nodejs patch ruby-dev zlib1g-dev libvips

    # Configurações adicionais do Chatwoot
    local secret=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 63 ; echo '')
    local RAILS_ENV=production

    sudo -i -u chatwoot << EOF
    rvm install "ruby-3.3.3"
    rvm use 3.3.3 --default
    git clone https://github.com/chatwoot/chatwoot.git
    cd chatwoot
    git checkout master
    bundle
    pnpm i
    cp .env.example .env
    sed -i -e "/SECRET_KEY_BASE/ s/=.*/=$secret/" .env
    sed -i -e '/REDIS_URL/ s/=.*/=redis:\/\/localhost:6379/' .env
    sed -i -e '/POSTGRES_HOST/ s/=.*/=localhost/' .env
    sed -i -e '/POSTGRES_USERNAME/ s/=.*/=chatwoot/' .env
    sed -i -e "/POSTGRES_PASSWORD/ s/=.*/=$pg_pass/" .env
    sed -i -e '/RAILS_ENV/ s/=.*/=$RAILS_ENV/' .env
    rake assets:precompile RAILS_ENV=production NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider"
EOF

    # Configurar o Email Provider do Chatwoot (SendGrid)
    sudo -i -u chatwoot << EOF
    cd chatwoot
    sed -i -e "/MAILER_SENDER_EMAIL/ s/=.*/=Chatwoot <$EMAIL_CHATWOOT_INPUT>/" .env
    sed -i -e "/SMTP_DOMAIN/ s/=.*/=$DOMINIO_INPUT/" .env
    sed -i -e "/SMTP_ADDRESS/ s/=.*/=smtp.sendgrid.net/" .env
    sed -i -e "/SMTP_PORT/ s/=.*/=587/" .env
    sed -i -e "/SMTP_AUTHENTICATION/ s/=.*/=plain/" .env
    sed -i -e "/SMTP_USERNAME/ s/=.*/=apikey/" .env
    sed -i -e "/SMTP_PASSWORD/ s/=.*/=$SENDGRID_API_KEY_INPUT/" .env
    sed -i -e "/SMTP_ENABLE_STARTTLS_AUTO/ s/=.*/=true/" .env
    sed -i -e "/ENABLE_ACCOUNT_SIGNUP/ s/=.*/=true/" .env
EOF

    # Setup do serviço Chatwoot
    cp /home/chatwoot/chatwoot/deployment/chatwoot-web.1.service /etc/systemd/system/chatwoot-web.1.service
    cp /home/chatwoot/chatwoot/deployment/chatwoot-worker.1.service /etc/systemd/system/chatwoot-worker.1.service
    systemctl enable chatwoot.target
    systemctl start chatwoot.target

    # Reiniciar Chatwoot após a configuração do email provider
    sudo systemctl restart chatwoot.target

    echo "Chatwoot instalado e configurado com sucesso!"
}

# Chamar função
instalar_sistemas
