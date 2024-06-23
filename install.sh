#!/bin/bash
# ugh why are you reading this

LDF_REPO="https://github.com/Nitepone/dotfiles-pub.git"
LDF_SCRIPT_ROOT="$(realpath "$(dirname "$0")")"
LDF_STAGING="${LDF_SCRIPT_ROOT}"
LDF_DEST="${HOME}"

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
    test "${LDF_REPO}" != "${my_repo_url}"
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
    local dot_config_dest
    local dot_config_src

    dot_config_src="${LDF_STAGING}/dot-config/${1}/"
    dot_config_dest="${LDF_DEST}/.config/${1}"

    if test -z "$1"; then
        pr_error "Bug: ${FUNCNAME[*]} called without a subdir?.."
        return 1
    fi
    if ! test -d "${dot_config_src}"; then
        pr_error "Missing sources: ${dot_config_src}"
    fi

    mkdir -p "${dot_config_dest}"
    cp -r "${dot_config_src}/"* "${dot_config_dest}"
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


# "main"
pr "Standing up staging directory..."
get_dots || exit 1

pr "Installing all dotfiles"
inst_shell_env
inst_editor_env
inst_bspwm_env

if test "${LDF_ERROR_COUNT}" -eq 0; then
    pr "Install Complete!"
else
    pr_error "Install encountered ${LDF_ERROR_COUNT} error(s)!"
fi
