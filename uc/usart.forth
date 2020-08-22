128 constant BUF-SIZE

BUF-SIZE buffer: usart1-rx-buffer
0 variable usart1-rx-wr-idx
0 variable usart1-rx-rd-idx

BUF-SIZE buffer: usart1-tx-buffer
0 variable usart1-tx-wr-idx
0 variable usart1-tx-rd-idx

BUF-SIZE buffer: usart3-rx-buffer
0 variable usart3-rx-wr-idx
0 variable usart3-rx-rd-idx

16 constant EXPECT-BUF-SIZE
EXPECT-BUF-SIZE buffer: expect-buffer

: @++ ( addr -- u )
  dup @ dup 1+ BUF-SIZE 1- and rot ! ;

: usart1-tx-ready? ( -- f )
  usart1-tx-wr-idx @ usart1-tx-rd-idx @ <> ;

: usart1-tx-fifo-not-full? ( -- f )
  USART1_ISR @ USART_ISR_TXFNF and 0<> ;

: usart1-handler ( -- )
  begin
    USART1_ISR @ USART_ISR_RXFNE and while
    USART1_RDR c@
    usart1-rx-wr-idx @++ usart1-rx-buffer + c!
  repeat
  begin
    usart1-tx-ready? usart1-tx-fifo-not-full? and while
    usart1-tx-rd-idx @++ usart1-tx-buffer + c@ USART1_TDR c!
  repeat
  usart1-tx-ready? 0= if USART_CR1_TXFNFIE USART1_CR1 bic! then ;

: usart3-handler ( -- )
  begin
    USART3_ISR @ USART_ISR_RXFNE and while
    USART3_RDR c@
    usart3-rx-wr-idx @++ usart3-rx-buffer + c!
  repeat ;

: usart1-rx-ready? ( -- f )
  usart1-rx-wr-idx @ usart1-rx-rd-idx @ <> ;

: usart3-rx-ready? ( -- f )
  usart3-rx-wr-idx @ usart3-rx-rd-idx @ <> ;

: usart1-rx ( -- c )
  begin usart1-rx-ready? until
  usart1-rx-rd-idx @++ usart1-rx-buffer + c@ ;

: usart3-rx ( -- c )
  begin usart3-rx-ready? until
  usart3-rx-rd-idx @++ usart3-rx-buffer + c@ ;

: usart1-tx ( c -- )
  usart1-tx-wr-idx @ usart1-tx-buffer + c!
  usart1-tx-wr-idx @++ drop
  USART_CR1_TXFNFIE USART1_CR1 bis! ;

: usart1-tx-str ( c-addr u -- )
  0 do dup c@ usart1-tx 1+ loop drop ;

: usart1-init ( baud -- )
  RCC_APBENR2_USART1EN RCC_APBENR2 bis!       \ note: wait 2 cycles after enabling the clock
  USART_CR1_UE USART1_CR1 bic!
  PCLK swap / USART1_BRR !
  [ USART_CR1_UE USART_CR1_RE or USART_CR1_TE or USART_CR1_FIFOEN or USART_CR1_RXFNEIE or literal, ] USART1_CR1 !
  ['] usart1-handler irq-usart1 !
  $08000000 NVIC_ISER ! ;

: usart3-init ( baud -- )
  RCC_APBENR1_USART3EN RCC_APBENR1 bis!       \ note: wait 2 cycles after enabling the clock
  USART_CR1_UE USART3_CR1 bic!
  PCLK swap / USART3_BRR !
  [ USART_CR1_UE USART_CR1_RE or USART_CR1_TE or USART_CR1_FIFOEN or USART_CR1_RXFNEIE or literal, ] USART3_CR1 !
  ['] usart3-handler irq-usart3_usart4_lpuart1 !
  $20000000 NVIC_ISER ! ;

: usart1-expect ( c-addr u -- )
  expect-buffer EXPECT-BUF-SIZE $FF fill
  begin
    expect-buffer 1+ expect-buffer EXPECT-BUF-SIZE 1- move
    usart1-rx
    over 1- expect-buffer + c!
    2dup expect-buffer over compare
  until
  2drop ;

: usart1-println ( c-addr u -- )
  usart1-tx-str $0D usart1-tx ;
