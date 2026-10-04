"""
=============================================================================
  FILE        : magfarm/dev/smoke_test.py
  PACKAGE     : MagFarm Lua  (MacroQuest / EverQuest)
  VERSION     : 0.1.0
  CHANGES     : 0.1.0  Initial structural smoke test.

  WHAT  : Performs offline structural checks for the MagFarm package.
  WHY   : Catches missing modules/docs before a game-client test.
  WHERE : Run on a PC from magfarm/dev or package root.
  HOW   : Confirms expected files and key documented package markers exist.
  WHEN  : Run after edits and before packaging.
=============================================================================
"""
import os
import sys

PACKAGE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REQUIRED = ['init.lua','runtime.lua','utils.lua','config.lua','state.lua','spells.lua','assist.lua','pet.lua','merc.lua','follow.lua','spell_acquisition.lua','ui.lua','README.md','ARCHITECTURE.md','ATTRIBUTION.md','CHANGELOG.md','LICENSE']

def main():
    """WHAT: Check package inventory. WHY: A missing module breaks requires. WHERE: Script entry. HOW: Verify expected paths. WHEN: Direct execution."""
    missing = [name for name in REQUIRED if not os.path.exists(os.path.join(PACKAGE, name))]
    if missing:
        print('FAIL missing:', ', '.join(missing))
        return 1
    init = open(os.path.join(PACKAGE, 'init.lua'), encoding='utf-8').read()
    architecture = open(os.path.join(PACKAGE, 'ARCHITECTURE.md'), encoding='utf-8').read()
    if "mq.bind('/magfarm'" not in init or 'Spell Acquisition' not in architecture:
        print('FAIL expected startup/architecture markers not found')
        return 1
    print('PASS MagFarm package structure is present.')
    return 0

if __name__ == '__main__':
    sys.exit(main())

# =============================================================================
# END OF FILE : magfarm/dev/smoke_test.py
# =============================================================================
