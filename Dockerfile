# token-watch — live viewer server (radar.py serve) in a container.
#
# The image is multi-arch by inheritance: python:3.12-slim is published for
# linux/amd64, linux/arm64 and more, so `docker build` works on Intel/AMD PCs,
# Apple Silicon and ARM servers alike. No third-party Python packages.
#
#   docker build -t token-watch .
#   docker run --rm -p 127.0.0.1:7777:7777 \
#     -v /path/to/vault:/vault:ro -v ~/.vault-radar:/data token-watch
#
# The hook normally runs on the host (Claude Code starts it on every tool call);
# the same image can run it too:  docker run --rm -i -v ~/.vault-radar:/data token-watch hook

FROM python:3.12-slim

LABEL org.opencontainers.image.title="token-watch" \
      org.opencontainers.image.description="See which notes your coding agent actually reads" \
      org.opencontainers.image.source="https://github.com/ksglmehmet/token-watch" \
      org.opencontainers.image.licenses="MIT"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=utf-8 \
    # Event log location inside the container (bind-mount the host's ~/.vault-radar here).
    VAULT_RADAR_HOME=/data \
    # Listen on all container interfaces; compose publishes the port on the host loopback only.
    VAULT_RADAR_BIND=0.0.0.0 \
    # Characters per token for the size estimate (≈3.6 for Turkish, ≈4.0 for English).
    VAULT_RADAR_CPT=3.8

WORKDIR /app
COPY radar.py ./
COPY ui/ ./ui/

# Run as an unprivileged user. UID/GID 1000 matches the first user on most Linux
# hosts, so files the container writes into /data stay owned by that user.
RUN groupadd --gid 1000 radar \
 && useradd --uid 1000 --gid radar --no-create-home --shell /usr/sbin/nologin radar \
 && mkdir -p /data /vault \
 && chown radar:radar /data
USER radar

EXPOSE 7777

# /api/vault answers only for a loopback Host header, which is what a request
# from inside the container sends.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:7777/api/vault', timeout=4).status == 200 else 1)"

ENTRYPOINT ["python", "/app/radar.py"]
CMD ["serve", "--vault", "/vault", "--no-open", "--port", "7777"]
