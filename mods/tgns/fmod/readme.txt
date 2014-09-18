FMOD 4.38.00 installer:

http://www.fmod.org/download/fmodex/tool/win/fmoddesigner43800win-installer.exe

) Open tgns_notifications.fdp in FMOD Designer

) Create Event Group per TGNS plugin

) Create Simple Event per plugin sound

) Set 'Playback Mode' to 'Oneshot'

) In the right column, set 'Mode' to '3d'

) Rename soundbank(s) to remove "_bank##" suffixes

) Save project

) Build project

) Create/Edit .soundinfo file(s) (to get sound length: open .fev file and view Length under Properties)

) Move all output files to "sound/" directory of mod filesystem

Source: http://forums.unknownworlds.com/discussion/comment/2135769#Comment_2135769