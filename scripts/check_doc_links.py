#!/usr/bin/env python3
"""Check that relative links in Markdown files point to existing files and headings.

    check_doc_links.py FILE.md...
"""
import os
import re
import sys


def anchors(path):
    found = set()
    with open(path) as f:
        for line in f:
            m = re.match(r'#+ (.*)', line)
            if m:
                title = re.sub(r'[^\w\- ]', '', m.group(1).strip().lower())
                found.add(title.replace(' ', '-'))
    return found


bad = 0
for doc in sys.argv[1:]:
    with open(doc) as f:
        text = f.read()
    for m in re.finditer(r'\]\(([^)#\s]*)(#[^)\s]*)?\)', text):
        target, anchor = m.group(1), m.group(2)
        if re.match(r'[a-z]+:', target):
            continue
        path = os.path.normpath(os.path.join(os.path.dirname(doc), target)) if target else doc
        if not os.path.exists(path):
            print(f'{doc}: missing {target}')
            bad += 1
        elif anchor and path.endswith('.md') and anchor[1:] not in anchors(path):
            print(f'{doc}: no heading for {target}{anchor}')
            bad += 1
sys.exit(1 if bad else 0)
