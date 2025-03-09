#!/bin/bash
# ugh why are you reading this

LDF_REPO_SLUG="Nitepone/dotfiles-pub"
LDF_REPO="https://github.com/${LDF_REPO_SLUG}.git"
LDF_SCRIPT_ROOT="$(realpath "$(dirname "$0")")"
LDF_STAGING="${LDF_SCRIPT_ROOT}"
if [[ -z "$LDF_DEST" ]]; then
    LDF_DEST="${HOME}"
fi

LDF_ERROR_COUNT=0

function pr {
    echo "$*"
}

function pr_error {
    LDF_ERROR_COUNT=$((LDF_ERROR_COUNT + 1))
    echo -ne '\e[031m'
    echo -n "$*" >&2
    echo -e '\e[0m'
}

function pr_info {
    echo -ne '\e[02m'
    echo -n "  $*"
    echo -e '\e[0m'
}

function is_curl_install {
    local my_repo_url
    local ret
    my_repo_url="$(git --git-dir "${LDF_SCRIPT_ROOT}/.git" config --get remote.origin.url)"
    ret=$?
    if test "${ret}" -ne 0; then
        return 0
    fi
    # implicit return!
    # shellcheck disable=SC2076
    ! [[ "${my_repo_url}" =~ "${LDF_REPO_SLUG}" ]]
}

function get_dots {
    if is_curl_install; then
        pr_info "Attempting dotfile repo clone from Github."
        LDF_STAGING="$(mktemp -du -t "adeerwashere.XXX")"
        git clone "${LDF_REPO}" "${LDF_STAGING}"
        if test $? -ne 0; then
            echo "Failed to get dotfiles!.. Bad repo url?"
            return 1
        fi
    else
        pr_info "Using existing dotfile repo at: ${LDF_STAGING}"
    fi
}

function meta_inst_dot_config {
    local dest
    local src

    src="${LDF_STAGING}/dot-config/${1}/"
    dest="${LDF_DEST}/.config/${1}"

    if test -z "$1"; then
        pr_error "Bug: ${FUNCNAME[*]} called without a subdir?.."
        return 1
    fi
    if ! test -d "${src}"; then
        pr_error "Missing sources: ${src}"
    fi

    mkdir -p "${dest}"
    cp -r "${src}/"* "${dest}"
}

function meta_inst_dot_local_bin {
    local dest
    local src

    src="${LDF_STAGING}/dot-local/bin/${1}"
    dest="${LDF_DEST}/.local/bin/${1}"

    if test -z "$1"; then
        pr_error "Bug: ${FUNCNAME[*]} called without a bin name?.."
        return 1
    fi
    if ! test -f "${src}"; then
        pr_error "Missing source: ${src}"
    fi

    pr_info "Installing bin: ${1}"
    mkdir -p "$(dirname "${dest}")"
    cp -r "${src}" "${dest}"
    chmod +x "${dest}"
}

function inst_rustup {
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y &> /dev/null
    if ! command -v cargo > /dev/null; then
        pr_error "Rust install failed.."
    fi
}

function inst_xwayland_satellite {
    local build_dir
    build_dir="$(mktemp -d)"
    git clone https://github.com/Supreeeme/xwayland-satellite.git "${build_dir}" &> /dev/null
    pushd "${build_dir}" > /dev/null || ( pr_error "Bug: ${FUNCNAME[*]} Push/popd failed?" && return 1 )
    cargo build --release -q
    sudo install -m 755 target/release/xwayland-satellite /usr/bin/
    popd > /dev/null || ( pr_error "Bug: ${FUNCNAME[*]} Push/popd failed?" && return 1 )
    rm -rf "${build_dir}"
}

function inst_niri {
    local build_dir
    build_dir="$(mktemp -d)"
    git clone https://github.com/YaLTeR/niri.git "${build_dir}" &> /dev/null
    pushd "${build_dir}" > /dev/null || ( pr_error "Bug: ${FUNCNAME[*]} Push/popd failed?" && return 1 )
    cargo build --release -q
    sudo install -m 755 target/release/niri /usr/bin/
    # XXX(luna) the systemd file looks in /usr/bin for niri-session..
    sudo install -m 755 resources/niri-session /usr/bin/
    sudo install -m 755 resources/niri.desktop /usr/share/wayland-sessions/
    sudo install -m 755 resources/niri-portals.conf /usr/share/xdg-desktop-portal/
    sudo install -m 755 resources/niri.service /etc/systemd/user/
    sudo install -m 755 resources/niri-shutdown.target /etc/systemd/user/
    popd > /dev/null || ( pr_error "Bug: ${FUNCNAME[*]} Push/popd failed?" && return 1 )
    rm -rf "${build_dir}"
}

function inst_bspwm_deps {
    sudo apt-get update -y > /dev/null
    pr_info "Installing bspwm"
    sudo apt-get install -y bspwm > /dev/null
    pr_info "Installing bspwmrc deps"
    sudo apt-get install -y picom sxhkd network-manager-gnome polybar edid-decode suckless-tools feh alacritty fonts-font-awesome > /dev/null
    pr_info "Installing sxhkdrc deps"
    sudo apt-get install -y brightnessctl pulseaudio-utils maim xclip rofi > /dev/null
}

function inst_niri_deps {
    sudo apt-get update -y > /dev/null
    pr_info "Installing niri build deps"
    inst_rustup
    sudo apt-get install -y gcc clang libudev-dev libgbm-dev libxkbcommon-dev \
        libegl1-mesa-dev libwayland-dev libinput-dev libdbus-1-dev \
        libsystemd-dev libseat-dev libpipewire-0.3-dev libpango1.0-dev \
        libdisplay-info-dev > /dev/null
    pr_info "Building and Installing niri"
    inst_niri # armadyl forgive me
    pr_info "Installing xwayland-satellite"
    sudo apt-get -y install libxcb-cursor-dev libxcb1-dev > /dev/null
    pr_info "Building and Installing xwayland-satellite"
    inst_xwayland_satellite
    pr_info "Installing niri runtime deps"
    sudo apt-get install -y network-manager-gnome alacritty brightnessctl \
        pulseaudio-utils fuzzel swaybg waybar > /dev/null
}

# Environment Installation Functions

function inst_shell_env {
    pr_info "Installing shell environment"
    cp "${LDF_STAGING}/dot-bashrc" "${LDF_DEST}/.bashrc"
}

function inst_editor_env {
    pr_info "Installing editor environment"
    meta_inst_dot_config nvim
}

function inst_bspwm_env {
    pr_info "Installing bspwm environment"
    meta_inst_dot_config bspwm
    meta_inst_dot_config polybar
    meta_inst_dot_config sxhkd
    chmod +x "${LDF_DEST}/.config/bspwm/bspwmrc"
}

function inst_niri_env {
    pr_info "Installing niri environment"
    meta_inst_dot_config niri
    meta_inst_dot_config waybar
}

function prompt_execute {
    read -p "Execute? (y/n) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# "main"
pr "Standing up staging directory..."
get_dots || exit 1

pr "Install bspwm deps and env"
if prompt_execute; then
    inst_bspwm_deps
    inst_bspwm_env
else
    pr_info "skipped!"
fi

pr "Install niri deps and env"
if prompt_execute; then
    inst_niri_deps
    inst_niri_env
else
    pr_info "skipped!"
fi

pr "Install shell env"
if prompt_execute; then
    inst_shell_env
else
    pr_info "skipped!"
fi

pr "Install editor env"
if prompt_execute; then
    inst_editor_env
else
    pr_info "skipped!"
fi

pr "Installing bin utilities"
if prompt_execute; then
    meta_inst_dot_local_bin cfgedit
else
    pr_info "skipped!"
fi

if test "${LDF_ERROR_COUNT}" -eq 0; then
    pr "Install Complete!"
else
    pr_error "Install encountered ${LDF_ERROR_COUNT} error(s)!"
fi
