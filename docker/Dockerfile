# Ralph Sandbox Template (Shape E)
# Extends the official Claude Code sandbox with ralph plugin pre-installed.
# tmux runs on the HOST, not inside the sandbox.

FROM docker/sandbox-templates:claude-code

USER root

# Install bun
RUN curl -fsSL https://bun.sh/install | bash && cp /root/.bun/bin/bun /usr/local/bin/bun

# Install Playwright system dependencies and browsers
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0t64 libnss3 libnspr4 libdbus-1-3 libatk1.0-0t64 \
    libatk-bridge2.0-0t64 libcups2t64 libdrm2 libxcb1 libxkbcommon0 \
    libatspi2.0-0t64 libx11-6 libxcomposite1 libxdamage1 libxext6 \
    libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libasound2t64 \
    libxshmfence1 fonts-liberation fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/*
RUN npx playwright install chromium

# Reinstall Claude Code via native installer to get current version
# The base image's install leaves method as 'unknown', breaking `claude update`.
# Native installer sets up proper config so future updates work at runtime.
USER agent
RUN curl -fsSL https://claude.ai/install.sh | bash
USER root

# Copy plugin to staging location (entrypoint copies to ~/.claude/ on startup)
COPY .claude-plugin /opt/ralph-plugin/.claude-plugin
COPY plugin /opt/ralph-plugin/plugin
COPY scripts /opt/ralph-plugin/scripts
RUN chmod -R a+r /opt/ralph-plugin/

# Create entrypoint that installs plugin after volumes are mounted
RUN printf '#!/bin/bash\n\
mkdir -p ~/.claude/commands ~/.claude/skills ~/.claude/agents ~/.claude/rules\n\
cp -r /opt/ralph-plugin/plugin/commands/* ~/.claude/commands/ 2>/dev/null || true\n\
cp -r /opt/ralph-plugin/plugin/skills/* ~/.claude/skills/ 2>/dev/null || true\n\
cp -r /opt/ralph-plugin/plugin/agents/* ~/.claude/agents/ 2>/dev/null || true\n\
cp -r /opt/ralph-plugin/plugin/rules/* ~/.claude/rules/ 2>/dev/null || true\n\
mkdir -p ~/bin\n\
cp /opt/ralph-plugin/scripts/*.sh ~/bin/ 2>/dev/null || true\n\
chmod +x ~/bin/*.sh 2>/dev/null || true\n\
cp /opt/ralph-plugin/plugin/settings.json ~/.claude/settings.json 2>/dev/null || true\n\
# Keep pnpm store outside workspace so it does not sync back to host\n\
echo "store-dir=/home/agent/.pnpm-store" > ~/.npmrc\n\
exec "$@"\n' > /usr/local/bin/ralph-entrypoint.sh && chmod 755 /usr/local/bin/ralph-entrypoint.sh


USER agent

ENTRYPOINT ["/usr/local/bin/ralph-entrypoint.sh"]
CMD ["claude"]
