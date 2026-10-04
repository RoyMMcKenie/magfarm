"""
=============================================================================
  FILE        : magfarm/dev/doc_audit.py
  PACKAGE     : MagFarm Lua  (MacroQuest / EverQuest)
  VERSION     : 0.1.0
  CHANGES     : 0.1.0  Initial documentation audit utility.

  WHAT  : Audits MagFarm Lua files for core documentation markers.
  WHY   : Documentation is a project requirement; automated checks make that
          requirement repeatable after future edits.
  WHERE : Run on a PC from the magfarm/dev directory or package root.
  HOW   : Checks headers, footers, version/changelog alignment, and documented
          named Lua functions.
  WHEN  : Run after every code change before packaging or deployment.
=============================================================================
"""
import glob
import os
import re
import sys

PACKAGE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HEADER_TAGS = ['FILE', 'PACKAGE', 'VERSION', 'CHANGES', 'WHAT', 'WHY', 'WHERE', 'HOW', 'WHEN']
FUNCTION_TAGS = ['WHAT', 'WHY', 'WHERE', 'HOW', 'WHEN']

def changelog_version():
    """WHAT: Read current release version. WHY: File versions must agree. WHERE: main. HOW: First changelog heading. WHEN: Audit start."""
    text = open(os.path.join(PACKAGE, 'CHANGELOG.md'), encoding='utf-8').read()
    match = re.search(r'^## (\d+\.\d+\.\d+)', text, re.M)
    return match.group(1) if match else None

def audit(path, version):
    """WHAT: Check one Lua file. WHY: Report problems by file. WHERE: main. HOW: Inspect header/footer/function context. WHEN: Once per Lua file."""
    text = open(path, encoding='utf-8').read()
    lines = text.splitlines()
    header, footer = '\n'.join(lines[:70]), '\n'.join(lines[-90:])
    problems = []
    for tag in HEADER_TAGS:
        if tag not in header: problems.append(f'missing header tag {tag}')
    if 'END OF FILE' not in footer: problems.append('missing END OF FILE footer')
    match = re.search(r'VERSION\s*:\s*(\d+\.\d+\.\d+)', header)
    if not match or match.group(1) != version: problems.append(f'version mismatch: {match.group(1) if match else "missing"} vs {version}')
    for index, line in enumerate(lines):
        found = re.match(r'\s*function\s+([\w\.:]+)', line)
        if found:
            above = '\n'.join(lines[max(0, index - 45):index])
            if not all(tag in above for tag in FUNCTION_TAGS): problems.append(f'line {index + 1}: undocumented function {found.group(1)}')
    return problems

def main():
    """WHAT: Run all audits. WHY: Command entry point. WHERE: module bottom. HOW: Print PASS/FAIL per Lua file. WHEN: Direct script execution."""
    version = changelog_version()
    failed = False
    print('Changelog version:', version)
    for path in sorted(glob.glob(os.path.join(PACKAGE, '*.lua'))):
        problems = audit(path, version)
        if problems:
            failed = True
            print('FAIL', os.path.basename(path))
            for problem in problems: print('  ', problem)
        else:
            print('PASS', os.path.basename(path))
    return 1 if failed else 0

if __name__ == '__main__':
    sys.exit(main())

# =============================================================================
# END OF FILE : magfarm/dev/doc_audit.py
# =============================================================================
