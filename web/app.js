// SPDX-License-Identifier: Apache-2.0
'use strict';
const tabs = [...document.querySelectorAll('[role="tab"]')];
function selectTab(tab) {
  tabs.forEach(item => {
    const selected = item === tab;
    item.setAttribute('aria-selected', String(selected));
    item.tabIndex = selected ? 0 : -1;
    document.getElementById(item.getAttribute('aria-controls')).hidden = !selected;
  });
  document.querySelectorAll('[data-side]').forEach(item => item.classList.toggle('selected', tab.id === `tab-${item.dataset.side}`));
}
tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => selectTab(tab));
  tab.addEventListener('keydown', event => {
    let next;
    if (event.key === 'ArrowRight') next = tabs[(index + 1) % tabs.length];
    if (event.key === 'ArrowLeft') next = tabs[(index + tabs.length - 1) % tabs.length];
    if (event.key === 'Home') next = tabs[0];
    if (event.key === 'End') next = tabs[tabs.length - 1];
    if (!next) return;
    event.preventDefault();
    selectTab(next);
    next.focus();
  });
});
const examples = {
  standard: {
    title: 'Clear the rebuildable clutter.',
    description: 'Clean compiler caches, old logs, and idle builds. Archives, release symbols, and source working copies stay out of Standard Clean.',
    folder: 'ModuleCache.noindex', path: '~/Library/Developer/Xcode/DerivedData/', method: 'Move to Trash',
    note: 'Protect a project’s location to keep it out of cleanup.'
  },
  deep: {
    title: 'Choose what you no longer need.',
    description: 'Keep the latest 1, 3, or 5 archive versions, including every build, or select all unprotected archives. Review the release-symbol impact before cleanup.',
    folder: 'MyApp.xcarchive', path: '~/Library/Developer/Xcode/Archives/', method: 'Move to Trash',
    note: 'Older releases need their own matching dSYMs. Protected locations always stay; additional confirmation is required.'
  }
};
document.querySelectorAll('[data-tier]').forEach(button => {
  button.addEventListener('click', () => {
    document.querySelectorAll('[data-tier]').forEach(item => {
      item.classList.toggle('active', item === button);
      item.setAttribute('aria-pressed', String(item === button));
    });
    const value = examples[button.dataset.tier];
    Object.entries(value).forEach(([key, text]) => { document.getElementById(`tier-${key}`).textContent = text; });
  });
});
const copyButton = document.getElementById('copy-command');
const status = document.getElementById('copy-status');
copyButton.addEventListener('click', async () => {
  const command = document.getElementById('install-command');
  try {
    await navigator.clipboard.writeText(command.textContent);
    status.textContent = 'Copied. Paste into Terminal to install.';
    copyButton.setAttribute('aria-label', 'Homebrew command copied');
    copyButton.querySelector('use').setAttribute('href', '#check');
  } catch {
    const range = document.createRange();
    range.selectNodeContents(command);
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    status.textContent = 'Command selected. Press ⌘C (or Ctrl+C) to copy.';
  }
});
