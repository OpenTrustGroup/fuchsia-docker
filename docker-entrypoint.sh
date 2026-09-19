#!/usr/bin/env bash
set -euo pipefail

USERNAME="${USERNAME:-fuchsia}"
DEV_PASSWORD="${DEV_PASSWORD:-fuchsia}"
HOME_DIR="/home/${USERNAME}"

configure_kvm_group() {
    if [[ ! -e /dev/kvm ]]; then
        return 0
    fi

    local kvm_gid
    local kvm_group
    kvm_gid="$(stat -c '%g' /dev/kvm)"
    kvm_group="$(getent group "${kvm_gid}" | cut -d: -f1 || true)"

    if [[ -z "${kvm_group}" ]]; then
        kvm_group="kvm"
        if getent group "${kvm_group}" > /dev/null; then
            groupmod --gid "${kvm_gid}" "${kvm_group}"
        else
            groupadd --gid "${kvm_gid}" "${kvm_group}"
        fi
    fi

    usermod -aG "${kvm_group}" "${USERNAME}"
}

configure_tun_access() {
    # The image cannot ship /dev/net/tun, because Docker mounts a fresh /dev
    # over it at start. Create the node here when it was not passed in, which
    # succeeds only with CAP_MKNOD, and make it accessible to the dev user the
    # way a Linux host presents it. Opening it still requires the device cgroup
    # to allow char 10:200, so keep every step non-fatal: a container without
    # tun support must still start, just without tap networking.
    if [[ ! -e /dev/net/tun ]]; then
        mkdir -p /dev/net
        mknod /dev/net/tun c 10 200 2> /dev/null || true
    fi

    if [[ -e /dev/net/tun ]]; then
        chmod 0666 /dev/net/tun 2> /dev/null || true
    fi
}

mkdir -p /run/sshd "${HOME_DIR}/.ssh" "${HOME_DIR}/fuchsia" "${HOME_DIR}/.cache/ccache"
chmod 700 "${HOME_DIR}/.ssh"
configure_kvm_group
configure_tun_access

for file in .bashrc .profile .bash_logout; do
    if [[ ! -e "${HOME_DIR}/${file}" && -e "/etc/skel/${file}" ]]; then
        install -m 644 -o "${USERNAME}" -g "${USERNAME}" "/etc/skel/${file}" "${HOME_DIR}/${file}"
    fi
done

if [[ ! -f "${HOME_DIR}/.bashrc" ]]; then
    install -m 644 -o "${USERNAME}" -g "${USERNAME}" /dev/null "${HOME_DIR}/.bashrc"
fi

if ! grep -qF 'export FUCHSIA_DIR="${HOME}/fuchsia"' "${HOME_DIR}/.bashrc"; then
    {
        printf '\n'
        printf '%s\n' 'export FUCHSIA_DIR="${HOME}/fuchsia"'
        printf '%s\n' 'export CCACHE_DIR="${HOME}/.cache/ccache"'
        printf '%s\n' 'export PATH="${FUCHSIA_DIR}/.jiri_root/bin:${FUCHSIA_DIR}/scripts:${PATH}"'
        printf '%s\n' 'if [ -f "${FUCHSIA_DIR}/scripts/fx-env.sh" ]; then source "${FUCHSIA_DIR}/scripts/fx-env.sh"; fi'
    } >> "${HOME_DIR}/.bashrc"
fi

if [[ -n "${DEV_PASSWORD}" ]]; then
    printf '%s:%s\n' "${USERNAME}" "${DEV_PASSWORD}" | chpasswd
fi

if [[ -f /ssh/authorized_keys ]]; then
    install -m 600 -o "${USERNAME}" -g "${USERNAME}" /ssh/authorized_keys "${HOME_DIR}/.ssh/authorized_keys"
elif compgen -G '/ssh/*.pub' > /dev/null; then
    cat /ssh/*.pub > "${HOME_DIR}/.ssh/authorized_keys"
    chown "${USERNAME}:${USERNAME}" "${HOME_DIR}/.ssh/authorized_keys"
    chmod 600 "${HOME_DIR}/.ssh/authorized_keys"
fi

chown "${USERNAME}:${USERNAME}" "${HOME_DIR}" "${HOME_DIR}/.ssh" "${HOME_DIR}/fuchsia" "${HOME_DIR}/.cache" "${HOME_DIR}/.cache/ccache" "${HOME_DIR}/.bashrc"
ssh-keygen -A

exec "$@"
