#!/usr/bin/env bash
set -euo pipefail

USERNAME="${USERNAME:-fuchsia}"
DEV_PASSWORD="${DEV_PASSWORD:-fuchsia}"
HOME_DIR="/home/${USERNAME}"

mkdir -p /run/sshd "${HOME_DIR}/.ssh" "${HOME_DIR}/fuchsia" "${HOME_DIR}/.cache/ccache"
chmod 700 "${HOME_DIR}/.ssh"

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
