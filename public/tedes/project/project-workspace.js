export const PROJECT_SCHEMA = "tedes-studio-project/v1";
export const MAX_PROJECT_POSITIONS = 30;
export const MAX_IMPORT_BYTES = 1024 * 1024;

const COLLECTIONS = new Set(["FORMA", "LINEA", "MATERIA"]);
const FINISHES = new Set(["Antique brass", "Matte black", "Satin bronze", "Polished chrome", "Brushed steel", "Graphite"]);
const HANDLES = new Set(["ARC", "EDGE", "LINE"]);
const LOCKS = new Set(["Not specified", "Privacy", "Passage", "Key"]);

export function cleanProjectText(value, max = 120) {
  return String(value ?? "").replace(/[<>]/g, "").slice(0, max);
}

function nextPositionId(used) {
  for (let n = 1; n <= 999; n += 1) {
    const id = "D-" + String(n).padStart(3, "0");
    if (!used.has(id)) {
      used.add(id);
      return id;
    }
  }
  throw new Error("Слишком много позиций для нумерации.");
}

export function normalizeProjectPosition(position, index = 0, usedIds = new Set()) {
  if (!position || typeof position !== "object" || Array.isArray(position)) {
    throw new Error("Одна из позиций имеет неверный формат.");
  }
  const candidate = typeof position.id === "string" && /^D-\d{3}$/.test(position.id) && !usedIds.has(position.id)
    ? position.id
    : null;
  const id = candidate || nextPositionId(usedIds);
  usedIds.add(id);
  const widthRaw = Number(position.width);
  const heightRaw = Number(position.height);
  return {
    id,
    zone: cleanProjectText(position.zone || "Unassigned zone", 80) || "Unassigned zone",
    collection: COLLECTIONS.has(position.collection) ? position.collection : "FORMA",
    finish: FINISHES.has(position.finish) ? position.finish : "Antique brass",
    handle: HANDLES.has(position.handle) ? position.handle : "ARC",
    lock: LOCKS.has(position.lock) ? position.lock : "Not specified",
    width: Math.max(400, Math.min(1800, Math.round(Number.isFinite(widthRaw) && widthRaw ? widthRaw : 900))),
    height: Math.max(1500, Math.min(3000, Math.round(Number.isFinite(heightRaw) && heightRaw ? heightRaw : 2100))),
    ...(typeof position.sku === "string" && position.sku.trim()
      ? { sku: cleanProjectText(position.sku.trim(), 40) }
      : {}),
  };
}

export function normalizeProjectDocument(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("JSON должен содержать объект проекта.");
  }
  if (value.schema && ![PROJECT_SCHEMA, "tedes-project-demo/v1"].includes(value.schema)) {
    throw new Error("Версия файла не поддерживается. Нужен экспорт TEDES Studio в JSON.");
  }
  const doors = Array.isArray(value.doors)
    ? value.doors
    : Array.isArray(value.project?.doors)
      ? value.project.doors
      : null;
  if (!doors) throw new Error("В JSON не найден массив doors.");
  if (doors.length > MAX_PROJECT_POSITIONS) {
    throw new Error("Файл содержит больше " + MAX_PROJECT_POSITIONS + " позиций. Разделите проект на несколько файлов.");
  }
  const used = new Set();
  const normalized = doors.map((door, index) => normalizeProjectPosition(door, index, used));
  const projectName = cleanProjectText(value.projectName || value.project?.name || "Imported TEDES project", 80) || "Imported TEDES project";
  return {
    schema: PROJECT_SCHEMA,
    projectName,
    doors: normalized,
    updatedAt: typeof value.updatedAt === "string" ? value.updatedAt : "",
  };
}

export function parseProjectDocument(text) {
  if (typeof text !== "string") throw new Error("Содержимое файла должно быть текстом JSON.");
  if (new TextEncoder().encode(text).byteLength > MAX_IMPORT_BYTES) {
    throw new Error("Файл больше 1 МБ. Экспортируйте компактную ведомость и повторите импорт.");
  }
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new Error("Файл не является корректным JSON.");
  }
  return normalizeProjectDocument(parsed);
}

function signature(position) {
  return [
    position.sku || "",
    position.zone || "",
    position.collection || "",
    position.finish || "",
    position.handle || "",
    position.lock || "",
    position.width || "",
    position.height || "",
  ].join("\u001f").toLowerCase();
}

export function mergeProjectDocuments(current, incoming) {
  const base = normalizeProjectDocument(current);
  const addition = normalizeProjectDocument(incoming);
  const combined = base.doors.map((door) => ({ ...door }));
  const seen = new Set(combined.map(signature));
  const used = new Set(combined.map((door) => door.id));
  let skippedDuplicates = 0;
  for (const door of addition.doors) {
    const key = signature(door);
    if (seen.has(key)) {
      skippedDuplicates += 1;
      continue;
    }
    const normalized = normalizeProjectPosition(door, combined.length, used);
    combined.push(normalized);
    seen.add(signature(normalized));
  }
  if (combined.length > MAX_PROJECT_POSITIONS) {
    throw new Error("Объединение даст " + combined.length + " позиций. Лимит проекта — " + MAX_PROJECT_POSITIONS + ".");
  }
  return {
    project: {
      schema: PROJECT_SCHEMA,
      projectName: base.doors.length ? base.projectName : addition.projectName,
      doors: combined,
      updatedAt: new Date().toISOString(),
    },
    added: combined.length - base.doors.length,
    skippedDuplicates,
  };
}

export function safeCsvCell(value) {
  const raw = String(value ?? "");
  const protectedValue = /^[\s\x00-\x1f]*[=+\-@]/.test(raw) ? "'" + raw : raw;
  return '"' + protectedValue.replace(/"/g, '""') + '"';
}

const KEY = "tedes-studio-project-v1";
const $ = (id) => document.getElementById(id);
const escapeHtml = (value) => String(value ?? "").replace(/[&<>"']/g, (character) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
}[character]));
const finishColor = (finish) => ({
  "Antique brass": "#b89550",
  "Matte black": "#34352f",
  "Satin bronze": "#927654",
  "Polished chrome": "#cbd0cb",
  "Brushed steel": "#999a90",
  "Graphite": "#4a4b44",
}[finish] || "#b89550");

let project = { schema: PROJECT_SCHEMA, projectName: "Residence / North Wing", doors: [], updatedAt: "" };
let storageCorrupt = false;
let storageWritable = true;
let pendingImport = null;
let editingId = null;

function readProject() {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return { ok: true, exists: false, data: { ...project, doors: [] } };
    return { ok: true, exists: true, data: normalizeProjectDocument(JSON.parse(raw)) };
  } catch (error) {
    return { ok: false, exists: true, error, data: { ...project, doors: [] } };
  }
}

function save() {
  if (storageCorrupt) {
    $("storageStatus").textContent = "Локальные данные повреждены. Сначала восстановите проект через импорт JSON.";
    return false;
  }
  try {
    project.schema = PROJECT_SCHEMA;
    project.projectName = cleanProjectText($("projectName").value || "Untitled project", 80) || "Untitled project";
    project.updatedAt = new Date().toISOString();
    localStorage.setItem(KEY, JSON.stringify(project));
    storageWritable = true;
    $("storageStatus").textContent = "Сохранено локально · " + new Date(project.updatedAt).toLocaleString();
    return true;
  } catch {
    storageWritable = false;
    $("storageStatus").textContent = "Сохранение недоступно: экспортируйте резервную копию JSON.";
    return false;
  }
}

function download(filename, content, type) {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1500);
}

function render() {
  $("projectName").value = project.projectName;
  $("projectCount").textContent = project.doors.length + " " + (
    project.doors.length === 1 ? "позиция"
      : project.doors.length >= 2 && project.doors.length <= 4 ? "позиции" : "позиций"
  );
  $("projectSummary").textContent = project.doors.length
    ? "Последнее изменение: " + (project.updatedAt ? new Date(project.updatedAt).toLocaleString() : "в этой сессии") + ". Ведомость хранится в браузере."
    : "В проекте пока нет сохранённых дверных позиций.";
  $("emptyState").hidden = project.doors.length !== 0;
  $("tableWrap").hidden = project.doors.length === 0;
  $("exportJson").disabled = project.doors.length === 0;
  $("exportCsv").disabled = project.doors.length === 0;
  $("clearProject").disabled = project.doors.length === 0;
  $("positionRows").innerHTML = project.doors.map((door) =>
    '<tr><td><span class="zone-name">' + escapeHtml(door.zone) + '</span><span class="zone-meta">' +
    escapeHtml(door.id) + (door.sku ? " · " + escapeHtml(door.sku) : "") +
    '</span></td><td>' + escapeHtml(door.collection) +
    '</td><td><span class="finish-chip" style="background:' + finishColor(door.finish) + '"></span>' + escapeHtml(door.finish) +
    '</td><td>' + escapeHtml(door.handle) + " / " + escapeHtml(door.lock) +
    '</td><td>' + door.width + " × " + door.height +
    '</td><td class="no-print"><div class="row-buttons"><button class="icon-btn edit" type="button" data-edit="' +
    escapeHtml(door.id) + '" aria-label="Редактировать ' + escapeHtml(door.zone) + '" title="Редактировать">Изменить</button>' +
    '<button class="icon-btn" type="button" data-duplicate="' + escapeHtml(door.id) +
    '" aria-label="Дублировать ' + escapeHtml(door.zone) + '" title="Дублировать">⧉</button>' +
    '<button class="icon-btn" type="button" data-remove="' + escapeHtml(door.id) +
    '" aria-label="Удалить ' + escapeHtml(door.zone) + '" title="Удалить">×</button></div></td></tr>'
  ).join("");
  $("storageStatus").dataset.readonly = String(storageCorrupt);
}

function showDialog(dialog) {
  if (typeof dialog.showModal === "function") dialog.showModal();
  else dialog.setAttribute("open", "");
}
function closeDialog(dialog) {
  if (typeof dialog.close === "function") dialog.close();
  else dialog.removeAttribute("open");
}

function openEditor(id) {
  const door = project.doors.find((item) => item.id === id);
  if (!door) return;
  editingId = id;
  $("editZone").value = door.zone;
  $("editSku").value = door.sku || "";
  $("editCollection").value = door.collection;
  $("editFinish").value = door.finish;
  $("editHandle").value = door.handle;
  $("editLock").value = door.lock;
  $("editWidth").value = String(door.width);
  $("editHeight").value = String(door.height);
  $("editMessage").textContent = "";
  showDialog($("editDialog"));
  $("editZone").focus();
}

function saveEditor() {
  const form = $("editForm");
  if (!form.reportValidity()) return;
  const width = Number($("editWidth").value);
  const height = Number($("editHeight").value);
  if (!Number.isInteger(width) || width < 400 || width > 1800) {
    $("editMessage").textContent = "Ширина должна быть целым числом от 400 до 1800 мм.";
    $("editWidth").focus();
    return;
  }
  if (!Number.isInteger(height) || height < 1500 || height > 3000) {
    $("editMessage").textContent = "Высота должна быть целым числом от 1500 до 3000 мм.";
    $("editHeight").focus();
    return;
  }
  const index = project.doors.findIndex((item) => item.id === editingId);
  if (index < 0) return closeDialog($("editDialog"));
  const current = project.doors[index];
  const updated = normalizeProjectPosition({
    ...current,
    zone: $("editZone").value.trim(),
    sku: $("editSku").value.trim(),
    collection: $("editCollection").value,
    finish: $("editFinish").value,
    handle: $("editHandle").value,
    lock: $("editLock").value,
    width,
    height,
  }, index, new Set(project.doors.filter((item) => item.id !== editingId).map((item) => item.id)));
  project.doors[index] = updated;
  const saved = save();
  render();
  closeDialog($("editDialog"));
  $("requestMessage").textContent = saved
    ? "Позиция обновлена."
    : "Позиция обновлена только в текущей сессии. Скачайте JSON-резервную копию.";
}

function openImportPreview(parsed, filename) {
  pendingImport = { ...parsed, filename };
  $("importSummary").textContent = "Файл: " + filename + ". Проект «" + parsed.projectName + "», позиций: " + parsed.doors.length + ". Ничего не изменено — выберите режим импорта.";
  $("importMessage").textContent = "";
  $("importMerge").disabled = storageCorrupt;
  if (storageCorrupt) $("importMessage").textContent = "Текущее хранилище повреждено: доступно только безопасное восстановление с заменой.";
  showDialog($("importDialog"));
}

function applyImport(mode) {
  if (!pendingImport) return;
  try {
    let next;
    if (mode === "replace") {
      if (!window.confirm("Заменить текущий проект данными файла «" + pendingImport.filename + "»? Сначала скачайте резервную копию, если она нужна.")) return;
      next = {
        schema: PROJECT_SCHEMA,
        projectName: pendingImport.projectName,
        doors: pendingImport.doors.map((door, index, all) => normalizeProjectPosition(door, index, new Set(all.slice(0, index).map((item) => item.id)))),
        updatedAt: new Date().toISOString(),
      };
    } else {
      const merged = mergeProjectDocuments(project, pendingImport);
      next = merged.project;
      $("importMessage").textContent = "Добавлено: " + merged.added + "; пропущено точных дублей: " + merged.skippedDuplicates + ".";
    }
    project = next;
    storageCorrupt = false;
    $("projectName").value = project.projectName;
    const saved = save();
    render();
    closeDialog($("importDialog"));
    $("requestMessage").textContent = mode === "replace"
      ? (saved ? "Проект восстановлен из JSON." : "Файл загружен в текущую сессию, но браузер не сохранил его. Экспортируйте копию.")
      : (saved ? "Позиции объединены из JSON." : "Позиции объединены в текущей сессии, но не сохранены браузером. Экспортируйте копию.");
    pendingImport = null;
  } catch (error) {
    $("importMessage").textContent = error instanceof Error ? error.message : "Импорт не выполнен.";
  }
}

if (typeof document !== "undefined") {
const loaded = readProject();
project = loaded.data;
if (!loaded.ok) {
  storageCorrupt = true;
  $("storageStatus").textContent = "Не удалось прочитать локальный проект. Он не перезаписан. Восстановите его из JSON.";
  $("requestMessage").textContent = "Локальное хранилище содержит некорректные данные. Используйте импорт JSON и выберите замену, чтобы восстановить проект.";
} else if (!loaded.exists) {
  $("storageStatus").textContent = "Локальный проект ещё не найден. Откройте каталог или студию, чтобы начать.";
} else {
  $("storageStatus").textContent = "Проект восстановлен из этого браузера.";
}
render();

$("projectName").addEventListener("input", () => {
  project.projectName = cleanProjectText($("projectName").value, 80) || "Untitled project";
  const saved = save();
  $("projectSummary").textContent = saved
    ? "Название проекта обновлено."
    : "Название изменено только в текущей сессии; при необходимости скачайте JSON-копию.";
});

$("positionRows").addEventListener("click", (event) => {
  const edit = event.target.closest("[data-edit]");
  const remove = event.target.closest("[data-remove]");
  const duplicate = event.target.closest("[data-duplicate]");
  if (edit) return openEditor(edit.dataset.edit);
  if (remove) {
    project.doors = project.doors.filter((door) => door.id !== remove.dataset.remove);
    const saved = save();
    render();
    $("requestMessage").textContent = saved
      ? "Позиция удалена из локальной ведомости."
      : "Позиция удалена только в текущей сессии: экспортируйте резервную копию.";
    return;
  }
  if (duplicate) {
    if (project.doors.length >= MAX_PROJECT_POSITIONS) {
      $("requestMessage").textContent = "Достигнут лимит: " + MAX_PROJECT_POSITIONS + " позиций.";
      return;
    }
    const source = project.doors.find((door) => door.id === duplicate.dataset.duplicate);
    if (!source) return;
    const used = new Set(project.doors.map((door) => door.id));
    const newId = nextPositionId(used);
    project.doors.push({ ...source, id: newId, zone: cleanProjectText(source.zone + " (копия)", 80) });
    const saved = save();
    render();
    $("requestMessage").textContent = saved ? "Копия добавлена." : "Копия создана только в текущей сессии. Экспортируйте копию.";
  }
});

$("editForm").addEventListener("submit", (event) => event.preventDefault());
$("saveEdit").addEventListener("click", saveEditor);
$("cancelEdit").addEventListener("click", () => closeDialog($("editDialog")));

$("clearProject").addEventListener("click", () => {
  if (!project.doors.length) return;
  if (!window.confirm("Удалить все позиции из локального проекта? Экспортируйте резервную копию перед очисткой.")) return;
  project.doors = [];
  const saved = save();
  render();
  $("requestMessage").textContent = saved
    ? "Проект очищен в этом браузере."
    : "Проект очищен только в текущей сессии; браузер не сохранил изменение.";
});

$("importJson").addEventListener("click", () => $("importFile").click());
$("importFile").addEventListener("change", async () => {
  const file = $("importFile").files?.[0];
  $("importFile").value = "";
  if (!file) return;
  if (file.size > MAX_IMPORT_BYTES) {
    $("requestMessage").textContent = "Файл больше 1 МБ. Выберите компактный JSON.";
    return;
  }
  try {
    const parsed = parseProjectDocument(await file.text());
    openImportPreview(parsed, cleanProjectText(file.name, 160));
  } catch (error) {
    $("requestMessage").textContent = error instanceof Error ? error.message : "Не удалось прочитать JSON.";
  }
});
$("importReplace").addEventListener("click", () => applyImport("replace"));
$("importMerge").addEventListener("click", () => applyImport("merge"));
$("cancelImport").addEventListener("click", () => {
  pendingImport = null;
  closeDialog($("importDialog"));
});

$("exportJson").addEventListener("click", () => {
  if (!project.doors.length) return;
  const file = {
    schema: PROJECT_SCHEMA,
    mode: "demonstration",
    projectName: project.projectName,
    updatedAt: project.updatedAt,
    doors: project.doors,
    notice: "Демонстрационная ведомость. Цена, наличие и механическая совместимость не подтверждены.",
  };
  download("tedes-project.json", JSON.stringify(file, null, 2), "application/json;charset=utf-8");
  $("requestMessage").textContent = "JSON-резервная копия подготовлена. Её можно импортировать в эту рабочую область или в TEDES Studio.";
});

$("exportCsv").addEventListener("click", () => {
  if (!project.doors.length) return;
  const columns = ["id", "zone", "sku", "collection", "finish", "handle", "lock", "width_mm", "height_mm"];
  const rows = project.doors.map((door) => [door.id, door.zone, door.sku || "", door.collection, door.finish, door.handle, door.lock, door.width, door.height]);
  const csv = [columns, ...rows].map((row) => row.map(safeCsvCell).join(",")).join("\r\n");
  download("tedes-project.csv", "\ufeff" + csv, "text/csv;charset=utf-8");
  $("requestMessage").textContent = "CSV-ведомость подготовлена. Перед использованием проверьте параметры с производителем.";
});

$("requestForm").addEventListener("submit", (event) => {
  event.preventDefault();
  const name = cleanProjectText($("contactName").value.trim(), 100);
  const email = $("contactEmail").value.trim().slice(0, 180);
  const company = cleanProjectText($("company").value.trim(), 120);
  const notes = String($("notes").value || "").replace(/\r/g, "").slice(0, 1200);
  if (!name || !email || !$("contactEmail").checkValidity()) {
    $("requestMessage").textContent = "Укажите контактное лицо и корректный email.";
    (!name ? $("contactName") : $("contactEmail")).focus();
    return;
  }
  if (!project.doors.length) {
    $("requestMessage").textContent = "Добавьте хотя бы одну позицию в проект перед формированием запроса.";
    return;
  }
  const request = { contactName: name, email, company, notes, preparedAt: new Date().toISOString(), delivery: "LOCAL FILE ONLY — NOT SENT TO TEDES OR ANY SUPPLIER." };
  const snapshot = {
    schema: PROJECT_SCHEMA,
    mode: "demonstration",
    projectName: project.projectName,
    updatedAt: project.updatedAt,
    doors: project.doors,
    request,
    notice: "Запрос создан локально и не отправлен. Цены, наличие и совместимость не подтверждены.",
  };
  const lines = [
    "TEDES — ЗАПРОС НА КОММЕРЧЕСКОЕ ПРЕДЛОЖЕНИЕ",
    "ДЕМОНСТРАЦИОННЫЙ ФАЙЛ · НЕ ОТПРАВЛЕН",
    "",
    "Проект: " + project.projectName,
    "Контакт: " + name,
    "Email: " + email,
    "Компания: " + company,
    "Комментарий: " + notes,
    "",
    "Позиций: " + project.doors.length,
    "",
    ...project.doors.map((door, index) => (index + 1) + ". " + door.zone + " | " + (door.sku || "DEMO / " + door.id) + " | " + door.collection + " | " + door.finish + " | " + door.handle + " / " + door.lock + " | " + door.width + " × " + door.height + " мм"),
    "",
    "Этот файл сформирован локально и не отправлен поставщику. Цена, наличие, технические характеристики и совместимость не подтверждены.",
  ].join("\r\n");
  download("tedes-request-brief.txt", lines, "text/plain;charset=utf-8");
  download("tedes-project-request.json", JSON.stringify(snapshot, null, 2), "application/json;charset=utf-8");
  $("requestMessage").textContent = "Подготовлены текстовый запрос и JSON с полем doors, пригодный для обратного импорта. Ничего не отправлено.";
});

window.addEventListener("storage", (event) => {
  if (event.key !== KEY) return;
  const result = readProject();
  if (!result.ok) {
    storageCorrupt = true;
    $("storageStatus").textContent = "Изменение в другой вкладке содержит повреждённые данные. Хранилище не перезаписано.";
    return;
  }
  storageCorrupt = false;
  project = result.data;
  render();
  $("requestMessage").textContent = "Проект обновлён из другой вкладки.";
});
}
