set ::env(SDL_VIDEODRIVER) dummy
after realtime 3.0 { screenshot -prefix bare_boot -raw }
after realtime 3.3 { type "thaion\r" }
after realtime 5.0 { screenshot -prefix bare_after -raw }
after realtime 5.2 { exit }
