CA=ca65
LD=ld65

all: skernal

skernal: skernal.o
	$(LD) -C symon.config -m skernal.map -vm -o rom.bin skernal.o

skernal.o: console.asm macros.asm math.asm util.asm skernal.asm
	$(CA) --listing skernal.map -o skernal.o skernal.asm

clean:
	rm -f *.o *.rom *.map *.lst *.bin
