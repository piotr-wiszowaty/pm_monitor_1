all: uart_pass_through.forth

uart_pass_through.forth: uart_pass_through.o
	elf2fth -s -w uart-pass-through $^ > $@

uart_pass_through.o: uart_pass_through.S
	arm-none-eabi-as -o uart_pass_through.o $^

clean:
	rm -f uart_pass_through.o uart_pass_through.forth
