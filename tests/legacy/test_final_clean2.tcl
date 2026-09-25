set ::env(SDL_VIDEODRIVER) dummy
after realtime 3.0 { type "call thaion\r" }
after realtime 4.5 { type "call printon\r" }
after realtime 6.0 { type "call printoff\r" }
after realtime 7.5 { type "call plockon\r" }
after realtime 9.0 { type "call printon\r" }
after realtime 10.5 { screenshot -prefix clean2_final -raw }
after realtime 10.7 { exit }
