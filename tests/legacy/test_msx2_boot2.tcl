set ::env(SDL_VIDEODRIVER) dummy
after realtime 3 { screenshot -prefix m2_t3 -raw }
after realtime 6 { screenshot -prefix m2_t6 -raw }
after realtime 9 { screenshot -prefix m2_t9 -raw }
after realtime 9.2 { exit }
