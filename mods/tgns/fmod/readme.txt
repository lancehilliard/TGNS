) Install FMOD Designer 4.44.63 (fmoddesigner44463win-installer.exe)

) Open tgns.fdp in FMOD Designer

) Create Event Group per TGNS plugin

) Create Simple Event per plugin sound (http://audio.online-convert.com/convert-to-wav -- WAV; 22or44kHz; 16-bit; Mono)

) Set 'Playback Mode' to 'Oneshot'

) In the right column, set 'Mode' to '3d'

) Rename soundbank(s) to remove "_bank##" suffixes

) Save project

) Build project

) Move all output files (tgns.fev, tgns.fsb) to "output/sound/" directory of mod filesystem

) Create/Edit .soundinfo file(s) (to get sound length: open .fev file and view Length under Properties)

Source: http://forums.unknownworlds.com/discussion/comment/2135769#Comment_2135769