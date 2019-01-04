#! /bin/bash

setxkbmap de neo
synclient TouchpadOff=1
feh --bg-scale --no-fehbg ~/.config/i3/background.png

start_conky_maia
compton -b

/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
pulseaudio

pa-applet
nm-applet
xfce4-power-manager
pamac-tray
clipit
sbxkb

fix_xcursor
unclutter &
xautolock -time 10 -locker blurlock

if [-d ~/.autostart.d/*.sh ]; then
  for start_snipplet in ~/.autostart.d/*.sh ; do
      sh $start_snipplet
  done
fi
