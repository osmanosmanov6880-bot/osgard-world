import { readFile, writeFile } from 'node:fs/promises'
import { join, resolve } from 'node:path'

const root = resolve(process.argv[2] || '')
if (!process.argv[2]) throw new Error('Usage: node scripts/localize-godot-web-export.mjs <export-directory>')

const file = join(root, 'index.html')
let html = await readFile(file, 'utf8')
const originalFailure = `\tfunction displayFailureNotice(err) {
\t\tconsole.error(err);
\t\tif (err instanceof Error) {
\t\t\tsetStatusNotice(err.message);
\t\t} else if (typeof err === 'string') {
\t\t\tsetStatusNotice(err);
\t\t} else {
\t\t\tsetStatusNotice('An unknown error occurred.');
\t\t}
\t\tsetStatusMode('notice');
\t\tinitializing = false;
\t}`
const localizedFailure = `\tfunction displayFailureNotice(err) {
\t\tconsole.error(err);
\t\tconst errorText = err instanceof Error ? err.message : typeof err === 'string' ? err : '';
\t\tif (errorText.includes('WebGL2')) {
\t\t\tdocument.documentElement.lang = 'ru';
\t\t\tsetStatusNotice('Для запуска игры требуется WebGL 2.\\nИспользуйте браузер и видеокарту с поддержкой WebGL 2 и включённым аппаратным ускорением.');
\t\t\tconst backLink = document.createElement('a');
\t\t\tbackLink.href = '/games/#catalog';
\t\t\tbackLink.textContent = '← Вернуться к каталогу игр';
\t\t\tbackLink.setAttribute('aria-label', 'Вернуться к каталогу игр');
\t\t\tbackLink.style.cssText = 'display:inline-block;margin-top:1rem;color:#83e4dc;font-weight:700;text-decoration:underline;';
\t\t\tstatusNotice.appendChild(backLink);
\t\t} else if (errorText) {
\t\t\tdocument.documentElement.lang = 'ru';
\t\t\tsetStatusNotice(errorText);
\t\t} else {
\t\t\tdocument.documentElement.lang = 'ru';
\t\t\tsetStatusNotice('Не удалось запустить игру. Проверьте соединение и попробуйте ещё раз.');
\t\t}
\t\tsetStatusMode('notice');
\t\tinitializing = false;
\t}`
function replaceOnce(source, before, after, label) {
  const count = source.split(before).length - 1
  if (count !== 1) throw new Error(`Expected one ${label}; found ${count}`)
  return source.replace(before, after)
}
html = replaceOnce(html, originalFailure, localizedFailure, 'Godot failure handler')
html = replaceOnce(html, 'Your browser does not support the canvas tag.', 'Ваш браузер не поддерживает canvas.', 'canvas fallback')
html = replaceOnce(html, 'Your browser does not support JavaScript.', 'Для запуска игры включите JavaScript в браузере.', 'noscript fallback')
if (!html.includes('Для запуска игры требуется WebGL 2.') || !html.includes("backLink.href = '/games/#catalog'")) throw new Error('Russian WebGL fallback is incomplete')
await writeFile(file, html)
console.log('Localized Godot WebGL 2 fallback:', file)
