/* Copyright (C) 2026 Chokri Hammedi (blue0x1) <https://github.com/blue0x1> */
OUTPUT_FORMAT("elf64-x86-64", "elf64-x86-64", "elf64-x86-64")
OUTPUT_ARCH(i386:x86-64)

ENTRY(_start)

PHDRS
{
	code_seg PT_LOAD;
	rdata_seg PT_LOAD;
	data_seg PT_LOAD;
	bss_seg PT_LOAD;
	loader_seg PT_LOAD;
}

SECTIONS
{
	.text : {
		*(.text.start)
		*(.text*)
	} : code_seg
	.rodata : {
		*(.rodata)
		*(.rodata*)
	} : rdata_seg
	.data : { *(.data) } : data_seg
	.bss  : { *(.bss) *(COMMON) } : bss_seg
	.loader ALIGN(0x4000) : { linux_loader = .; KEEP(*(.loader)) } : loader_seg
	/DISCARD/ : {
		*(.comment)
		*(.note.GNU-stack)
		*(.eh_frame)
		*(.interp)
	}
}
