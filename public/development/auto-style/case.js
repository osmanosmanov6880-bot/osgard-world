(() => {
  "use strict";
  const button = document.querySelector("[data-copy-brief]");
  const status = document.getElementById("as-copy-status");
  const brief = document.getElementById("as-project-brief");
  if (button && status && brief) {
    button.addEventListener("click", async () => {
      const text = brief.textContent.trim();
      try {
        if (navigator.clipboard && window.isSecureContext) {
          await navigator.clipboard.writeText(text);
        } else {
          const field = document.createElement("textarea");
          field.value = text;
          field.setAttribute("readonly", "");
          field.style.position = "fixed";
          field.style.opacity = "0";
          document.body.appendChild(field);
          field.select();
          const copied = document.execCommand("copy");
          field.remove();
          if (!copied) throw new Error("Clipboard unavailable");
        }
        status.textContent = document.documentElement.lang === "ar"
          ? "تم نسخ وصف المشروع إلى الحافظة."
          : document.documentElement.lang === "en"
            ? "Project brief copied to clipboard."
            : "Описание проекта скопировано в буфер обмена.";
      } catch {
        status.textContent = document.documentElement.lang === "ar"
          ? "انسخ النص من الكتلة أدناه يدويًا."
          : document.documentElement.lang === "en"
            ? "Copy the project brief from the text block below."
            : "Скопируйте описание проекта вручную из блока ниже.";
      }
    });
  }
  document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
    anchor.addEventListener("click", () => {
      const target = document.querySelector(anchor.getAttribute("href"));
      if (target) target.setAttribute("tabindex", "-1");
    });
  });
})();
