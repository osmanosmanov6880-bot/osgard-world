FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN groupadd --system --gid 10001 osgard \
    && useradd --system --uid 10001 --gid osgard --home-dir /nonexistent --shell /usr/sbin/nologin osgard \
    && install -d -o osgard -g osgard /app/server /app/empty /var/lib/osgard-core \
    && printf '%s\n' '<!doctype html><title>OSGARD Core API</title>' > /app/empty/index.html

COPY --chown=osgard:osgard server/ /app/server/

WORKDIR /app/server
USER 10001:10001
EXPOSE 4173
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:4173/api/core/health', timeout=3)"

CMD ["python", "core_server.py", "--root", "/app/empty", "--database", "/var/lib/osgard-core/core.sqlite3", "--host", "0.0.0.0", "--port", "4173", "--public-origin", "https://osgard.world"]
