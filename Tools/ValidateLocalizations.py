#!/usr/bin/env python3
"""Check catalog completeness, format-argument parity, and source-key coverage."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / 'XcodeSize/XcodeSize'
catalog = json.loads((source / 'Core/Resources/Localizable.xcstrings').read_text())
assert catalog['sourceLanguage'] == 'en', 'The source language must remain English'
strings = catalog['strings']
languages = ('en', 'zh-Hans', 'zh-Hant', 'ja', 'ko')
errors = []
for key, entry in strings.items():
    for language in languages:
        unit = entry.get('localizations', {}).get(language, {}).get('stringUnit', {})
        value = unit.get('value', '')
        if not value or unit.get('state') != 'translated':
            errors.append(f'{language}: missing translation for {key!r}')
        if value.count('%@') != key.count('%@'):
            errors.append(f'{language}: format arguments differ for {key!r}')

keys = set()
for path in source.rglob('*.swift'):
    text = path.read_text()
    for match in re.finditer(r'L10n\.text\("((?:[^"\\]|\\.)*)"', text):
        key = json.loads('"' + match.group(1) + '"')
        keys.add(key)
        if key not in strings:
            errors.append(f'{path.name}: missing catalog key {key!r}')
    if path.name != 'Localization.swift' and re.search(r'[\u3400-\u9fff]', text):
        errors.append(f'{path.name}: unexpected hardcoded Chinese text')

if errors:
    raise SystemExit('\n'.join(errors))
print(f'{len(strings)} catalog entries; all {len(languages)} languages complete ({", ".join(languages)}); {len(keys)} source keys verified.')
