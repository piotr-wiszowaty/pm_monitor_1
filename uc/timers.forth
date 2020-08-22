0 variable tick0

: tim14-handler
  TIM_SR_UIF TIM14_SR hbic!
  tick0 @ if tick0 @ 1- tick0 ! then ;

: tim14-init
  RCC_APBENR2_TIM14EN RCC_APBENR2 bis!
  TIM_DIER_UIE TIM14_DIER h!
  [ 3200 1 - literal, ] TIM14_PSC !
  [ 100 1 - literal, ] TIM14_ARR !
  ['] tim14-handler irq-tim14 !
  NVIC_IPR4 @ $0FFFFFFF and $40000000 or NVIC_IPR4 !
  $00080000 NVIC_ISER !
  TIM_CR1_CEN TIM14_CR1 h! ;

: ms ( u -- u )
  10 / ;

: wait ( -- )
  tick0 !
  begin tick0 @ while repeat ;

: rtc-handler
  RTC_SCR_CWUTF RTC_SCR !     \ NOTE: do not exit interrupt handler for at least 2 APB clock cycles
  begin RTC_SR @ RTC_SR_WUTF and while repeat ;

: rtc-domain-reset ( -- )
  RCC_BDCR_BDRST RCC_BDCR bis!
  RCC_BDCR_BDRST RCC_BDCR bic! ;

: lse-on ( -- )
  RCC_APBENR1_PWREN RCC_APBENR1 bis!                             \ enable power control clock
  PWR_CR1_DBP PWR_CR1 bis!                                       \ disable RTC domain write protection
  [ 1 RCC_BDCR_LSEDRV_POS lshift RCC_BDCR_LSEON + literal, ] RCC_BDCR bis!  \ turn on LSE
  begin RCC_BDCR @ RCC_BDCR_LSERDY and until ;                   \ wait for LSE to become ready

: rtc-unprotect ( -- )
  $CA RTC_WPR !
  $53 RTC_WPR ! ;

0 variable tmr16-high
0 variable time0
0 variable time1
0 variable cap-cnt

: tim16-handler
  TIM16_SR @ TIM_SR_UIF and if
    TIM_SR_UIF TIM16_SR hbic!
    tmr16-high @ 1+ tmr16-high !
  then
  TIM16_SR @ TIM_SR_CC1IF and if
    TIM_SR_CC1IF TIM16_SR hbic!
    time1 @ time0 !
    tmr16-high @ time1 2+ h!
    TIM16_CCR1 h@ time1 h!
    cap-cnt @ 1+ cap-cnt !
  then ;

: show-hsi16 ( -- )
  cr ." time0 = " time0 @ .
  cr ." time1 = " time1 @ .
  cr ." diff  = " time1 @ time0 @ - .
  cr ." HSITRIM = " char $ emit RCC_ICSCR @ hex. cr ;

\ NOTE: due to a hardware bug TIM16 is always clocked from SYSCLK
: calibrate-hsi16 ( -- )
  0 cap-cnt !
  0 tmr16-high !
  ['] tim16-handler irq-tim16 !
  NVIC_IPR5 @ $FFFF00FF and $00004000 or NVIC_IPR5 !
  $00200000 NVIC_ISER !
  RCC_APBENR2_TIM16EN RCC_APBENR2 bis!
  0 TIM16_CNT !
  $03 TIM16_TISEL !
  $01 TIM16_CCMR1 h!
  TIM_CCER_CC1E TIM16_CCER h!
  [ TIM_DIER_CC1IE TIM_DIER_UIE + literal, ] TIM16_DIER !
  TIM_CR1_CEN TIM16_CR1 h!

  ['] rtc-handler irq-rtc_tamp !
  NVIC_IPR0 @ $FF00FFFF and $00400000 or NVIC_IPR0 !
  $00000004 NVIC_ISER !
  RCC_APBENR1_RTCAPBEN RCC_APBENR1 bis!
  [ RCC_BDCR_RTCEN 1 RCC_BDCR_RTCSEL_POS lshift + literal, ] RCC_BDCR bis!
  rtc-unprotect
  0 RTC_CR !
  begin RTC_ICSR @ RTC_ICSR_WUTWF and until
  511 RTC_WUTR !   \ RTC/16=2048 Hz => 250 ms interval
  [ RTC_CR_WUTE RTC_CR_WUTIE + literal, ] RTC_CR !

  begin cap-cnt @ 1 > until

  RCC_BDCR_RTCEN RCC_BDCR bic!
  RCC_APBENR1_RTCAPBEN RCC_APBENR1 bic!
  RCC_APBENR2_TIM16EN RCC_APBENR2 bic!

  \ show-hsi16
  RCC_ICSCR @ RCC_ICSCR_HSITRIM and RCC_ICSCR_HSITRIM_POS rshift
  time1 @ time0 @ -
  PCLK > if
    dup 0 > if 1- then
  else
    dup 127 < if 1+ then
  then
  RCC_ICSCR_HSITRIM_POS lshift RCC_ICSCR_HSITRIM RCC_ICSCR bics! ;
