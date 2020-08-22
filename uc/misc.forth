16000000 constant PCLK

: led-y-on ( -- )
  $00400000 GPIOC_BSRR ! ;

: led-y-off ( -- )
  $00000040 GPIOC_BSRR ! ;

: led-r-on ( -- )
  $01000000 GPIOA_BSRR ! ;

: led-r-off ( -- )
  $00000100 GPIOA_BSRR ! ;

: bics! ( u msk addr -- )
  dup @ rot not and rot or swap ! ;
