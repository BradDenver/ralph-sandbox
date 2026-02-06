# Ralph Sandbox Template
# Extends the official Claude Code sandbox with ralph-sandbox plugin pre-installed

FROM docker/sandbox-templates:claude-code

USER root

# Copy plugin to staging location
COPY .claude-plugin /opt/ralph-plugin/.claude-plugin
COPY plugin /opt/ralph-plugin/plugin
COPY scripts /opt/ralph-plugin/scripts

# Create entrypoint script
RUN printf '#!/bin/bash\n\
mkdir -p ~/.claude/commands ~/.claude/skills ~/.claude/agents ~/.claude/rules\n\
cp -r /opt/ralph-plugin/plugin/commands/* ~/.claude/commands/ 2>/dev/null || true\n\
cp -r /opt/ralph-plugin/plugin/skills/* ~/.claude/skills/ 2>/dev/null || true\n\
cp -r /opt/ralph-plugin/plugin/agents/* ~/.claude/agents/ 2>/dev/null || true\n\
cp -r /opt/ralph-plugin/plugin/rules/* ~/.claude/rules/ 2>/dev/null || true\n\
mkdir -p ~/bin\n\
cp /opt/ralph-plugin/scripts/*.sh ~/bin/ 2>/dev/null || true\n\
chmod +x ~/bin/*.sh 2>/dev/null || true\n\
exec "$@"\n' > /usr/local/bin/ralph-entrypoint.sh && chmod 755 /usr/local/bin/ralph-entrypoint.sh

USER agent

ENTRYPOINT ["/usr/local/bin/ralph-entrypoint.sh"]
CMD ["claude"]
