FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN groupadd --system --gid 10001 osgard \
    && useradd --system --uid 10001 --gid osgard --home-dir /nonexistent --shell /usr/sbin/nologin osgard \
    && install -d -o osgard -g osgard /app /var/lib/remix-guard

COPY --chown=osgard:osgard server/remix_guard.py /app/remix_guard.py
WORKDIR /app
USER 10001:10001
EXPOSE 8081
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8081/health', timeout=4)"

CMD ["python", "remix_guard.py", "--host", "0.0.0.0", "--port", "8081", "--upstream", "http://remix-api:8080", "--database", "/var/lib/remix-guard/terminal.sqlite3"]
