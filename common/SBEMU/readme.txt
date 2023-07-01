
 Setup SBEMU environment for both real-mode and protected-mode games

 - boot machine with "DEVICE=jemmex.exe" in config.sys
 - run "jload qpiemu.dll"
 - run "hdpmi32i -r -x"
 - run "sbemu"

 Notes

 Ensure that no HDPMI environment variable is set before loading hdpmi32i.
