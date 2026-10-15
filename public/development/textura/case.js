(() => {
  const status = document.querySelector('[data-tx-status]');
  const brief = document.querySelector('[data-tx-brief]');
  document.querySelectorAll('[data-copy-brief]').forEach((button) => {
    button.addEventListener('click', async () => {
      const text = brief?.textContent?.trim() || 'TEXTURA — luxury specialty coffee website concept by OSGARD Development.';
      try {
        if (navigator.clipboard?.writeText && window.isSecureContext) {
          await navigator.clipboard.writeText(text);
        } else {
          const area = document.createElement('textarea');
          area.value = text; area.setAttribute('readonly', '');
          area.style.position = 'fixed'; area.style.opacity = '0';
          document.body.appendChild(area); area.select();
          const copied = document.execCommand('copy'); area.remove();
          if (!copied) throw new Error('Clipboard unavailable');
        }
        if (status) status.textContent = document.documentElement.lang === 'ru' ? 'Краткое описание скопировано.' : document.documentElement.lang === 'ar' ? 'تم نسخ ملخص المشروع.' : 'Project brief copied.';
      } catch {
        if (status) status.textContent = document.documentElement.lang === 'ru' ? 'Не удалось скопировать автоматически — выделите описание выше.' : document.documentElement.lang === 'ar' ? 'تعذر النسخ تلقائياً — حدّد الملخص يدوياً.' : 'Copy unavailable — select the brief manually.';
      }
    });
  });
})();
