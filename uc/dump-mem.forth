16 buffer: ascii-dump-buf

: phex2. ( c -- )
  hex 0 <# # # #> type space ;

: phex8. ( u -- )
  hex 0 <# # # # # # # # # #> type space space ;

: replace-non-printable ( -- )
  decimal
  16 0 do
    ascii-dump-buf i + c@ $20 < ascii-dump-buf i + c@ $7E > or if
      [char] . ascii-dump-buf i + c!
    then
  loop ;

: dump ( c-addr len -- )
  base @ >r
  decimal
  ascii-dump-buf 16 [char] . fill
  over dup                          \ c-addr len
  $0F and 16 swap -                 \ c-addr len c-addr c-addr
  ascii-dump-buf 16 + over - swap   \ c-addr len c-addr (16-len&15)
  move                              \ c-addr len c-addr c-addr2 (16-len&15)
  replace-non-printable

  cr
  over $FFFFFFF0 and phex8.

  over $0F and if
    over $0F and 0 do
      [char] . emit [char] . emit space 
      i 7 = if [char] - emit space then
    loop
  then

  0 do
    dup c@ phex2.
    1+
    dup $0F and 0= if
      decimal
      space ascii-dump-buf 8 type space ascii-dump-buf 8 + 8 type
      dup ascii-dump-buf 16 move
      replace-non-printable
      cr dup phex8.
    then
    dup $0F and 8 = if
      [char] - emit space
    then
  loop

  dup $0F and if
    16 over $0F and do
      [char] . emit [char] . emit space
      i 7 = if [char] - emit space then
    loop
    dup $0F and ascii-dump-buf + over $0F and 16 swap - [char] . fill
    space ascii-dump-buf 8 type space ascii-dump-buf 8 + 8 type
  then

  drop
  cr
  r> base ! ;
