	.syntax	unified
	.cpu	cortex-m0
	.thumb
	.text

	.equ	USART1_ISR, 0x40013800+0x1C
	.equ	USART1_RDR, 0x40013800+0x24
	.equ	USART1_TDR, 0x40013800+0x28
	.equ	USART2_ISR, 0x40004400+0x1C
	.equ	USART2_RDR, 0x40004400+0x24
	.equ	USART2_TDR, 0x40004400+0x28
	.equ	RXFNE, 0x00000020

uart_pass_through:
	nop				@ placeholder for "push {lr}"

	movs	r1, #RXFNE
	ldr	r2, =USART1_ISR
	ldr	r3, =USART1_RDR
	ldr	r4, =USART1_TDR
	ldr	r5, =USART2_ISR
	ldr	r6, =USART2_RDR
	ldr	r7, =USART2_TDR
loop:	ldr	r0, [r2]
	tst	r0, r1
	beq	1f
	ldrb	r0, [r3]
	strb	r0, [r7]
1:	ldr	r0, [r5]
	tst	r0, r1
	beq	loop
	ldrb	r0, [r6]
	strb	r0, [r4]
	b	loop

	.end
