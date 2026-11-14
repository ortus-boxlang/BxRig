# Shared by the pty tests: wait until a terminal program has drawn its first screen instead of sleeping a fixed time (native start takes 1.4 to 2.2 s
# depending on the machine). ready( fd ) returns once output has arrived and then stayed quiet for `quiet` seconds, or after `limit` seconds.
import os, select, time
def ready(fd, quiet=0.5, limit=20.0):
    start = time.time(); last = None
    while time.time() - start < limit:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                if not os.read(fd, 65536): return
            except OSError: return
            last = time.time()
        elif last is not None and time.time() - last >= quiet:
            return
