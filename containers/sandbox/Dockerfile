FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ssh-client curl ca-certificates jq sudo vim && \
    # gh CLI
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh && \
    # Node.js 22 LTS
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    # Claude Code
    npm install -g @anthropic-ai/claude-code && \
    # Cleanup
    apt-get clean && rm -rf /var/lib/apt/lists/*

# GitHub SSH host key
RUN ssh-keyscan github.com >> /etc/ssh/ssh_known_hosts 2>/dev/null

# Dev user
RUN useradd -m -s /bin/bash -u 1000 dev && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER dev
WORKDIR /home/dev

# .bash_profile sources .bashrc for login shells
RUN echo '[ -f ~/.bashrc ] && . ~/.bashrc' > ~/.bash_profile

# Shell config
RUN echo '\n# Vi keybindings\nset -o vi\n\n# SSH agent from host\nexport SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock\n\n# History\nHISTSIZE=10000\nHISTFILESIZE=20000\nHISTCONTROL=ignoredups:erasedups\nshopt -s histappend\nPROMPT_COMMAND="history -a;$PROMPT_COMMAND"' >> ~/.bashrc
