set ::env(SDL_VIDEODRIVER) dummy
after realtime 3.0 { type "call thaion\r" }
after realtime 4.0 { type "call printon\r" }
after realtime 4.7 { type "call printoff\r" }
after realtime 5.4 { type "call plockon\r" }
after realtime 6.1 { type "call printon\r" }
after realtime 6.8 { screenshot -prefix clean_final -raw }
after realtime 7.0 { exit }
