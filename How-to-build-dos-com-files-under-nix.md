# Toolchain

Courtesy JohnDoe31415 at
https://github.com/johndoe31415/dosdebug/tree/master/dostest

- `gcc` is capable of assembling source in either 
   `AT&T` or `Intel` syntax.
- `binutils/ld` is able to produce `MS-DOS` `.COM` files.
- `make` to bring it all together.

# as

`open_file.s`:
```as
.code16gcc

mov $'X', %dl
mov $0x02, %ah
int $0x21

mov $0x4c00, %ax
int $0x21
```

`example.s`:
```as
.code16gcc

# Open file in 32 bit mode
mov $filename, %dx
mov $0x3d00, %ax
int $0x21
push %ax

# Open it again
mov $filename, %dx
mov $0x3d00, %ax
int $0x21
push %ax

# Push this a second time so we can attempt a double close
push %ax

# Now close both files
pop %bx
mov $0x3e, %ah
int $0x21

pop %bx
mov $0x3e, %ah
int $0x21

# This close should now fail (file already closed/invalid handle)
pop %bx
mov $0x3e, %ah
int $0x21

# Exit
mov $0x4c00, %ax
int $0x21

filename:
	.string "EXAMPLE.COM"
```

# ld
`dos_com.ld`:
```ld
OUTPUT_FORMAT(binary)
SECTIONS {
    . = 0x0100;
    .text : {
        *(.text);
    }
    .data : {
        *(.data);
        *(.bss);
        *(.rodata);
    }
    _heap = ALIGN(4);
}
```

# make

`Makefile`:
```make
PHONY: all clean install
.SUFFIXES: .s .com

SOURCES := $(wildcard *.s)
OBJS := $(SOURCES:.s=.com)
CFLAGS := 
LDFLAGS := -nostdlib -T dos_com.ld

all: $(OBJS)

clean:
	rm -f $(OBJS)

install: all
	cp $(OBJS) ~/.dosboxdrv
	../dosbox-0.74-3-dbg

.s.com:
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)
	objdump -b binary -m i386 -M i8086 --adjust-vma=0x100 -D $@
```
