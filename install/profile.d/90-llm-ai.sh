# LuicipherOS local AI defaults for login shells (ADR-0002).
# The authoritative copy is /etc/environment.d/90-llm-ai.conf; systemd user
# managers read that directly, this file mirrors it for non-systemd shells.
if [ -r /etc/environment.d/90-llm-ai.conf ]; then
  set -a
  . /etc/environment.d/90-llm-ai.conf
  set +a
fi