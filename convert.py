import re
import os
import glob

files = glob.glob("*.sh")

def process(content):
    content = re.sub(r'^#!/bin/bash', '#!/bin/dash', content)
    # Simple [[ ]] to [ ]
    content = re.sub(r'\[\[ (.*?) \]\]', r'[ \1 ]', content)
    
    # For double quotes without $, \, ` or '
    # We will use a regex that matches double quotes and contents
    def replacer(m):
        inner = m.group(1)
        if re.search(r'[\$\`\\\']', inner) or not inner:
            return f'"{inner}"'
        return f"'{inner}'"
        
    content = re.sub(r'"([^"\\]*?)"', replacer, content)
    return content

for f in files:
    with open(f, 'r') as fp:
        c = fp.read()
    nc = process(c)
    if c != nc:
        with open(f, 'w') as fp:
            fp.write(nc)
