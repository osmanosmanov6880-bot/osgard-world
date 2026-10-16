"""Tests local delivery and route shells. Does not automate a browser."""
import functools
import importlib.util
from pathlib import Path
from http.server import ThreadingHTTPServer
from urllib.request import build_opener, ProxyHandler
from urllib.error import HTTPError
import threading
import re
spec=importlib.util.spec_from_file_location('preview','delivery/START.py')
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
server=ThreadingHTTPServer(('127.0.0.1',0),functools.partial(module.Handler,directory=str(Path('dist').resolve())))
threading.Thread(target=server.serve_forever,daemon=True).start()
base='http://127.0.0.1:'+str(server.server_port)
client=build_opener(ProxyHandler({}))
try:
 for route in ['/', '/teams/', '/deliveries/', '/workspace/overview/', '/account/', '/learning/organizer/', '/learning/campus/', '/workspace/', '/intelligence/', '/play/', '/development/', '/play/world/vector-zero/', '/play/world/null-shift/', '/learning/project/', '/lectures/how-language-models-work/', '/tedes/project/', '/development/phantom/', '/development/merakki/', '/data/', '/games/time/', '/r/sample-card']:
  with client.open(base+route) as response:
   html=response.read().decode();assert response.status==200;assert '<title>' in html,route
   assert 'rel="canonical"' in html,route
   if route in ['/','/intelligence/','/play/','/development/']:
    for asset in re.findall(r'(?:src|href)="(/assets/[^"<>]+)"',html):
     with client.open(base+asset) as resource: assert resource.status==200 and len(resource.read())>100,asset
 for route in ['/brand/favicon.svg','/brand/preview-world.png','/brand/preview-intelligence.png','/brand/preview-play.png','/brand/fonts/CormorantGaramond-0.ttf','/brand/fonts/SpaceGrotesk-0.ttf']:
  with client.open(base+route) as response:assert response.status==200 and len(response.read())>100,route
 for missing in ['/assets/missing-file.js','/missing-route','/learning/unknown','/api/not-connected','/brand/fonts/']:
  try:client.open(base+missing);raise AssertionError('Missing route or asset returned 200: '+missing)
  except HTTPError as error:assert error.code==404;assert 'Этот маршрут' in error.read().decode()
 with client.open(base+'/') as response:assert response.headers.get('X-Content-Type-Options')=='nosniff'
 print('HTTP PASS: 21 deep links, built entry assets, six brand assets, five real 404 responses and local headers')
finally:
 server.shutdown();server.server_close()
