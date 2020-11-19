;%include "/usr/local/share/csc314/asm_io.inc"
; %include "/usr/include/unistd.h"

; the file that stores the initial state
%define BOARD_FILE 'board.txt'

; how to represent everything
%define WALL_CHAR '#'
%define PLAYER_CHAR 'O'

; the size of the game screen in characters
%define HEIGHT 20
%define WIDTH 40

;Size of snake array
%define SNAKE_SIZE 50

; the player starting position.
; top left is considered (0,0)
%define STARTX 5
%define STARTY 5

; these keys do things
%define EXITCHAR 'x'
%define UPCHAR 'w'
%define LEFTCHAR 'a'
%define DOWNCHAR 's'
%define RIGHTCHAR 'd'
%define BREAKCHAR 'b'

%define SLEEP_SPEED 200000


segment .data

	; used to fopen() the board file defined above
	board_file			db BOARD_FILE,0

	; used to change the terminal mode
	mode_r				db "r",0
	raw_mode_on_cmd		db "stty raw -echo",0
	raw_mode_off_cmd	db "stty -raw echo",0

	; called by system() to clear/refresh the screen
	clear_screen_cmd	db "clear",0

	; things the program will print
	help_str			db 13,10,"Controls: ", \
							UPCHAR,"=UP / ", \
							LEFTCHAR,"=LEFT / ", \
							DOWNCHAR,"=DOWN / ", \
							RIGHTCHAR,"=RIGHT / ", \
							EXITCHAR,"=EXIT", \
							13,10,10,0

segment .bss

	; this array stores the current rendered gameboard (HxW)
	board	resb	(HEIGHT * WIDTH)

	; these variables store the current player position
	xpos	resd	1
	ypos	resd	1

	;Each of these will have a 1 or a 0 depending on where the snake is
	;If the snake has 1 in the nth position, the snake has a cell at the nth position

	;memory watch 0x56558394
	snake_x resd SNAKE_SIZE

	;memory watch 0x56558524
	snake_y resd SNAKE_SIZE

	;Velocities
	x_speed resd 1
	y_speed resd 1

segment .text

	global	main
	global  raw_mode_on
	global  raw_mode_off
	global  init_board
	global  render
	; global sleep

	extern	system
	extern	putchar
	extern	getchar
	extern	printf
	extern	fopen
	extern	fread
	extern	fgetc
	extern	fclose
	extern usleep
	extern fcntl

main:
	enter	0,0
	pusha
	;***************CODE STARTS HERE***************************


	; Set snake_x and snake_y starting position
	mov DWORD [snake_x + 4 * 0], 5
	mov DWORD [snake_y + 4 * 0], 5

	mov DWORD [snake_x + 4 * 1], 6
	mov DWORD [snake_y + 4 * 1], 5

	mov DWORD [snake_x + 4 * 2], 7
	mov DWORD [snake_y + 4 * 2], 5

	; put the terminal in raw mode so the game works nicely
	call	raw_mode_on

	; read the game board file into the global variable
	call	init_board

	; set the player at the proper start position
	mov		DWORD [xpos], STARTX
	mov		DWORD [ypos], STARTY

	; the game happens in this loop
	; the steps are...
	;   1. render (draw) the current board
	;   2. get a character from the user
	;	3. store current xpos,ypos in esi,edi
	;	4. update xpos,ypos based on character from user
	;	5. check what's in the buffer (board) at new xpos,ypos
	;	6. if it's a wall, reset xpos,ypos to saved esi,edi
	;	7. otherwise, just continue! (xpos,ypos are ok)
	game_loop:

		; draw the game board
		call	render

		; get an action from the user
		call	nonblocking_getchar ;getchar

		cmp al, -1
		jne char_typed


		;Move and draw player
		calc_player:
				mov		eax, WIDTH
				mul		DWORD [ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]
				cmp		BYTE [eax], WALL_CHAR
				jne		valid_move
					; opps, that was an invalid move, reset
					mov		DWORD [xpos], esi
					mov		DWORD [ypos], edi
				valid_move:

				;Move the player here
				mov esi, DWORD [y_speed]
				mov edi, DWORD [x_speed]

				cmp DWORD [x_speed], 1
				je x_1_player_move
				cmp DWORD [x_speed], -1
				je x_neg_1_player_move
				cmp DWORD [y_speed], 1
				je y_1_player_move
				cmp DWORD [y_speed], -1
				je y_neg_1_player_move

				;It was none of the checked values
				jmp player_move_check_end

				player_move_check_start:
					;We are moving right
					x_1_player_move:
						;Get snake length - 1
						mov eax, 2 ;Snake length get logic would go here
						; inc DWORD [snake_x + 4 * eax] ;Move it
						mov ebx, DWORD [snake_x + 4 * eax] ;Save value before we call our remove function
						;Remove the 0th x value in the snake array
						call remove_last_x
						;Increment far right position
						inc ebx
						mov DWORD [snake_x + 4 * eax], ebx
						jmp player_move_check_end
					x_neg_1_player_move:
						jmp player_move_check_end
					y_1_player_move:
						jmp player_move_check_end
					y_neg_1_player_move:
						jmp player_move_check_end
				player_move_check_end:
				mov DWORD [x_speed], 0
				mov DWORD [y_speed], 0

		;Sleep for sleep speed in order to not render as quickly
		push SLEEP_SPEED
		call usleep
		add esp, 4

		jmp		game_loop

		; store the current position
		; we will test if the new position is legal
		; if not, we will restore these
		; mov		esi, [xpos]
		; mov		edi, [ypos]

		char_typed:
			; choose what to do
			cmp		al, EXITCHAR
			je		game_loop_end
			cmp		al, UPCHAR
			je 		move_up
			cmp		al, LEFTCHAR
			je		move_left
			cmp		al, DOWNCHAR
			je		move_down
			cmp		al, RIGHTCHAR
			je		move_right
			cmp al, BREAKCHAR
			je break_move
			jmp		input_end			; or just do nothing

			; move the player according to the input character
			move_up:
				; dec		DWORD [ypos]
				mov DWORD [y_speed], -1
				mov DWORD [x_speed], 0
				jmp		input_end
			move_left:
				; dec		DWORD [xpos]
				mov DWORD [x_speed], -1
				mov DWORD [y_speed], 0
				jmp		input_end
			move_down:
				; inc		DWORD [ypos]
				mov DWORD [y_speed], 1
				mov DWORD [x_speed], 0
				jmp		input_end
			move_right:
				; inc		DWORD [xpos]
				mov DWORD [x_speed], 1
				mov DWORD [y_speed], 0
				jmp input_end
			break_move:
				jmp input_end
			input_end:


	jmp game_loop
	game_loop_end:

	; restore old terminal functionality
	call raw_mode_off

	;***************CODE ENDS HERE*****************************
	popa
	mov		eax, 0
	leave
	ret

; === FUNCTION ===
raw_mode_on:

	push	ebp
	mov		ebp, esp

	push	raw_mode_on_cmd
	call	system
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
raw_mode_off:

	push	ebp
	mov		ebp, esp

	push	raw_mode_off_cmd
	call	system
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
init_board:

	push	ebp
	mov		ebp, esp

	; FILE* and loop counter
	; ebp-4, ebp-8
	sub		esp, 8

	; open the file
	push	mode_r
	push	board_file
	call	fopen
	add		esp, 8
	mov		DWORD [ebp-4], eax

	; read the file data into the global buffer
	; line-by-line so we can ignore the newline characters
	mov		DWORD [ebp-8], 0
	read_loop:
	cmp		DWORD [ebp-8], HEIGHT
	je		read_loop_end

		; find the offset (WIDTH * counter)
		mov		eax, WIDTH
		mul		DWORD [ebp-8]
		lea		ebx, [board + eax]

		; read the bytes into the buffer
		push	DWORD [ebp-4]
		push	WIDTH
		push	1
		push	ebx
		call	fread
		add		esp, 16

		; slurp up the newline
		push	DWORD [ebp-4]
		call	fgetc
		add		esp, 4

	inc		DWORD [ebp-8]
	jmp		read_loop
	read_loop_end:

	; close the open file handle
	push	DWORD [ebp-4]
	call	fclose
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
render:

	push	ebp
	mov		ebp, esp

	; two ints, for two loop counters
	; ebp-4, ebp-8
	sub		esp, 8

	; clear the screen
	push	clear_screen_cmd
	call	system
	add		esp, 4

	; print the help information
	push	help_str
	call	printf
	add		esp, 4

	; outside loop by height
	; i.e. for(c=0; c<height; c++)
	mov		DWORD [ebp-4], 0
	y_loop_start:
	cmp		DWORD [ebp-4], HEIGHT
	je		y_loop_end

		; inside loop by width
		; i.e. for(c=0; c<width; c++)
		mov		DWORD [ebp-8], 0
		x_loop_start:
		cmp		DWORD [ebp-8], WIDTH
		je 		x_loop_end
			
			mov ecx, 0
			mov DWORD [xpos], 0
			mov DWORD [ypos], 0

			;SNAKE_SIZE - 1
			mov ebx, SNAKE_SIZE
			dec ebx
			length_loop_start:
				cmp ecx, ebx
				je length_loop_end

				mov eax, DWORD [snake_x + 4 * ecx]
				cmp eax, 0
				je x_not_1

				x_1:
					call x_is_1
				x_not_1:

				mov eax, DWORD [snake_y + 4 * ecx]
				cmp eax, 0
				je y_not_1
				
				y_1:
					call y_is_1
				y_not_1:


				; check if (xpos,ypos)=(x,y)
				mov		eax, [xpos]
				cmp		eax, DWORD [ebp-8]
				jne		print_board
				mov		eax, [ypos]
				cmp		eax, DWORD [ebp-4]
				jne		print_board
					; if both were equal, print the player
					push	PLAYER_CHAR
					jmp		print_end
				print_board:
					; otherwise print whatever's in the buffer
					mov		eax, [ebp-4]
					mov		ebx, WIDTH
					mul		ebx
					add		eax, [ebp-8]
					mov		ebx, 0
					mov		bl, BYTE [board + eax]
					push	ebx
				
				inc ecx
				jmp length_loop_start
			length_loop_end:
			print_end:
			call	putchar
			add		esp, 4

		inc		DWORD [ebp-8]
		jmp		x_loop_start
		x_loop_end:

		; write a carriage return (necessary when in raw mode)
		push	0x0d
		call 	putchar
		add		esp, 4

		; write a newline
		push	0x0a
		call	putchar
		add		esp, 4

	inc		DWORD [ebp-4]
	jmp		y_loop_start
	y_loop_end:

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
nonblocking_getchar:

; returns -1 on no-data
; returns char on succes

; magic values
%define F_GETFL 3
%define F_SETFL 4
%define O_NONBLOCK 2048
%define STDIN 0

	push	ebp
	mov		ebp, esp

	; single int used to hold flags
	; single character (aligned to 4 bytes) return
	sub		esp, 8

	; get current stdin flags
	; flags = fcntl(stdin, F_GETFL, 0)
	push	0
	push	F_GETFL
	push	STDIN
	call	fcntl
	add		esp, 12
	mov		DWORD [ebp-4], eax

	; set non-blocking mode on stdin
	; fcntl(stdin, F_SETFL, flags | O_NONBLOCK)
	or		DWORD [ebp-4], O_NONBLOCK
	push	DWORD [ebp-4]
	push	F_SETFL
	push	STDIN
	call	fcntl
	add		esp, 12

	call	getchar
	mov		DWORD [ebp-8], eax

	; restore blocking mode
	; fcntl(stdin, F_SETFL, flags ^ O_NONBLOCK
	xor		DWORD [ebp-4], O_NONBLOCK
	push	DWORD [ebp-4]
	push	F_SETFL
	push	STDIN
	call	fcntl
	add		esp, 12

	mov		eax, DWORD [ebp-8]

	mov		esp, ebp
	pop		ebp
	ret


; === FUNCTION ===

x_is_1:
	push ebp
	mov ebp, esp

	mov eax, DWORD [snake_x + 4 * ecx]
	mov DWORD [xpos], eax

	mov esp, ebp
	pop ebp
	ret

y_is_1:
	push ebp
	mov ebp, esp

	mov eax, DWORD [snake_y + 4 * ecx]
	mov DWORD [ypos], eax

	mov		esp, ebp
	pop		ebp
	ret

;Removes the last x value in the snake array 
remove_last_x:
	push ebp
	mov ebp, esp

	mov ecx, 0
	remove_last_x_loop_start:
		cmp ecx, SNAKE_SIZE - 1
		je remove_last_x_loop_end

		;snake_x[ecx] = snake_x[ecx + 1]
		
		mov edx, ecx
		inc edx
		mov edi, DWORD [snake_x + 4 * edx]
		mov DWORD [snake_x + 4 * ecx], edi

		inc ecx
		jmp remove_last_x_loop_start
	remove_last_x_loop_end:

	mov esp, ebp
	pop ebp
	ret