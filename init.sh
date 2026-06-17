#!/bin/dash

# -------------------------------
# Configuración
# -------------------------------
NUM_THREADS=6
BASE_DIR="$HOME/chromium-src"
BUILD_DIR="out/Default"

# 🔥 Flags CPU (Alder Lake)
OPT_FLAGS="-march=alderlake -Ofast -mabm -mno-kl -mno-pconfig -mno-sgx -mno-widekl -mshstk --param=l1-cache-line-size=64 --param=l1-cache-size=32 --param=l2-cache-size=12288"

export CFLAGS="$OPT_FLAGS"
export CXXFLAGS="$OPT_FLAGS"

# -------------------------------
# 1. depot_tools
# -------------------------------
if [ ! -d "$HOME/depot_tools" ]; then
    echo "📥 Clonando depot_tools..."
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$HOME/depot_tools"
fi
export PATH="$PATH:$HOME/depot_tools"

# -------------------------------
# 2. Sync
# -------------------------------
echo "🧹 Preparando entorno..."
cd "$HOME"
rm -f .gclient
[ ! -L "src" ] && ln -sf "$BASE_DIR" src

gclient config --name="src" https://chromium.googlesource.com/chromium/src

cd "$BASE_DIR"

echo "🔄 Sincronizando dependencias (respetando user-work)..."
# Revertimos solo parches de este script, NO tus cambios
git checkout build/toolchain/gcc_toolchain.gni 2>/dev/null
git checkout chrome/browser/new_tab_page 2>/dev/null

# Sincronización
gclient sync --no-history -D --force --upstream || exit 1
gclient runhooks || exit 1

# -------------------------------
# 3. Parche GN (toolchain fix)
# -------------------------------
echo "🛠️ Parche GN..."
TARGET_FILE="build/toolchain/gcc_toolchain.gni"

if [ -f "$TARGET_FILE" ]; then
    sed -i 's/inputs = rustc_wrapper_inputs/not_needed([ "rustc_wrapper_inputs" ])/g' "$TARGET_FILE"
fi

# -------------------------------
# 4. 🚫 Desactivar IA del NTP (QUIRÚRGICO)
# -------------------------------
echo "🚫 Desactivando features de NTP AI..."

FEATURE_FILES=$(grep -RIl "BASE_FEATURE" chrome/browser/new_tab_page 2>/dev/null)

for file in $FEATURE_FILES; do
    sed -i '
    /Ntp\|ntp\|MagicStack\|Modules\|Drive\|AI/ {
        s/FEATURE_ENABLED_BY_DEFAULT/FEATURE_DISABLED_BY_DEFAULT/g
    }
    ' "$file"
done

# -------------------------------
# 5. 🛠️ Parches de Pestaña Única y Pantalla Blanca (SURGICAL)
# -------------------------------
echo "🛡️ Aplicando parches de Pestaña Única y Pantalla Blanca..."

# Corregir error de GN (variable no usada en .gn)
[ -f ".gn" ] && sed -i 's/^expand_directory_allowlist =/# expand_directory_allowlist =/' .gn

# A. Restringir TabStripModel a 1 sola pestaña (Sintaxis corregida)
sed -i '/int TabStripModel::InsertTabAtImpl(/,/ {/ s/ {/ { if (count() >= 1) return active_index(); /' chrome/browser/ui/tabs/tab_strip_model.cc

# B. Forzar Navegación en la pestaña actual
sed -i '/base::WeakPtr<content::NavigationHandle> Navigate(NavigateParams\* params) {/ a \  if (params->disposition != WindowOpenDisposition::CURRENT_TAB && params->disposition != WindowOpenDisposition::NEW_POPUP) params->disposition = WindowOpenDisposition::CURRENT_TAB;' chrome/browser/ui/browser_navigator.cc

# C. Ocultar botones de "Nueva Pestaña" (Horizontal y Vertical)
sed -i '/bool ShouldShowNewTabButton(BrowserWindowInterface\* browser) {/ a \  return false;' chrome/browser/ui/views/frame/horizontal_tab_strip_region_view.cc
sed -i '/new_tab_button_ = AddChildView(std::move(new_tab_button));/ a \  new_tab_button_->SetVisible(false);' chrome/browser/ui/views/tabs/vertical/vertical_tab_strip_bottom_container.cc

# D. Forzar about:blank como página de inicio y New Tab
sed -i 's/return NewTabURLDetails::ForProfile(profile).url;/return GURL("about:blank");/' chrome/browser/search/search.cc
sed -i '/SessionStartupPref SessionStartupPref::GetStartupPref(/,/}/ s/return SessionStartupPref(PrefValueToType(prefs->GetInteger(prefs::kRestoreOnStartup)));/return SessionStartupPref(SessionStartupPref::DEFAULT);/' chrome/browser/prefs/session_startup_pref.cc

# E. Desactivar atajos de teclado (Ctrl+T, Ctrl+N)
sed -i '/IDC_NEW_TAB/d; /IDC_NEW_WINDOW/d; /IDC_NEW_INCOGNITO_WINDOW/d' chrome/browser/ui/accelerator_table.cc

# F. Limpiar Menú de Aplicaciones (Quitar Nueva Pestaña/Ventana)
sed -i '/IDC_NEW_TAB/,/)/ s/^/\/\//; /IDC_NEW_WINDOW/,/)/ s/^/\/\//' chrome/browser/ui/toolbar/app_menu_model.cc

# -------------------------------
# 6. Build args
# -------------------------------
echo "🏗️ Generando build (modo desarrollo)..."

rm -rf "$BUILD_DIR"

gn gen "$BUILD_DIR" --args="
use_ozone=true
ozone_platform_wayland=false
ozone_platform_x11=true
cc_wrapper=\"ccache\"

is_official_build=false
symbol_level=0
treat_warnings_as_errors=false
chrome_pgo_phase=0

# privacidad
google_api_key=\"no\"
google_default_client_id=\"no\"
google_default_client_secret=\"no\"

# Permitir variables no usadas en GN para evitar errores de parada
ignore_elf_symbol_check=true

enable_nacl=false
enable_extensions=true

# optimización segura
use_thin_lto=true
is_cfi=false
" || exit 1

# -------------------------------
# 6. Compilación
# -------------------------------
echo "🚀 Compilando con $NUM_THREADS hilos..."

if command -v ninja >/dev/null 2>&1; then
    ninja -C "$BUILD_DIR" -j "$NUM_THREADS" chrome || exit 1
else
    echo "❌ ninja no encontrado"
    exit 1
fi

# -------------------------------
# 7. Instalación
# -------------------------------
echo "🎉 Instalando..."
doas ln -sf "$(pwd)/$BUILD_DIR/chrome" /usr/local/bin/chromium-native

echo "✅ Chromium listo (Tu versión + optimizado)"
