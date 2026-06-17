#!/usr/bin/env python3

import sys
import subprocess
import difflib
import os

def escape_html(text):
    return (text.replace('&', '&amp;')
                .replace('<', '&lt;')
                .replace('>', '&gt;')
                .replace('"', '&quot;')
                .replace("'", '&#39;'))

def highlight_char_diff(old_line, new_line):
    old_content = old_line[1:] if old_line.startswith(('-', '+')) else old_line
    new_content = new_line[1:] if new_line.startswith(('-', '+')) else new_line
    matcher = difflib.SequenceMatcher(None, old_content, new_content)
    old_highlighted, new_highlighted = [], []
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == 'equal':
            old_highlighted.append(escape_html(old_content[i1:i2]))
            new_highlighted.append(escape_html(new_content[j1:j2]))
        elif tag == 'delete':
            old_highlighted.append(f'<span class="word-del">{escape_html(old_content[i1:i2])}</span>')
        elif tag == 'insert':
            new_highlighted.append(f'<span class="word-add">{escape_html(new_content[j1:j2])}</span>')
        elif tag == 'replace':
            old_highlighted.append(f'<span class="word-del">{escape_html(old_content[i1:i2])}</span>')
            new_highlighted.append(f'<span class="word-add">{escape_html(new_content[j1:j2])}</span>')
    return f"-{''.join(old_highlighted)}", f"+{''.join(new_highlighted)}"

def should_highlight_lines(old_line, new_line):
    if not old_line.startswith('-') or not new_line.startswith('+'):
        return False
    old_content = old_line[1:].strip()
    new_content = new_line[1:].strip()
    if not old_content or not new_content:
        return False
    return difflib.SequenceMatcher(None, old_content, new_content).ratio() > 0.3

def main():
    salida = os.path.expanduser("~/diff.htm")
    git_args = sys.argv[1:]

    try:
        subprocess.run(['git', 'add', '-N', '.'], check=True)
        result = subprocess.run(['git', 'diff', *git_args], capture_output=True, text=True, check=True)
        diff_content = result.stdout
        subprocess.run(['git', 'reset', '.'], capture_output=True, text=True)
    except subprocess.CalledProcessError:
        return

    html_lines = ['''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Git Diff Light</title>
<style>
body { 
    font-family: 'DejaVu Sans Mono', monospace; 
    background: #ffffff; 
    color: #333; 
    padding: 20px; 
    line-height: 1.2; 
}
pre { margin: 0; white-space: pre-wrap; }

/* Contenedores de línea para el fondo */
.line { display: inline-block; width: 100%; }

/* Colores de texto oscuros para modo light */
.add { color: #155724; background-color: #e6ffed; } /* Verde oscuro sobre fondo menta muy pálido */
.del { color: #721c24; background-color: #ffeef0; } /* Rojo vino sobre fondo rosa muy pálido */
.header { color: #005cc5; font-weight: bold; }    /* Azul fuerte */
.chunk { color: #6f42c1; background-color: #f6f8fa; font-style: italic; } /* Púrpura */

/* Resaltado interno (caracteres) */
.word-add { background-color: #acf2bd; font-weight: bold; color: #0a3622; }
.word-del { background-color: #fdb8c0; text-decoration: line-through; color: #4b1113; }
</style>
</head><body><pre>''']

    lines = diff_content.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        escaped_line = escape_html(line)
        
        if (line.startswith('diff --git') or line.startswith('index ') or 
            line.startswith('Binary file') or
            (i > 0 and line.startswith('--- ') and not lines[i-1].startswith('---')) or
            (i > 0 and line.startswith('+++ ') and not lines[i-1].startswith('+++'))):
            html_lines.append(f'<span class="line header">{escaped_line}</span>')
        elif line.startswith('@@ '):
            html_lines.append(f'<span class="line chunk">{escaped_line}</span>')
        elif (line.startswith('-') and not line.startswith('---') and
              i + 1 < len(lines) and lines[i+1].startswith('+') and not lines[i+1].startswith('+++')):
            if should_highlight_lines(line, lines[i+1]):
                old_h, new_h = highlight_char_diff(line, lines[i+1])
                html_lines.append(f'<span class="line del">{old_h}</span>')
                html_lines.append(f'<span class="line add">{new_h}</span>')
            else:
                html_lines.append(f'<span class="line del">{escaped_line}</span>')
                html_lines.append(f'<span class="line add">{escape_html(lines[i+1])}</span>')
            i += 1
        elif line.startswith('+') and not line.startswith('+++'):
            html_lines.append(f'<span class="line add">{escaped_line}</span>')
        elif line.startswith('-') and not line.startswith('---'):
            html_lines.append(f'<span class="line del">{escaped_line}</span>')
        else:
            html_lines.append(f'<span class="line">{escaped_line}</span>')
        i += 1

    html_lines.append('</pre></body></html>')

    with open(salida, 'w', encoding='utf-8') as f:
        f.write('\n'.join(html_lines))

    subprocess.run(f'chromium --new-window {salida}', shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

if __name__ == "__main__":
    main()