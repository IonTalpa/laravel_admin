# 🚀 Filament Panel Kurulum ve Deployment Rehberi

## 📋 İçindekiler
- [Hızlı Başlangıç](#hızlı-başlangıç)
- [Localhost Kurulumu](#localhost-kurulumu)
- [Hosting'e Deployment](#hostinge-deployment)
- [Sorun Giderme](#sorun-giderme)
- [Sık Sorulan Sorular](#sık-sorulan-sorular)

---

## 🎯 Hızlı Başlangıç

### Gereksinimler
- PHP 8.1+
- Composer
- MySQL veya SQLite

### Script'i İndir ve Çalıştır
```bash
# Script'i indir
wget https://example.com/install-filament.sh
# veya manuel oluştur

# Çalıştırma izni ver
chmod +x install-filament.sh

# Çalıştır
./install-filament.sh
```

---

## 💻 Localhost Kurulumu

### Varsayılan Kurulum
```bash
./install-filament.sh
```
- Panel: `http://localhost:8000/admin`
- Email: `admin@example.com`
- Şifre: `password`

### Özel Ayarlarla Kurulum
```bash
PROJECT_NAME="my-app" \
ADMIN_EMAIL="admin@mysite.com" \
ADMIN_PASSWORD="MySecurePass123" \
./install-filament.sh
```

---

## 🌐 Hosting'e Deployment

### 1. SSH ile Bağlan
```bash
ssh username@server-ip
cd ~/public_html
```

### 2. Script'i Yükle ve Çalıştır
```bash
# Script'i upload et (FTP veya wget ile)
wget https://yourserver.com/install-filament.sh
chmod +x install-filament.sh

# Domain'i belirterek çalıştır
APP_URL="https://yourdomain.com" \
ADMIN_EMAIL="admin@yourdomain.com" \
./install-filament.sh
```

### 3. Public Klasörü Yönlendir
```bash
# public_html içinde .htaccess oluştur
cat > .htaccess << 'EOF'
RewriteEngine On
RewriteRule ^(.*)$ public/$1 [L]
EOF
```

### 4. Production Ayarları
`.env` dosyasını düzenle:
```env
APP_ENV=production
APP_DEBUG=false
APP_URL=https://yourdomain.com

# MySQL kullanıyorsan
DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=veritabani_adi
DB_USERNAME=kullanici_adi
DB_PASSWORD=sifre
```

### 5. İzinleri Ayarla
```bash
chmod -R 755 .
chmod -R 777 storage bootstrap/cache
chmod 644 .env
```

### 6. Optimizasyon
```bash
php artisan config:cache
php artisan route:cache
php artisan view:cache
composer install --optimize-autoloader --no-dev
```

---

## 🔧 Sorun Giderme

### 500 Internal Server Error
```bash
# Hata loglarını kontrol et
tail -f storage/logs/laravel.log

# İzinleri düzelt
chmod -R 777 storage
chmod -R 777 bootstrap/cache
```

### Veritabanı Bağlantı Hatası
```bash
# .env dosyasını kontrol et
nano .env

# Cache'i temizle
php artisan config:clear
php artisan cache:clear

# Veritabanını test et
php artisan tinker
>>> DB::connection()->getPdo();
```

### "Class not found" Hatası
```bash
composer install
composer dump-autoload
```

### Panel'e Giriş Yapamıyorum
```bash
# Yeni admin kullanıcı oluştur
php artisan make:filament-user

# Veya tinker ile
php artisan tinker
>>> \App\Models\User::create([
>>>     'name' => 'Admin',
>>>     'email' => 'yeni@email.com',
>>>     'password' => bcrypt('yenisifre')
>>> ]);
```

---

## ❓ Sık Sorulan Sorular

### Subdomain'de nasıl kurarım?
```bash
cd ~/domains/panel.yourdomain.com/public_html
APP_URL="https://panel.yourdomain.com" ./install-filament.sh
```

### MySQL yerine PostgreSQL kullanabilir miyim?
Evet, `.env` dosyasında:
```env
DB_CONNECTION=pgsql
DB_PORT=5432
```

### SSL sertifikası nasıl eklerim?
Hosting panelinden Let's Encrypt SSL aktifleştir veya `.htaccess`'e ekle:
```apache
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}/$1 [R=301,L]
```

### Farklı bir port kullanmak istiyorum
```bash
php artisan serve --port=3000
```

### Mail ayarları nasıl yapılır?
`.env` dosyasına ekle:
```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=your-email@gmail.com
```

---

## 📝 Notlar

- İlk girişte admin şifresini değiştirmeyi unutma!
- Production'da `APP_DEBUG=false` olmalı
- Düzenli backup al
- `.env` dosyasını git'e ekleme

---

## 🆘 Destek

Sorun yaşarsan:
1. Hata mesajını Google'la
2. [Laravel Docs](https://laravel.com/docs)
3. [Filament Docs](https://filamentphp.com/docs)
4. Stack Overflow'da sor

---

## 📜 Lisans

MIT

---

*Son güncelleme: 2024*
