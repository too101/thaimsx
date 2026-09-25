set ::env(SDL_VIDEODRIVER) dummy
after realtime 5.0 { screenshot -prefix msx2boot -raw }
after realtime 5.2 { exit }
