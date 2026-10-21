// Product explanation only. No file input, upload, conversion or network request.
for (const section of document.querySelectorAll('[data-file-actions]')) {
  const buttons = [...section.querySelectorAll('[data-select-action]')];
  const select = button => {
    for (const item of buttons) item.setAttribute('aria-pressed', String(item === button));
    for (const petal of section.querySelectorAll('[data-wheel-action]')) petal.dataset.active = String(petal.dataset.wheelAction === button.dataset.selectAction);
    const title = section.querySelector('[data-wheel-title]');
    const center = section.querySelector('[data-center-title]');
    if (title) title.textContent = button.dataset.label ?? '';
    if (center) center.textContent = button.dataset.shortLabel ?? '';
  };
  for (const button of buttons) {
    button.addEventListener('click', () => select(button));
    button.addEventListener('focus', () => select(button));
  }
}
