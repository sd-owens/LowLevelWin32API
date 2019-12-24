TITLE LowLevelInputOutput     (LowLevelInputOutput_Win32API_MASM.asm)

; Author: Steve Owens
; Last Modified: 12/03/2019
; Description:  This program implements two custom procedures, ReadVal and WriteVal to handle low level input and 
;               output to the console.  ReadVal takes in user input from the keyboard as a string of ascii characters,
;				validates the input to be only unsigned integer values less than the maximum 32bit size of 
;				4,294,967,295 and stores the value in memory as an integer. WriteVal reads in an integer value and 
;				converts it to its ascii equivalent and outputs that format to the console.  Custom macros getString
;				and writeString were written using the Win32 API to handle simply repetition of code for input and 
;				output from the console.  Furthermore, to fully demonstrate the operation of the custom procesures 
;				above, the program take in 10 integer values from the user, provides a running total of the values, 
;			    displays the data entered, outputs their sum, and finally calculates and displays the average value of
;				the numbers.
;
; Implementation notes:
;				This program is implemented using procedures.
;				All parameters are passed on the system stack

INCLUDE Irvine32.inc

; (constant definitions)
ENDL				EQU			<0dh, 0ah>					; end of line sequence
BUFFER_SIZE			EQU			<80>						; max buffer_size of 80 characters, allows input > 32bit limit
ARRAY_SIZE			EQU			<10>						; array size for 10 32bit integers

.data
; (variable definitions - strings, string_sizes)
progTitle		BYTE		"Demonstrating low-level I/O procedures", ENDL
title_size		DWORD		($ - progTitle)

progName		BYTE		"Programmed by Steve Owens", ENDL, ENDL
name_size		DWORD		($ - progName)

ec1				BYTE		"**EC #1: Number each line of user input and display a running subtotal of the user's numbers.**", ENDL
ec1_size		DWORD		($ - ec1)

ec3 			BYTE		"**EC #3: Implement the getString and displayString macros using Win32 API functions.**", ENDL, ENDL
ec3_size		DWORD		($ - ec3)

info1			BYTE		"Please provide 10 positive decimal integers.", 13, 10,
							"Each number needs to be small enough to fit inside a 32 bit register.", 13, 10,
							"After you have finished inputting the raw numbers I will display a list", 13, 10,
							"of the integers, their sum, and their average value.", ENDL, ENDL
info1_size		DWORD		($ - info1)

prompt1			BYTE		"Please enter an integer number: ", 0
prompt1_size	DWORD		($ - prompt1)

result1			BYTE		"You entered the following numbers: ", 0
result1_size	DWORD		($ - result1)

result2			BYTE		"The sum of these numbers is: ", 0
result2_size	DWORD		($ - result2)

result3			BYTE		"The average is: ", 0
result3_size	DWORD		($ - result3)

subtot			BYTE		"Subtotal: ", 0
subtot_size		DWORD		($ - subtot)

error			BYTE		"ERROR: You did not enter a positive integer number or your number was too big.", 13, 10,
						    "Please try again: ", 0
error_size		DWORD		($ - error)

outro1			BYTE		"Thank you for using my program!", ENDL
outro1_size		DWORD		($ - outro1)

value			DWORD		0											; initialized to 0 
sum				QWORD		0											; sum of array initialized to zero

num_array		DWORD		ARRAY_SIZE DUP(?)


; (variables for Win32 API function calls)
buffer			BYTE		BUFFER_SIZE DUP(?), 0, 0
stdInHandle		HANDLE		?
bytesRead		DWORD		?
consoleHandle	HANDLE		0
bytesWritten	DWORD		?

	
.code
;-----------------------------------------------------------------------------------------------------------------
;getString Macro
;description: Macro to use Win32 API to read a character string from user keyboard input.  Returns characters read
;			  in the buffer and bytesRead variables
;receives: address of buffer and address of variable bytesRead by reference
;returns: input string in buffer and an integer value for bytesRead stored in bytesRead
;preconditions:  none
;registers changed: eax, edx
;-----------------------------------------------------------------------------------------------------------------
getString MACRO buffer, bytesRead

			push	eax													; save contents of registers manipulated in macro
			push	edx

			INVOKE	GetstdHandle, STD_INPUT_HANDLE
			mov		stdInHandle, eax
			
			INVOKE	ReadConsole,
				    stdInHandle, 
					buffer,
					BUFFER_SIZE,
					bytesRead,
					0

			pop		edx													; returns registers to pre-macro call state
			pop		eax

ENDM
;-----------------------------------------------------------------------------------------------------------------
;displayString Macro
;description: Macro to use Win32 API to write an integer value to the console by take a string of ascii characters
;			  by reference and writing them to the console.
;receives: address of string of buffer by reference and the length of the string by value.
;returns: none
;preconditions:  none
;registers changed: eax
;-----------------------------------------------------------------------------------------------------------------
displayString MACRO string, string_size							; string is passed as an OFFSET thus no ADDR in INVOKE

			push	eax	
			
			INVOKE	GetStdHandle, STD_OUTPUT_HANDLE
			mov		consoleHandle, eax

			INVOKE  WriteConsole,
				    consoleHandle,
				    string,
				    string_size,
				    ADDR bytesWritten,
				    0

			pop		eax

ENDM
;-----------------------------------------------------------------------------------------------------------------
;introduction 
;description: display program name and introduces programmer.  displays EC header.
;receives: none
;returns: validated user input in eax register
;preconditions:  none
;registers changed: none, all restored to pre-call state
;-----------------------------------------------------------------------------------------------------------------
introduction PROC

			pushad
			
			displayString	OFFSET progTitle, title_size
			displayString	OFFSET progName, name_size
			displayString	OFFSET ec1, ec1_size
			displayString	OFFSET ec3, ec3_size
			displayString	OFFSET info1, info1_size

			popad
			ret

introduction ENDP

;-----------------------------------------------------------------------------------------------------------------
;getData
;description: Procedure to handle logic for providing prompts to the user and obtaining users input as a string for
;		      each of the 10 array values.  Provides features for displaying line numbers and a running subtotal
;			  of the sum of the integers of the array.
;receives: num_array by reference, array_size by value, value by reference, buffer by reference, prompt1 by
;		   reference, and prompt1_size by value
;returns:  subtotal in address provided for sum [ebp + 32]
;preconditions:  none
;registers changed: eax, ecx, edx, esi, edi
;-----------------------------------------------------------------------------------------------------------------
getData PROC

			; stack passed params							; ebp + 8  prompt1_size by value
															; ebp + 12 prompt1 string by reference
															; ebp + 16 buffer by reference (address)
															; ebp + 20 value by reference (address)
															; ebp + 24 array_size by value
															; ebp + 28 num_array by reference (address)
															; ebp + 32 sum by reference (for returning value)
															; ebp + 36 bytesRead by reference
			push	ebp										
			mov		ebp, esp
			sub		esp, 4									; ebp - 4 local variable for array subtotal

			push	eax										; save state of registers from caller
			push	ecx
			push	edx
			push	edi
			push	esi

			mov		eax, [ebp + 32]

			mov		esi, [ebp + 20]							; move address of value into esi
			mov		edx, [esi]								; add value pointed to by esi into edx, 0 
			mov		edi, 0									; initialize edi to 0
			
			mov		ecx, [ebp + 24]							; set ecx to 10 for array size and # integers to get
			mov		esi, [ebp + 28]							; set esi to first element in the array
L3:
			inc		edx
			push	edx										; push value in edx onto stack for LineNumber PROC										
			call	LineNumber
									
			push	edi
			call	SubTotal

			push	[ebp + 36]
			push	[ebp + 20]
			push	[ebp + 16]
			push	[ebp + 12]
			push	[ebp + 8]
			call	ReadVal
		
			mov		ebx, [ebp + 20]							; move the number stored in value into address pointed by esi
			mov		eax, [ebx]
			add		edi, eax								; add value to running subtotal for array
			mov		[ebp - 4], edi		
			mov		[esi], eax
			add		esi, 4									; increment esi by one DWORD (4).
			loop	L3

			xor		eax, eax								; zero out eax for next operation
			mov		eax, [ebp + 32]							; move address of sum into eax
			mov		[eax], edi								; store subtotal into sum variable (where eax points)
			
			pop		esi										; restore altered registers to pre-called state
			pop		ecx
			pop		edx
			pop		ecx
			pop		eax

			mov		esp, ebp								; clean up local variables
			pop		ebp										; clean up the stack										
			ret		32

getData ENDP

;-----------------------------------------------------------------------------------------------------------------
;LineNumber
;description: Procedure to  handle line number feature the corresponds to the element of the array to which the
;			  user is providing a string input.  Take a integers input and coverts the value to an ascii code by
;		      adding 48 to the value, then uses the Irvine Library WriteChar method to print ascii chars
;			  to the console for formatted ouptput.  
;receives: integer by value
;returns:  none
;preconditions:  none
;registers changed: eax
;-----------------------------------------------------------------------------------------------------------------
LineNumber PROC
			
			; stack passed params							; [ebp + 8] integer by value
			push	ebp
			mov		ebp, esp
			push	eax										; preserve state of eax register

			xor		eax, eax								; zero out eax
			mov		al, 40									; ascii for left parenths
			call	WriteChar
			mov		al, [ebp + 8]							; value push from edx for line numbers
			add		al, 48									; add 48 to convert digit to ascii character
			cmp		al, 58
			jae		TEN
			call	WriteChar
FINISHED2:
			mov		al, 41									; ascii for right parenths
			call	WriteChar
			mov		al, 32									; ascii for space character
			call	WriteChar

			pop		eax										; restore eax to pre called state
			pop		ebp
			ret		4										; clean up the stack

TEN:														;handles printing 1 and 0 for "10" condition
			mov		al, 49
			call	WriteChar
			mov		al, 48
			call	WriteChar
			jmp		FINISHED2

LineNumber ENDP
;-----------------------------------------------------------------------------------------------------------------
;SubTotal
;description: Procedure to print the running subtotal for the user supplied values with each line in the console. 
;receives: integer by value
;returns:  none
;preconditions:  none
;registers changed: eax
;-----------------------------------------------------------------------------------------------------------------
SubTotal PROC
			
			; stack passed params							; ebp + 8 integer by value

			push	ebp
			mov		ebp, esp
			push	eax										; preserve state of eax by caller

			xor		eax, eax
			mov		al, 40									; ascii value for left parenths
			call	WriteChar
			mov		eax, [ebp + 8]
			call	WriteDec

			xor		eax, eax
			mov		al, 41									; ascii value for right parenths
			call	WriteChar
			mov		al, 32									; ascii value for space
			call	WriteChar

			pop		eax										; retore eax to pre-called state
			pop		ebp
			ret		4										; clean up the stack

SubTotal ENDP

;-----------------------------------------------------------------------------------------------------------------
;ReadVal
;description: Display a prompt to the user and then get the users "integer" input as a string, validates the number
;			  character by character in reverse and then converts the string to an integer value storing it in the
;			  array memory location passed by reference on the stack.
;receives: prompt1_size by value, prompt1 string  by reference, buffer by reference, and value by reference.
;returns:  validated user input as an integer in the variable "value" [ebp + 8]
;preconditions:  none
;registers changed: eax, ebx, ecx, edx, esi, edi
;-----------------------------------------------------------------------------------------------------------------
ReadVal PROC
			; stack passed params							; ebp + 8 prompt1_size by value
															; ebp + 12 prompt1 string by reference
															; ebp + 16 buffer by reference
															; ebp + 20 value by reference
															; ebp + 24 bytesRead by reference
			push	ebp
			mov		ebp, esp
			sub		esp, 4									; [ebp -4] local for boolean valid (0 or 1)

			push	edx										; preserve state of registers from caller
			push	esi
			push	edi
			push	ecx	
			push	eax
			push	ebx

			displayString [ebp + 12], [ebp + 8]				; display prompt to user for what action to take
START:
			mov		edx, [ebp - 4]							; initialize [ebp - 4] to zero
			mov		edx, 0
			mov		[ebp - 4], edx							

			mov		edx, [ebp + 20]							; verify value is zero or reset to 0 following error call.	
			mov		eax , 0								
			mov		[edx], eax			

			getString [ebp + 16], [ebp + 24]				; get number input from users as a string

			mov		edx, [ebp + 24]							; remove end of line characters from bytesRead 0a and 0d
			mov		eax, [edx]
			sub		eax, 2
			
			cmp		eax, 10									; check if string input is greater than 10 digits after removing ENDL chars.
			ja		E1										; uses bytesRead for comparision

			mov		[edx], eax								; store result back into address referenced [ebp + 24]

			mov		esi, [ebp + 16]							; set esi to start of buffer 
			mov		edi, [ebp + 24]
			add		esi, [edi]								; add bytesRead to esi to shift write point
			dec		esi										; subtract 1 from esi, since esi is pointer to just past the end of string.
			
			mov		eax, [ebp + 24]							; counter is initialized to bytesRead
			mov		ecx, [eax]
			std												; set direction flag to reverse
			mov		ebx, 1									; initialize multiplier
CONVERT:
			xor		eax, eax								; reset all EAX registers to zero, EAX, AX, AH, AL
			lodsb
			movzx	eax, al
			lea  	edi, [ebp - 4]							; lookup address of local at runtime for passing on stack
			push	edi									    ; pass local variable by reference to hold boolean result
			push	eax										; push character onto stack for validation
			call	Validate

			mov		edx, [ebp - 4]							; move value of local variable (boolean) into edx for comparision
			cmp		edx, 0
			jz		E1

			sub		al, 48
			mul		ebx
			mov		edx, [ebp + 20]
			jc		E1										; jump if carry adding value into edx result is > 4,294,967,295
			add		eax, [edx]
			jc		E1										; jump if carry adding value into eax result is > 4,294,967,295
			mov		[edx], eax								; store result back into addressed passed on stack [ebp +20]

			mov		eax ,ebx								; increments ebx   ...1, 10, 100, 1000, 10000 etc.
			mov		ebx, 10
			mul		ebx
			mov		ebx, eax
			loop	CONVERT
		
			pop		ebx
			pop		eax
			pop		ecx										; restore altered registers to pre-called state
			pop		edi
			pop		esi
			pop		edx

			mov		esp, ebp								; clean up local variables
			pop		ebp
			ret		20										; clean up the stack

E1:
			displayString	OFFSET error, error_size
			jmp		START

ReadVal ENDP
;-----------------------------------------------------------------------------------------------------------------
;Validate
;description: Validates user input as an ascii character for the integer value.  Uses the ascii character value
;			  range of 48 - 57 (0 - 9) as valid entries.
;receives: ascii value of character by value
;returns:  "boolean" true or false.  Returns a 1 for true and a 0 for false
;preconditions:  none
;registers changed: eax, ecx, edx
;-----------------------------------------------------------------------------------------------------------------
Validate PROC

			; stack passed params							; [ebp + 8] ascii value of character by value
															; [ebp + 12] variable to return result of boolean
			push	ebp
			mov		ebp, esp
			push	eax										; save contents of registers from caller
			push	ecx
			push	edx
			
			xor		edx, edx								; sets edx to 0, will return result in edx 1 for true (valid), 0 for false
			cmp		al, 57
			ja		E2										; jump if ascii value is greater than 57 (number 9)
			cmp		al, 48
			jb		E2										; jump if ascii value is less than 48 (number 0)
			mov		edx, 1			
			jmp		FIN1
E2:
			mov		edx, 0
FIN1:		

			mov		ecx,  [ebp + 12]
			mov		[ecx],	edx							; return boolean to calling function
			pop		edx
			pop		ecx
			pop		eax										; restor registers to pre-called state
			pop		ebp
			ret		8										; clean up the stack					

Validate ENDP
;-----------------------------------------------------------------------------------------------------------------
;WriteVal
;description: Converts an integer value into its ascii character representation, stores that value in the string
;			  buffer variable passed in by refrence and then calls the displayString procedure to print the value
;			  to the console
;receives: string buffer by reference, current array element by reference
;returns:  string representation of integer value in buffer
;preconditions:  none
;registers changed: eax, ebx, ecx, esi, edi
;-----------------------------------------------------------------------------------------------------------------

WriteVal PROC

			; stack passed params							; [ebp + 8] string buffer by reference
															; [ebp + 12] current array element (number) by reference
			push	ebp
			mov		ebp, esp
			sub		esp, 4									; [ebp - 4] local current quotient
			sub		esp, 4									; [ebp - 8] local for char count
			push	eax
			push	ebx										; save state of registers from the caller
			push	ecx
			push	esi
			push	edi

			mov		ecx, 0									; initialize ecx to 0
			mov		esi, [ebp + 8]							; move address of 'value' into esi passed on stack

			mov		edi, [ebp + 12]							; move address of 'buffer' into edi 

			mov		eax, [esi]								; move value data into eax for conversion to a string
			mov		ebx, 10
			cld												; set direction to forward for counting characters

            ; WHILE loop                                    ; count the length of integer to be converted.
COUNT:
			xor		edx, edx								; zero out edx for remainder for unsigned division	
			div		ebx
			inc		ecx										; increase char count by 1
			cmp		eax, 0									; check is quotient was zero, if so end while loop
			je		ENDCOUNT
			jmp		COUNT
ENDCOUNT:
			mov		[ebp - 8], ecx							; store total new string length into local [ebp - 8]
			add		edi, ecx								; add the character count to edi to point to the end of value in memory
			dec		edi										; decrement edi by one to account for zero index
			std												; set direction to be reverse for writing of values to memory
			mov		eax, [esi]								; move value data into eax for next for loop
			
			; FOR loop										; uses number of characters as loop counter stored in ecx
L1:
			xor		edx, edx								; zero out edx for remainder for unsigned division	
			div		ebx

			mov		[ebp - 4], eax							; move quotient into local variable
			mov		eax, edx								; remove remainder into eax for addition
			add		eax, 48									; add 48d (30h) to value in eax to convert to ascii
			stosb											; moves contents of eax (al) into address pointed to by edi
			mov		eax, [ebp - 4]							; move quotient back into eax for next iteration of loop
			loop	L1
		
			cld												; restore direction flag
			displayString	[ebp + 12], [ebp - 8]
			
			pop		edi										; restore state of registers to pre-called state
			pop		esi
			pop		ecx
			pop		ebx
			pop		eax

			mov		esp, ebp								; clean up locals
			pop		ebp
			ret		8										; clean up the stack

WriteVal ENDP
;-----------------------------------------------------------------------------------------------------------------
;printArray
;description:  Procedure iterates through the passed in address for the numbers array called WriteVal during each
;			   iteration.  The WriteVal procedure converts the stored integers value to their ascii representation
;			   and print them to the console.  Provides text formatting and alignment features for the console.
;receives: ARRAY_SIZE by value, num-array by reference, string buffer by reference, result1_size by value, and the
;		   resul1 string by reference.
;returns:  none
;preconditions:  none
;registers changed: eax, ecx, esi
;-----------------------------------------------------------------------------------------------------------------
printArray PROC
								
			; stack passed params							; [ebp + 8] ARRAY_SIZE by value
															; [ebp + 12] num_array by reference
															; [ebp + 16] string buffer by reference
															; [ebp + 20] prompt1_size by value
															; [ebp + 24] OFFSET prompt1 by reference
			push	ebp
			mov		ebp, esp			
			push	eax										; save the state of registers from the caller
			push	ecx
			push	esi

			call	CrLf									
			displayString	[ebp + 24], [ebp + 20]          
			call	CrLf			
			mov		esi, [ebp + 12]							; move address of num_array into esi
			mov		ecx, [ebp + 8]							; initialize loop counter to ARRAY_SIZE
		
L4:									
			push	[ebp + 16]								; push address of string buffer on stack
			push	esi										; push address of array element on stack
			call	WriteVal
									
			add		esi, 4
			xor		eax, eax
			mov		al, 32									; add a space between integers
			call	WriteChar
			loop	L4
			call	CrLf

			pop		esi										; restore registers to pre-called state
			pop		ecx
			pop		eax

			pop		ebp
			ret		20										; clean up the stack

printArray ENDP
;-----------------------------------------------------------------------------------------------------------------
;printResults
;description:  Procedure handles the math for the calculation of the array total sum and average value.  Provides
;			   data title prompts to the user for values displayed.
;receives: result2_size by value, result2 string by reference, variable sum by reference (WriteVal requires by ref)
;		   result3_size by value, result3 string by reference, and string buffere by reference
;returns:  none
;preconditions:  integer sum is passed by reference to allowing passing by reference to WriteVal
;registers changed: eax, ebx, edx, esi
;-----------------------------------------------------------------------------------------------------------------
printResults PROC

			; stack passed params							; [ebp + 8] result2_size by value
															; [ebp + 12] result2 string by reference
															; [ebp + 16] sum by by reference for WriteVal
															; [ebp + 20] result3_size by value
															; [ebp + 24] result3 string by reference
															; [ebp + 28] string buffer by reference
			push	ebp	
			mov		ebp, esp
			sub		esp, 4									; [ebp -4] create local variable for calculated avg to pass to WriteVal

			push	eax										; save the state of registers from the caller
			push	ebx
			push	edx
			push	esi

			call	CrLf
			displayString [ebp + 12], [ebp + 8]

			push	[ebp + 28]								; push buffer by reference onto stack
			push	[ebp + 16]								; push sum by value onto stack									
			call	WriteVal
			call	CrLf

			mov		esi, [ebp + 16]
			mov		eax, [esi]								; mov value referenced by esi into eax for calculation

			xor		edx, edx
			mov		ebx, ARRAY_SIZE							; divide by 10 for 10 elements in array
			div		ebx

			displayString [ebp + 24], [ebp + 20]

			mov		[ebp - 4], eax							; store average in local variable [ebp - 4]
			lea		eax, [ebp - 4]							; lookup runtime address of local variable
			push	[ebp + 28]								; push buffer by reference onto stack
			push	eax										; push address of local variable onto stack
			call	WriteVal
			call	CrLf

			pop		esi
			pop		edx										; restore registers to pre-called state
			pop		ebx
			pop		eax

			mov		esp, ebp								; clean up local variables
			pop		ebp
			ret		24										; clean up the stack

printResults ENDP



;----------------------------------------------------------------------------------------------------------------
;goodbye
;description: end program, exit message to user
;receives: 
;returns: none
;preconditions: none
;registers changed: none
;----------------------------------------------------------------------------------------------------------------
goodbye PROC
			
			; stack passed params							; [ebp + 8] outro1_size by value
															; [ebp + 12]	outro1 string by reference

			push	ebp
			mov		ebp, esp
			
			displayString [ebp + 12], [ebp + 8]
			
			pop		ebp
			ret 8

goodbye ENDP
;----------------------------------------------------------------------------------------------------------------
;main function
;description: calls program procedures in order required order for proper execution of program.
;receives: none
;returns: none
;preconditions: none
;registers changed: none
;----------------------------------------------------------------------------------------------------------------
main PROC	
		
			call	introduction

			push	OFFSET bytesRead
			push	OFFSET sum
			push	OFFSET num_array
			push	ARRAY_SIZE
			push	OFFSET value
			push	OFFSET buffer
			push	OFFSET prompt1
			push	prompt1_size
			call	getData

			push	OFFSET result1
			push	result1_size
			push	OFFSET buffer
			push	OFFSET num_array
			push	ARRAY_SIZE
			call	printArray

			push	OFFSET buffer
			push	OFFSET result3
			push	result3_size
			push	OFFSET sum
			push	OFFSET result2
			push	result2_size
			call	printResults

			push	OFFSET outro1
			push	outro1_size
			call	goodbye

			exit	; exit to operating system

main ENDP
END main