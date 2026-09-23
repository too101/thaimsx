# openMSX machine config for the bug-8 regression test

`UserMSX1_expanded.xml` is a custom openMSX machine: primary slot 0 is **expanded**
(subslotted, `<secondary slot="0">` wrapping the system ROM), matching how many real
MSX1/MSX2 machines are actually wired (including the hardware the bug-8 report came
from). The project's default test configs use a *non*-expanded slot 0, which cannot
reproduce bug 8 (SPEC_TH.md 9.11) at all -- see that section for why.

To use it: edit the `<filename>` path inside to point at your own MSX1 system ROM,
copy the file into `~/.openMSX/share/machines/`, then:

```
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
openmsx -machine UserMSX1_expanded -carta build/thairom.rom \
        -script ../test_phase3_expanded_slot_bug8.tcl
cat /tmp/bug8_regression_out.txt   # must say PASS
```
