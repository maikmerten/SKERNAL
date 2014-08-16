CA=ca65
LD=ld65

all: hex

hex: skernal
	srec_cat rom.bin -binary -o rom.hex -intel

skernal: skernal.o
	$(LD) -C multicomp.config -m skernal.map -vm -o rom.bin skernal.o

skernal.o: console.asm macros.asm io.asm math.asm util.asm skernal.asm fat.asm
	$(CA) --listing skernal.map -o skernal.o skernal.asm

clean:
	rm -f *.o *.rom *.map *.lst *.bin *.hex
