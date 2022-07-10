KBUILD_OUTPUT :=  ./koutput
UBUILD_OUTPUT :=  ./uoutput

abs_objtree := $(shell mkdir -p $(KBUILD_OUTPUT) && cd $(KBUILD_OUTPUT) && pwd)
abs_objtree := $(shell mkdir -p $(UBUILD_OUTPUT) && cd $(UBUILD_OUTPUT) && pwd)

K=kernel
U=user
KRN_SRC=kernel

KRN_C_SRC = kernel/bio.c      kernel/file.c    kernel/log.c   kernel/plic.c    kernel/ramdisk.c    kernel/start.c    kernel/sysfile.c  kernel/uart.c \
  kernel/console.c  kernel/fs.c      kernel/main.c  kernel/printf.c  kernel/sleeplock.c  kernel/string.c   kernel/sysproc.c  kernel/virtio_disk.c \
  kernel/exec.c     kernel/kalloc.c  kernel/pipe.c  kernel/proc.c    kernel/spinlock.c   kernel/syscall.c  kernel/trap.c     kernel/vm.c
  
# removed: ramdisk.c  
KRN_C_SRC2 = bio.c      file.c    log.c   plic.c      start.c    sysfile.c  uart.c \
  console.c  fs.c      main.c  printf.c  sleeplock.c  string.c   sysproc.c  virtio_disk.c \
  exec.c     kalloc.c  pipe.c  proc.c    spinlock.c   syscall.c  trap.c     vm.c  

#removed: ramdisk.o 
KRN_C_OBJ = bio.o     file.o   log.o  plic.o     start.o   sysfile.o uart.o \
  console.o fs.o     main.o printf.o sleeplock.o string.o  sysproc.o virtio_disk.o \
  exec.o    kalloc.o pipe.o proc.o   spinlock.o  syscall.o trap.o    vm.o 


KRN_ASM_SRC = kernel/entry.S  kernel/kernelvec.S  kernel/swtch.S  kernel/trampoline.S

KRN_ASM_OBJ = entry.o  kernelvec.o  swtch.o  trampoline.o

KRN_ASM_OBJ2 = $(KBUILD_OUTPUT)/entry.S  $(KBUILD_OUTPUT)/kernelvec.S  $(KBUILD_OUTPUT)/swtch.S  $(KBUILD_OUTPUT)/trampoline.S

OBJS = \
  $(KBUILD_OUTPUT)/entry.o \
  $(KBUILD_OUTPUT)/start.o \
  $(KBUILD_OUTPUT)/console.o \
  $(KBUILD_OUTPUT)/printf.o \
  $(KBUILD_OUTPUT)/uart.o \
  $(KBUILD_OUTPUT)/kalloc.o \
  $(KBUILD_OUTPUT)/spinlock.o \
  $(KBUILD_OUTPUT)/string.o \
  $(KBUILD_OUTPUT)/main.o \
  $(KBUILD_OUTPUT)/vm.o \
  $(KBUILD_OUTPUT)/proc.o \
  $(KBUILD_OUTPUT)/swtch.o \
  $(KBUILD_OUTPUT)/trampoline.o \
  $(KBUILD_OUTPUT)/trap.o \
  $(KBUILD_OUTPUT)/syscall.o \
  $(KBUILD_OUTPUT)/sysproc.o \
  $(KBUILD_OUTPUT)/bio.o \
  $(KBUILD_OUTPUT)/fs.o \
  $(KBUILD_OUTPUT)/log.o \
  $(KBUILD_OUTPUT)/sleeplock.o \
  $(KBUILD_OUTPUT)/file.o \
  $(KBUILD_OUTPUT)/pipe.o \
  $(KBUILD_OUTPUT)/exec.o \
  $(KBUILD_OUTPUT)/sysfile.o \
  $(KBUILD_OUTPUT)/kernelvec.o \
  $(KBUILD_OUTPUT)/plic.o \
  $(KBUILD_OUTPUT)/virtio_disk.o

# riscv64-unknown-elf- or riscv64-linux-gnu-
# perhaps in /opt/riscv/bin
#TOOLPREFIX = 
TOOLPREFIX=riscv64-unknown-elf-
# Try to infer the correct TOOLPREFIX if not set
ifndef TOOLPREFIX
TOOLPREFIX := $(shell if riscv64-unknown-elf-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-unknown-elf-'; \
	elif riscv64-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-linux-gnu-'; \
	elif riscv64-unknown-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-unknown-linux-gnu-'; \
	else echo "***" 1>&2; \
	echo "*** Error: Couldn't find a riscv64 version of GCC/binutils." 1>&2; \
	echo "*** To turn off this error, run 'gmake TOOLPREFIX= ...'." 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif

QEMU = qemu-system-riscv64

CC = $(TOOLPREFIX)gcc
AS = $(TOOLPREFIX)gas
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump

CFLAGS = -Wall -Werror -O -fno-omit-frame-pointer -ggdb
CFLAGS += -MD
CFLAGS += -mcmodel=medany
CFLAGS += -ffreestanding -fno-common -nostdlib -mno-relax
CFLAGS += -I.
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)
KRN_CFLAGS := -o $(KBUILD_OUTPUT)
USR_CFLAGS := -o $(UBUILD_OUTPUT)

# Disable PIE when possible (for Ubuntu 16.10 toolchain)
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]no-pie'),)
CFLAGS += -fno-pie -no-pie
endif
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]nopie'),)
CFLAGS += -fno-pie -nopie
endif

LDFLAGS = -z max-page-size=4096


 

$K/kernel: $(KRN_C_OBJ) $(KRN_ASM_OBJ)  $K/kernel.ld $U/initcode
	$(LD) $(LDFLAGS) -T $K/kernel.ld -o $K/kernel $(OBJS) 
	$(OBJDUMP) -S $K/kernel > $K/kernel.asm
	$(OBJDUMP) -t $K/kernel | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $K/kernel.sym

# http://www.gnu.org/software/make/manual/make.html#Static-Pattern
# https://stackoverflow.com/a/40621556/974287
# https://stackoverflow.com/a/18548815/974287
$(KRN_C_OBJ) : %.o : kernel/%.c
	$(CC) $(CFLAGS) -c $<  -o $(KBUILD_OUTPUT)/$@  
	
$(KRN_ASM_OBJ) : %.o : kernel/%.S
	$(CC) $(CFLAGS) -c $<  -o $(KBUILD_OUTPUT)/$@ 



$U/initcode: $U/initcode.S
	$(CC) $(CFLAGS) -march=rv64g -nostdinc -I. -Ikernel -c $U/initcode.S -o $U/initcode.o
	$(LD) $(LDFLAGS) -N -e start -Ttext 0 -o $U/initcode.out $U/initcode.o
	$(OBJCOPY) -S -O binary $U/initcode.out $U/initcode
	$(OBJDUMP) -S $U/initcode.o > $U/initcode.asm

tags: $(OBJS) _init
	etags *.S *.c

ULIB = $U/ulib.o $U/usys.o $U/printf.o $U/umalloc.o

_%: %.o $(ULIB)
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $^
	$(OBJDUMP) -S $@ > $*.asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $*.sym

$U/usys.S : $U/usys.pl
	perl $U/usys.pl > $U/usys.S

$U/usys.o : $U/usys.S
	$(CC) $(CFLAGS) -c -o $U/usys.o $U/usys.S

$U/_forktest: $U/forktest.o $(ULIB)
	# forktest has less library code linked in - needs to be small
	# in order to be able to max out the proc table.
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $U/_forktest $U/forktest.o $U/ulib.o $U/usys.o
	$(OBJDUMP) -S $U/_forktest > $U/forktest.asm

mkfs/mkfs: mkfs/mkfs.c $K/fs.h $K/param.h
	gcc -Werror -Wall -I. -o mkfs/mkfs mkfs/mkfs.c

# Prevent deletion of intermediate files, e.g. cat.o, after first build, so
# that disk image changes after first build are persistent until clean.  More
# details:
# http://www.gnu.org/software/make/manual/html_node/Chained-Rules.html
.PRECIOUS: %.o

UPROGS=\
	$U/_cat\
	$U/_echo\
	$U/_forktest\
	$U/_grep\
	$U/_init\
	$U/_kill\
	$U/_ln\
	$U/_ls\
	$U/_mkdir\
	$U/_rm\
	$U/_sh\
	$U/_stressfs\
	$U/_usertests\
	$U/_grind\
	$U/_wc\
	$U/_zombie\

fs.img: mkfs/mkfs README $(UPROGS)
	mkfs/mkfs fs.img README $(UPROGS)

-include kernel/*.d user/*.d

# $(shell mkdir -p $(KBUILD_OUTPUT) && cd $(KBUILD_OUTPUT) && pwd)
clean: 
	rm -f *.tex *.dvi *.idx *.aux *.log *.ind *.ilg \
	*/*.o */*.d */*.asm */*.sym \
	$U/initcode $U/initcode.out $K/kernel fs.img \
	mkfs/mkfs .gdbinit \
        $U/usys.S $(KBUILD_OUTPUT)/* \
	$(UPROGS)

# try to generate a unique GDB port
GDBPORT = $(shell expr `id -u` % 5000 + 25000)
# QEMU's gdb stub command line changed in 0.11
QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; \
	then echo "-gdb tcp::$(GDBPORT)"; \
	else echo "-s -p $(GDBPORT)"; fi)
ifndef CPUS
CPUS := 3
endif

QEMUOPTS = -machine virt -bios none -kernel $K/kernel -m 128M -smp $(CPUS) -nographic
QEMUOPTS += -drive file=fs.img,if=none,format=raw,id=x0
QEMUOPTS += -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0

qemu: $K/kernel fs.img
	$(QEMU) $(QEMUOPTS)

.gdbinit: .gdbinit.tmpl-riscv
	sed "s/:1234/:$(GDBPORT)/" < $^ > $@

qemu-gdb: $K/kernel .gdbinit fs.img
	@echo "*** Now run 'gdb' in another window." 1>&2
	$(QEMU) $(QEMUOPTS) -S $(QEMUGDB)

