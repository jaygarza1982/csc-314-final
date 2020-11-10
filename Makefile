NAME=game

all: game

clean:
	rm -rf game game.o

game: game.asm
	nasm -f elf game.asm
	gcc -g -m32 -o game game.o
