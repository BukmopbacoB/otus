# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"          # Ubuntu 22.04 LTS
  # config.vm.box = "ubuntu/noble64"        # ← можно 24.04, если хочешь новее

  config.vm.hostname = "cms-prometheus"
  config.vm.network "private_network", ip: "192.168.56.88"

  config.vm.synced_folder ".", "/vagrant", disabled: false

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048
    vb.cpus = 2
  end

  config.vm.provision "shell", inline: <<-SHELL
    export DEBIAN_FRONTEND=noninteractive

    # Обновляем систему
    apt-get update && apt-get upgrade -y

    # Устанавливаем всё нужное
    apt-get install -y nginx php-fpm php-pgsql php-gd php-xml php-mbstring php-curl \
      php-zip php-json php-opcache php-intl php-bcmath unzip curl git \
      postgresql postgresql-contrib

    # Настраиваем PostgreSQL
    sudo -u postgres psql -c "CREATE USER drupal WITH PASSWORD 'drupalpass123';"
    sudo -u postgres psql -c "CREATE DATABASE drupal OWNER drupal;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE drupal TO drupal;"

    # Разрешаем подключение по localhost (по умолчанию и так работает, но на всякий)
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" /etc/postgresql/*/main/postgresql.conf
    echo "host    drupal    drupal    127.0.0.1/32    md5" >> /etc/postgresql/*/main/pg_hba.conf
    systemctl restart postgresql

    # Качаем Drupal 10
    cd /var/www
    curl -sSL https://www.drupal.org/download-latest/tar.gz -o drupal.tar.gz
    tar xzf drupal.tar.gz
    mv drupal-* drupal
    chown -R www-data:www-data /var/www/drupal

    # Настраиваем nginx
    cat > /etc/nginx/sites-available/drupal.conf <<'EOF'
server {
    listen 80;
    server_name _;

    root /var/www/drupal/web;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php*-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires max;
        log_not_found off;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/drupal.conf /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    systemctl restart nginx php*-fpm

    echo "-------------------------------------------------------"
    echo "Готово! Открывай в браузере: http://192.168.56.88"
    echo "Запусти установку Drupal в браузере"
    echo ""
    echo "База:     drupal"
    echo "Пользователь: drupal"
    echo "Пароль:   drupalpass123"
    echo "Хост:     localhost"
    echo "-------------------------------------------------------"
  SHELL
end
