FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ssh-client curl ca-certificates jq sudo vim locales && \
    # gh CLI
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh && \
    # Cleanup
    apt-get clean && rm -rf /var/lib/apt/lists/*

# UTF-8 locale
RUN sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# GitHub SSH host key
RUN ssh-keyscan github.com >> /etc/ssh/ssh_known_hosts 2>/dev/null

# Dev user
RUN useradd -m -s /bin/bash -u 1000 dev && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER dev
WORKDIR /home/dev

# Claude Code (native installer)
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/dev/.local/bin:${PATH}"

# Codex CLI (OpenAI)
RUN curl -fsSL https://github.com/openai/codex/releases/latest/download/codex-linux-arm64.tar.gz \
    | tar xz -C /tmp && mv /tmp/codex /home/dev/.local/bin/codex

# Claude Code sandbox config: use weaker nested sandbox since container is already isolated
RUN mkdir -p ~/.claude && echo '{"sandbox":{"enableWeakerNestedSandbox":true}}' > ~/.claude/settings.json

# Global git pre-push hook: block pushes to non-origin remotes and protected branches
RUN mkdir -p ~/.config/git/hooks && cat > ~/.config/git/hooks/pre-push << 'HOOKEOF'
#!/bin/bash
# Global pre-push hook: only allow pushing to origin, block main/master branches
remote="$1"
url="$2"

# Only allow pushing to origin (the fork)
if [ "$remote" != "origin" ]; then
  echo "BLOCKED: push to '$remote' is not allowed. Only 'origin' (your fork) is permitted."
  exit 1
fi

# Block pushes to protected branches
while read local_ref local_sha remote_ref remote_sha; do
  branch="${remote_ref#refs/heads/}"
  case "$branch" in
    main|master)
      echo "BLOCKED: push to protected branch '$branch' is not allowed."
      echo "Push to a feature/task branch instead."
      exit 1
      ;;
  esac
done

exit 0
HOOKEOF
RUN chmod +x ~/.config/git/hooks/pre-push && \
    git config --global core.hooksPath ~/.config/git/hooks

# .bash_profile sources .bashrc for login shells
RUN echo '[ -f ~/.bashrc ] && . ~/.bashrc' > ~/.bash_profile

# Shell config
RUN echo '\n# Vi keybindings\nset -o vi\n\n# SSH agent from host\nexport SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock\n\n# History\nHISTSIZE=10000\nHISTFILESIZE=20000\nHISTCONTROL=ignoredups:erasedups\nshopt -s histappend\nPROMPT_COMMAND="history -a;$PROMPT_COMMAND"\n\n# Dangerous mode aliases (container is already sandboxed)\nalias clauded="claude --dangerously-skip-permissions"\nalias codexd="codex --dangerously-bypass-approvals-and-sandbox"' >> ~/.bashrc
