# Report: dt_bell (0.7.1)

There is no separate brief. The scope was Tim's in chat (25 Nov 14:45): "proceed with 0.7.1", the patch proposed in the 0.8.0 report. It covers one sound and nothing else.

- **Branch:** `claude/dt-bell`, from `main` at bf431f4 (#43 merged). PR #44 (0.8.0) still targets 0.7.0's line; once this merges, #44 needs `main` merged in and its version stays 0.8.0.
- **Sound:** `PlaySoundFile(565853, "SFX")`. FileDataID 565853 is `sound/doodad/belltollhorde.ogg`, from the wowdev community listfile, and it's the file Tim exported. The ID came from the listfile because the folder Tim exported to (`_desk\belltollhorde`) isn't connected to this session.
- **Behaviour:**
  - While that bell's handle is still playing (`C_Sound.IsPlaying`, in the Forever spec), no new bell starts.
  - If `PlaySoundFile` is absent, errors or won't play, the old `PlaySound(READY_CHECK)` plays instead.
  - The setting's description now names the bell.
- **Guard proofs** (each removed once, then put back):

  | Guard | Red check |
  |---|---|
  | one bell at a time | "0.7.1: still tolling: no second bell over the first" |
  | no bell, the old chime | "0.7.1: a client that can't play the bell gets the old chime" |
  | sound only when switched on (existing) | the three T6 "no sound" checks |
  | SFX channel | the T6 bell check |

- **Suites:** `run_all.sh` ALL GREEN. gamble 233, up 5.
- **Not done:** `PlaySoundFile` isn't added to Selftest REQUIRED, because the chime fallback covers its absence. The bell isn't clipped short: H1 asks whether it should be.
