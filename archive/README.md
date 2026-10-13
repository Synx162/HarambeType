# Development archive

These are source-only snapshots of the project as it was built across three course milestones. They are kept for history. **The design that was built and demoed is in [`../src`](../src).**

Quartus databases, build outputs, waveform files and duplicate `.mif` images were left out. The folder names are the ones used during development.

| Folder | What's in it |
|---|---|
| `milestone1/` | First working path from a PS/2 keyboard to a letter on screen. `PS2_demo/` is the course-provided PS/2 reference. `scancode_to_fontIndex/` has notes and the first ModelSim testbench. |
| `milestone2/` | Target-word stream, `done_list`/`comparator` scoring, on-screen timer (9-bit color, one framebuffer). `MODELSIM MS2/kb/` has the PS/2 receiver testbench. |
| `milestone3/` | Integration iterations toward the final build (`New Uploads/` = versions swapped between teammates). `Reference MS2 working/` is the last known-good Milestone 2 build. |
| `unused/` | Glyph drawers for live on-screen stats (`in_game_stats_draw`, `counter_to_pixel_draw`). They are not instantiated in the final top level; the HEX displays show those values instead. |
