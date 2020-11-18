NAME=game

all: game

clean:
	rm -rf game game.o

game: game.asm
	nasm -f elf game.asm
	gcc -m32 -o game game.o
