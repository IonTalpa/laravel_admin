#!/usr/bin/env bash
set -euo pipefail

# ====== Renkli çıktı için sabitler ======
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly NC='\033[0m' # No Color

# ====== Global değişkenler ======
CLEANUP_DISABLED="false"  # Başlangıç değeri

# ====== Ayarlar ======
PROJECT_NAME="${PROJECT_NAME:-panel-starter}"
APP_URL="${APP_URL:-http://localhost}"
ADMIN_NAME="${ADMIN_NAME:-Admin User}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-password}"

FILAMENT_VERSION="${FILAMENT_VERSION:-^3.2}"
PERMISSION_VERSION="${PERMISSION_VERSION:-^6.7}"
SHIELD_VERSION="${SHIELD_VERSION:-^3.0}"

# ====== Yardımcı Fonksiyonlar ======
info()  { echo -e "${BLUE}[bilgi]${NC} $*"; }
ok()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[uyarı]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*" >&2; }
die()   { err "$*"; exit 1; }

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        die "'$1' bulunamadı. Lütfen yükleyin."
    fi
}

free_port() {
    local port=${1:-8000}
    while lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 || \
          ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$port$"; do
        port=$((port+1))
    done
    echo "$port"
}

check_php_version() {
    local required_version="8.1.0"
    if ! php -r "exit(version_compare(PHP_VERSION, '$required_version', '>=') ? 0 : 1);"; then
        die "PHP $required_version veya üzeri gerekli. Mevcut: $(php -v | head -1)"
    fi
}

# ====== Temizlik fonksiyonu (hata durumunda) ======
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ] && [ "$CLEANUP_DISABLED" != "true" ]; then
        warn "Kurulum başarısız oldu (Hata kodu: $exit_code)"
        if [ -d "$PROJECT_NAME" ] && [ "$PWD" = "$(realpath "$PROJECT_NAME" 2>/dev/null || echo "$PWD")" ]; then
            cd ..
            read -p "Oluşturulan '$PROJECT_NAME' klasörü silinsin mi? (e/H): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ee]$ ]]; then
                rm -rf "$PROJECT_NAME"
                info "Klasör silindi."
            fi
        fi
    fi
}
trap cleanup EXIT

# ====== Ön Kontroller ======
info "Sistem gereksinimleri kontrol ediliyor..."
need php
need composer
need lsof || need ss  # Port kontrolü için

check_php_version
ok "PHP versiyonu uygun: $(php -v | head -1 | cut -d' ' -f2)"

# Composer versiyonu kontrolü
composer_version=$(composer --version 2>/dev/null | cut -d' ' -f3)
ok "Composer versiyonu: $composer_version"

# Proje klasörü kontrolü
if [ -d "$PROJECT_NAME" ]; then
    die "Klasör zaten var: $PROJECT_NAME"
fi

# ====== Laravel Kurulumu ======
info "Laravel projesi oluşturuluyor: $PROJECT_NAME"
composer create-project laravel/laravel "$PROJECT_NAME" --prefer-dist --no-interaction

cd "$PROJECT_NAME" || die "Proje klasörüne geçilemedi"
ok "Çalışma dizini: $(pwd)"

# İlk cache temizleme
php artisan config:clear
php artisan cache:clear 2>/dev/null || true

# ====== Environment Ayarları ======
info ".env dosyası yapılandırılıyor"

# .env dosyasını güvenli şekilde oluştur
if [ ! -f .env ]; then
    cp .env.example .env || die ".env.example bulunamadı"
fi

# Uygulama anahtarı oluştur
php artisan key:generate --force --no-interaction

# .env dosyasını güncelle (platform bağımsız)
update_env() {
    local key="$1"
    local value="$2"
    local file=".env"
    
    if grep -q "^${key}=" "$file"; then
        # macOS ve Linux uyumlu sed kullanımı
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^${key}=.*|${key}=${value}|" "$file"
        else
            sed -i "s|^${key}=.*|${key}=${value}|" "$file"
        fi
    else
        echo "${key}=${value}" >> "$file"
    fi
}

# Comment out fonksiyonu
comment_env() {
    local key="$1"
    local file=".env"
    
    if grep -q "^${key}=" "$file"; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/^${key}=/#${key}=/" "$file"
        else
            sed -i "s/^${key}=/#${key}=/" "$file"
        fi
    fi
}

# Environment değişkenlerini güncelle
update_env "APP_NAME" "\"${PROJECT_NAME}\""
update_env "APP_URL" "${APP_URL}"
update_env "DB_CONNECTION" "sqlite"

# MySQL ayarlarını yorum satırı yap
comment_env "DB_HOST"
comment_env "DB_PORT" 
comment_env "DB_USERNAME"
comment_env "DB_PASSWORD"

# SQLite veritabanı oluştur
info "SQLite veritabanı ayarlanıyor"
mkdir -p database
touch database/database.sqlite
chmod 664 database/database.sqlite  # Veritabanı dosyasına yazma izni ver
ok "Veritabanı dosyası oluşturuldu: $(pwd)/database/database.sqlite"

# .env dosyasında tam yol kullan
DB_PATH="$(pwd)/database/database.sqlite"
update_env "DB_DATABASE" "${DB_PATH}"

# ====== Locale ve Timezone Ayarları ======
info "Locale ve timezone ayarları yapılıyor"
php <<'PHP'
<?php
$configFile = 'config/app.php';
if (!file_exists($configFile)) {
    echo "HATA: config/app.php bulunamadı\n";
    exit(1);
}

$config = file_get_contents($configFile);
$replacements = [
    "'timezone' => 'UTC'" => "'timezone' => 'Europe/Istanbul'",
    "'locale' => 'en'" => "'locale' => 'tr'",
    "'fallback_locale' => 'en'" => "'fallback_locale' => 'tr'",
];

foreach ($replacements as $search => $replace) {
    $config = str_replace($search, $replace, $config);
}

file_put_contents($configFile, $config);
echo "config/app.php güncellendi\n";
PHP

# ====== Filament Kurulumu ======
info "Filament paketi yükleniyor (${FILAMENT_VERSION})"
composer require "filament/filament:${FILAMENT_VERSION}" --no-interaction

info "Filament Admin paneli oluşturuluyor"
# Önce panel oluştur
php artisan make:filament-panel admin --no-interaction || die "Filament panel oluşturulamadı"

# ====== Spatie Permission + Shield ======
info "Rol ve yetki yönetimi paketleri yükleniyor"
composer require "spatie/laravel-permission:${PERMISSION_VERSION}" --no-interaction -W
composer require "bezhansalleh/filament-shield:${SHIELD_VERSION}" --no-interaction -W

# Permission config yayınla
php artisan vendor:publish --provider="Spatie\Permission\PermissionServiceProvider" --force

# ====== Veritabanı Migrasyonları ======
info "Veritabanı bağlantısını test ediyoruz"
php artisan db:show 2>/dev/null || {
    err "Veritabanı bağlantısı başarısız!"
    info "database/database.sqlite dosyasını kontrol ediyoruz..."
    ls -la database/ || true
    info ".env dosyasındaki DB ayarlarını kontrol ediyoruz..."
    grep "^DB_" .env || true
    die "Veritabanı bağlantısı kurulamadı. Lütfen ayarları kontrol edin."
}

info "Veritabanı migrasyonları çalıştırılıyor"
php artisan migrate --force --no-interaction

# Shield config yayınla
php artisan vendor:publish --tag="filament-shield-config" --force 2>/dev/null || true

# ====== User Model Güncelleme ======
info "User modeli güncelleniyor"
php <<'PHP'
<?php
$userFile = 'app/Models/User.php';
if (!file_exists($userFile)) {
    echo "HATA: User.php bulunamadı\n";
    exit(1);
}

$content = file_get_contents($userFile);

// HasRoles trait'ini ekle
if (strpos($content, 'use Spatie\\Permission\\Traits\\HasRoles;') === false) {
    $content = preg_replace(
        '/namespace App\\\\Models;/',
        "namespace App\\Models;\n\nuse Spatie\\Permission\\Traits\\HasRoles;",
        $content,
        1
    );
}

// Trait'i class içinde kullan
if (strpos($content, 'use HasRoles;') === false) {
    // Mevcut use ifadelerini bul ve HasRoles ekle
    $pattern = '/(use HasApiTokens.*?;)/';
    if (preg_match($pattern, $content, $matches)) {
        $replacement = $matches[1] . "\n    use HasRoles;";
        $content = str_replace($matches[1], $replacement, $content);
    }
}

file_put_contents($userFile, $content);
echo "User.php güncellendi (HasRoles trait'i eklendi)\n";
PHP

# ====== Panel Provider Güncelleme ======
info "Admin panel provider güncelleniyor"
php <<'PHP'
<?php
$providerFile = 'app/Providers/Filament/AdminPanelProvider.php';
if (!file_exists($providerFile)) {
    echo "UYARI: AdminPanelProvider.php bulunamadı, atlanıyor\n";
    exit(0);
}

$content = file_get_contents($providerFile);

// Shield plugin'ini ekle
if (strpos($content, 'FilamentShieldPlugin') === false) {
    // Use ifadesini ekle
    if (strpos($content, 'use BezhanSalleh\\FilamentShield\\FilamentShieldPlugin;') === false) {
        $content = preg_replace(
            '/namespace App\\\\Providers\\\\Filament;/',
            "namespace App\\Providers\\Filament;\n\nuse BezhanSalleh\\FilamentShield\\FilamentShieldPlugin;",
            $content,
            1
        );
    }
    
    // Plugin'i panel metoduna ekle
    $pattern = '/->plugins\(\[(.*?)\]\)/s';
    if (preg_match($pattern, $content, $matches)) {
        $plugins = trim($matches[1]);
        if (empty($plugins)) {
            $newPlugins = "\n            FilamentShieldPlugin::make()\n        ";
        } else {
            $newPlugins = $plugins . ",\n            FilamentShieldPlugin::make()\n        ";
        }
        $content = preg_replace($pattern, "->plugins([$newPlugins])", $content, 1);
    } else {
        // plugins metodu yoksa, panel metodunun sonuna ekle
        $content = preg_replace(
            '/(\->middleware\([^)]+\))/s',
            "$1\n        ->plugins([\n            FilamentShieldPlugin::make()\n        ])",
            $content,
            1
        );
    }
}

file_put_contents($providerFile, $content);
echo "AdminPanelProvider güncellendi (Shield plugin'i eklendi)\n";
PHP

# ====== Shield İzinleri ======
info "Shield izinleri oluşturuluyor"
php artisan shield:generate --all --quiet 2>/dev/null || warn "Shield izinleri oluşturulamadı (normal olabilir)"

# ====== Admin Kullanıcı Oluşturma ======
info "Admin kullanıcısı oluşturuluyor"

# Önce Filament komutuyla dene
php artisan make:filament-user \
    --name="${ADMIN_NAME}" \
    --email="${ADMIN_EMAIL}" \
    --password="${ADMIN_PASSWORD}" \
    2>/dev/null || true

# Kullanıcıya super_admin rolü ver
php <<PHP
<?php
require 'vendor/autoload.php';
\$app = require __DIR__.'/bootstrap/app.php';
\$kernel = \$app->make(Illuminate\Contracts\Console\Kernel::class);
\$kernel->bootstrap();

use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Spatie\Permission\Models\Role;

\$email = '${ADMIN_EMAIL}';
\$name = '${ADMIN_NAME}';
\$password = '${ADMIN_PASSWORD}';

// Kullanıcıyı oluştur veya güncelle
\$user = User::updateOrCreate(
    ['email' => \$email],
    [
        'name' => \$name,
        'password' => Hash::make(\$password),
        'email_verified_at' => now(),
    ]
);

echo "Kullanıcı hazır: \$email\n";

// Super admin rolünü oluştur ve ata
\$role = Role::firstOrCreate(['name' => 'super_admin', 'guard_name' => 'web']);

if (!\$user->hasRole(\$role->name)) {
    \$user->assignRole(\$role);
    echo "Super admin rolü atandı\n";
} else {
    echo "Kullanıcı zaten super admin\n";
}
PHP

# ====== Asset'leri Yayınla ======
info "Filament asset'leri yayınlanıyor"
php artisan filament:assets || true  # --force parametresi kaldırıldı
php artisan storage:link 2>/dev/null || true

# ====== Cache Temizleme ======
info "Cache temizleniyor"
php artisan optimize:clear

# ====== Başarı Mesajı ======
PORT=$(free_port 8000)

echo
echo "════════════════════════════════════════════════════════"
ok "🎉 Kurulum başarıyla tamamlandı!"
echo "════════════════════════════════════════════════════════"
echo
echo "  📋 Proje: ${PROJECT_NAME}"
echo "  🌐 Panel: ${BLUE}http://127.0.0.1:${PORT}/admin${NC}"
echo "  📧 Email: ${GREEN}${ADMIN_EMAIL}${NC}"
echo "  🔑 Şifre: ${GREEN}${ADMIN_PASSWORD}${NC}"
echo
echo "════════════════════════════════════════════════════════"
echo
info "Sunucu başlatılıyor..."
echo

# Sunucuyu başlat
CLEANUP_DISABLED=true  # Sunucu başlatıldıktan sonra cleanup'ı devre dışı bırak
exec php artisan serve --host=127.0.0.1 --port="${PORT}"
