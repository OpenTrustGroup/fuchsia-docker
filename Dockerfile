# syntax=docker/dockerfile:1

FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=fuchsia
ARG USER_UID=1000
ARG USER_GID=1000
ARG NODE_MAJOR=22

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash-completion \
        build-essential \
        ca-certificates \
        ccache \
        clang \
        cmake \
        curl \
        file \
        g++ \
        git \
        gnupg \
        iproute2 \
        iputils-ping \
        less \
        locales \
        lsb-release \
        make \
        nano \
        ninja-build \
        openssh-client \
        openssh-server \
        pkg-config \
        python3 \
        python3-venv \
        rsync \
        sudo \
        tmux \
        unzip \
        vim \
        xauth \
        xz-utils \
        zip \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg -o /etc/apt/keyrings/packages.mozilla.org.asc \
    && gpg -n -q --import --import-options import-show /etc/apt/keyrings/packages.mozilla.org.asc \
        | awk 'BEGIN { found = 0 } /pub/ { getline; gsub(/^ +| +$/, ""); if ($0 == "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3") found = 1 } END { exit found ? 0 : 1 }' \
    && printf 'deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main\n' > /etc/apt/sources.list.d/mozilla.list \
    && printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' > /etc/apt/preferences.d/mozilla \
    && apt-get update \
    && apt-get install -y --no-install-recommends firefox \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && printf 'deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_%s.x nodistro main\n' "${NODE_MAJOR}" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g @openai/codex \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/bash "${USERNAME}" \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
    && chmod 0440 "/etc/sudoers.d/${USERNAME}" \
    && mkdir -p /run/sshd "/home/${USERNAME}/.ssh" "/home/${USERNAME}/fuchsia" "/home/${USERNAME}/.cache/ccache" /workspace \
    && chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}" /workspace \
    && chmod 700 "/home/${USERNAME}/.ssh"

RUN sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -ri 's/^#?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config \
    && sed -ri 's/^#?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -ri 's/^#?X11Forwarding .*/X11Forwarding yes/' /etc/ssh/sshd_config \
    && sed -ri 's/^#?X11UseLocalhost .*/X11UseLocalhost yes/' /etc/ssh/sshd_config \
    && if ! grep -qE '^X11Forwarding yes$' /etc/ssh/sshd_config; then printf '\nX11Forwarding yes\n' >> /etc/ssh/sshd_config; fi \
    && if ! grep -qE '^X11UseLocalhost yes$' /etc/ssh/sshd_config; then printf '\nX11UseLocalhost yes\n' >> /etc/ssh/sshd_config; fi \
    && printf '\nAllowUsers %s\n' "${USERNAME}" >> /etc/ssh/sshd_config

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    USER="${USERNAME}" \
    FUCHSIA_DIR="/home/${USERNAME}/fuchsia" \
    CCACHE_DIR="/home/${USERNAME}/.cache/ccache" \
    PATH="/home/${USERNAME}/fuchsia/.jiri_root/bin:/home/${USERNAME}/fuchsia/scripts:${PATH}"

RUN { \
        echo 'export FUCHSIA_DIR="${HOME}/fuchsia"'; \
        echo 'export CCACHE_DIR="${HOME}/.cache/ccache"'; \
        echo 'export PATH="${FUCHSIA_DIR}/.jiri_root/bin:${FUCHSIA_DIR}/scripts:${PATH}"'; \
        echo 'if [ -f "${FUCHSIA_DIR}/scripts/fx-env.sh" ]; then source "${FUCHSIA_DIR}/scripts/fx-env.sh"; fi'; \
    } >> "/home/${USERNAME}/.bashrc" \
    && chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.bashrc"

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

EXPOSE 22
WORKDIR /home/${USERNAME}

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
