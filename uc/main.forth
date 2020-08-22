0 variable rx-state
0 variable break
0 variable sensor-error

0 variable pm1.0
0 variable pm2.5
0 variable pm10

\ PA4   USB_PWREN#     input       EXTIx
\ PA6   SENSOR_RESET   output
\ PA7   SENSOR_SET     output
\ PA8   LED (red)      output
\ PA9   BLE_RX         output/AF1  USART1_RX
\ PA10  BLE_TX         input/AF1   USART1_TX
\ PA11  BLE_RTS#       input/AF1   USART1_CTS
\ PA12  BLE_CTS#       output/AF1  USART1_RTS
\ PB0   SENSOR_TXD     input/AF4   USART3_RX
\ PB1   BLE_MODE       output
\ PB2   BLE_RST#       output
\ PC6   LED (yellow)   output

: gpio-init ( -- )
  GPIOA_AFRH @ $FFF0000F and $00011110 or GPIOA_AFRH !
  GPIOB_AFRL @ $FFFFFFF0 and $00000004 or GPIOB_AFRL !
  \ 00 - input, 01 - output, 10 - alternate function, 11 - analog
  GPIOA_MODER @ $FC000FFF and $02A95000 or GPIOA_MODER !
  GPIOB_MODER @ $FFFFFFC0 and $00000016 or GPIOB_MODER !
  GPIOC_MODER @ $FFFFCFFF and $00001000 or GPIOC_MODER !
  $000001C0 GPIOA_BSRR !
  $00040002 GPIOB_BSRR !
  $00000040 GPIOC_BSRR ! ;

: ble-prompt ( -- )
  s" CMD> " usart1-expect ;

: ble-aok-prompt ( -- )
  s" AOK" usart1-expect ble-prompt ;

: ble-on ( -- )
  $00000004 GPIOB_BSRR !
  100 ms wait
  s" %REBOOT%" usart1-expect
  s" $$$" usart1-tx-str
  ble-prompt ;

: ble-off ( -- )
  $00040000 GPIOB_BSRR ! ;

: ble-reboot ( -- )
  ble-off 100 ms wait ble-on ;

: beacon ( -- )
  ble-on
  s" SC,1" usart1-println ble-aok-prompt                      \ connectable advertisement disabled, beacon enabled
  s" STB,0140" usart1-println ble-aok-prompt                  \ beacon interval = 200 ms
  s" STA,8000,0001,8000" usart1-println ble-aok-prompt        \ advertisement interval
  s" IB,Z" usart1-println ble-aok-prompt                      \ beacon clear
  s" IB,09,504D53656E736F7231" usart1-println ble-aok-prompt  \ add beacon name: PMSensor1
  \ IB,FF,xxxxxxxxxx - manufacturer specific data
  pm1.0 @ pm2.5 @ 16 lshift or pm10 @                         \ (pm1.0 | (pm2.5 << 16)) pm10
  base @ >r
  hex
  <# # # # # # # # # # # # # [char] , hold [char] F hold [char] F hold [char] , hold [char] B hold [char] I hold #>
  r> base !
  usart1-println ble-aok-prompt
  10000 ms tick0 !
  begin
    key? if -1 break ! then
  tick0 @ 0= break @ or until
  ble-off ;

: sensor-on ( -- )
  $00000080 GPIOA_BSRR !
  100 ms wait ;

: sensor-off ( -- )
  $00800000 GPIOA_BSRR ! ;

: sensor-reset ( -- )
  $00400000 GPIOA_BSRR !
  20 ms tick0 !
  begin tick0 @ 0= until
  $00000040 GPIOA_BSRR ! ;

: pm. ( u -- )
  0 <# #s #> type ;

: get-pm ( -- )
  2 0 do usart3-rx drop loop
  usart3-rx 8 lshift usart3-rx or pm1.0 !
  usart3-rx 8 lshift usart3-rx or pm2.5 !
  usart3-rx 8 lshift usart3-rx or pm10 !
  22 0 do usart3-rx drop loop
  ." PM1.0=" pm1.0 @ . ." PM2.5=" pm2.5 @ . ." PM10=" pm10 @ . cr ;

: measure1 ( -- )
  0 rx-state !
  1100 ms tick0 !
  begin
    usart3-rx-ready? if
      led-y-on
      rx-state @ case
        0 of usart3-rx $42 = if 1 rx-state ! then endof
        1 of usart3-rx $4D = if 2 rx-state ! else 0 rx-state ! then endof
        2 of get-pm 3 rx-state ! endof
      endcase
    else
      key? if -1 break ! exit then
      tick0 @ 0= if -1 sensor-error ! exit then
    then
  rx-state @ 3 = break @ or until ;

: refresh-watchdog ( -- )
  $AAAA IWDG_KR ! ;

: enable-watchdog ( -- )
  $CCCC IWDG_KR !
  $5555 IWDG_KR !
  7 IWDG_PR !                             \ 32 kHz / 256 = 125 Hz
  [ 60 125 * literal, ] IWDG_RLR !        \ 60 seconds
  begin IWDG_SR @ 0= until ;

: measure ( -- )
  sensor-on
  0 pm1.0 ! 0 pm2.5 ! 0 pm10 !
  cr
  10 0 do
    0 sensor-error !
    measure1
    led-y-off
    break @ sensor-error @ or if leave then
  loop
  sensor-off ;

: main ( -- )
  0 break !
  enable-watchdog
  begin
    calibrate-hsi16
    measure
    sensor-error @ 0= if
      beacon
      100000 ms tick0 !
    else
      sensor-off
      sensor-reset
      5000 ms tick0 !
    then
    begin
      key? if -1 break ! then
      refresh-watchdog
    tick0 @ 0= break @ or until
  break @ until ;

: setup ( -- )
  gpio-init
  rtc-domain-reset
  lse-on
  115200 usart1-init
  9600 usart3-init
  tim14-init
  ble-off
  sensor-off ;
