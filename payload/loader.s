# The unchanged Linux loader (the original linux-2048mb.bin), run after boot.c.
.section .loader, "awx", @progbits
.incbin "loader.bin"
