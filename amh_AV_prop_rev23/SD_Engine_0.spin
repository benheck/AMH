{
NEW OPTIMIZED EXPERIMENTAL VERSION
PINHECK SYSTEM - Parallax Propeller Audio / DMD System Driver
2009-2014 Benjamin J Heckendorn
www.benheck.com
}

VAR

  long hiddenSectors, fileSystemType, dataBlockAddress
  long FATSectorSize, rootDirectorySectorNumber, rootCluster
  word reservedSectorCount
  byte CIDRegisterCopy[16]


PUB sdStart(DOPin, CLKPin, DIPin, CSPin, WPPin, CDPin, whichCog, addressLocation)

  sdStop

  dataBlockAddress := addressLocation                                           'Get address of the dataBlock0 RAM we passed to this function

  readTimeout := (clkfreq / 10)
  writeTimeout := (clkfreq / 2)
  clockCounterSetup := (constant(%00100 << 26) + (CLKPin & $1F))
  dataInCounterSetup := (constant(%00100 << 26) + (DIPin & $1F))
     
  dataOutPin := (|<DOPin)
  clockPin := (|<CLKPin)
  dataInPin := (|<DIPin)
  chipSelectPin := (|<CSPin)
  writeProtectPin := ((|<WPPin) & (WPPin <> -1))
  cardDetectPin := ((|<CDPin) & (CDPin <> -1))
     
  blockPntrAddress := @cardBlockAddress
  sectorPntrAddress := @cardSectorAddress
  WPFlagAddress := @cardWriteProtectedFlag
  CDFlagAddress := @cardNotDetectedFlag
  commandFlagAddress := @cardCommandFlag
  errorFlagAddress := @cardErrorFlag
  CSDRegisterAddress := @CSDRegister
  CIDRegisterAddress := @CIDRegister
    
  cardCogID := whichCog
  coginit(cardCogID, @initialization, @CIDPointer)


PUB mountPartition | cardType '' 37 Stack Longs

  readWriteBlock(@cardType, "M")                                                'Mount the card 
  bytemove(@CIDRegisterCopy, @CIDRegister, 16)
  readWriteBlock(0, "R")                                                        'Load first sector into buffer
  
  if(((blockGet(54, 4) & $FF_FF_FF) <> $54_41_46) and ((blockGet(82, 4) & $FF_FF_FF) <> $54_41_46))
  
    if(blockGet(510, 2) <> $AA_55)
      return -1

    hiddenSectors := blockGet(454, 4)
    readWriteBlock(0, "R")

  reservedSectorCount := blockGet(14, 2)

  FATSectorSize := blockGet(22, 2)                                              'Find the size of the FAT, in sectors
    
  ifnot(FATSectorSize)                                                          'If the size wasn't there...
  
    FATSectorSize := blockGet(36, 4)                                            'Look for it here

  rootDirectorySectorNumber := (reservedSectorCount + (2 * FATSectorSize))      'Calculate root directory sector (2 is the default number of FATs)

  return 1


PUB GetRootDirectory

  return rootDirectorySectorNumber


PUB readSector(currentSector, targetAddress, numberOfSectors)

  if cardErrorFlag

    'waitcnt(200_000_000 + cnt)
    
    mountPartition                                      'Re-mount the card

    'waitcnt(50_000_000 + cnt)
    
    cardErrorFlag := 0                                  'Clear the flag

  repeat numberOfSectors
   
    CIDPointer := @CIDRegisterCopy
    cardSectorAddress := (currentSector + hiddenSectors)
    cardBlockAddress := targetAddress
    cardCommandFlag := "R"
   
    repeat while(cardCommandFlag)

      if cardErrorFlag
       
        return currentSector
   
    currentSector += 1
    targetAddress += 512
    
  return currentSector


PRI readWriteBlock(address, command)

  CIDPointer := @CIDRegisterCopy
  cardSectorAddress := (address + hiddenSectors)
  cardBlockAddress := dataBlockAddress
  cardCommandFlag := command

  repeat while(cardCommandFlag)


PRI blockGet(index, numBytes)

  bytemove(@result, dataBlockAddress + (index & $1_FF), numBytes)


PUB sdStop '' 3 Stack Longs

  if(cardCogID)
    cogstop(-1 + cardCogID~)

  if(cardLockID)
    lockret(-1 + cardLockID~)

  bytefill(@CSDRegister, 0, 16)
  bytefill(@CIDRegister, 0, 16)


DAT

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       SDC Driver
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

                        org     0

' //////////////////////Initialization/////////////////////////////////////////////////////////////////////////////////////////

initialization          mov     ctra,                  clockCounterSetup            ' Setup counter modules.
                        mov     ctrb,                  dataInCounterSetup           '

                        mov     cardMounted,           #0                           ' Skip to instruction handle.
                        jmp     #instructionWait                                    '

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Command Center
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

instructionFlush        call    #flushSPI                                           ' Clean up the SPI bus.
                        call    #shutdownSPI                                        '

instructionHalt         cmp     cardCommand,           #"B" wz                      ' Halt the chip if booting failure.
if_z                    mov     buffer,                #$02                         '
if_z                    clkset  buffer                                              '

instructionError        neg     buffer,                #1                           ' Assert error flag and unmount card.
                        wrbyte  buffer,                errorFlagAddress             '
                        mov     cardMounted,           #0                           '

                        mov     counter,               #16                          ' Setup to clear registers.
                        mov     SPIExtraBuffer,        CIDRegisterAddress           '
                        mov     SPIExtraCounter,       CSDRegisterAddress           '

instructionClearLoop    wrbyte  fiveHundredAndTwelve,  SPIExtraBuffer               ' Clear registers.
                        add     SPIExtraBuffer,        #1                           '
                        wrbyte  fiveHundredAndTwelve,  SPIExtraCounter              '
                        add     SPIExtraCounter,       #1                           '
                        djnz    counter,               #instructionClearLoop        '

' //////////////////////Instruction Handle/////////////////////////////////////////////////////////////////////////////////////

instructionLoop         wrbyte  fiveHundredAndTwelve,  commandFlagAddress           ' Clear instruction.

instructionWait         test    cardDetectPin,         ina wz                       ' Update the CD pin state.
                        muxnz   buffer,                #$FF                         '
                        wrbyte  buffer,                CDFlagAddress                '

                        test    writeProtectPin,       ina wc                       ' Update the WP pin state
                        muxc    buffer,                #$FF                         '
                        wrbyte  buffer,                WPFlagAddress                '

if_nz                   mov     cardMounted,           #0                           ' Check the command.
                        rdbyte  cardCommand,           commandFlagAddress           '
                        tjz     cardCommand,           #instructionWait             '

if_z                    cmp     cardCommand,           #"M" wz                      ' If mounting was requested do it.
if_z                    jmp     #mountCard                                          '

                        cmp     cardCommand,           #"O" wz                      ' If operation was requested do it.
if_z                    jmp     #instructionLoop                                    '

                        cmp     cardMounted,           #0 wz                        ' Check if the card is mounted.
if_z                    jmp     #instructionError                                   '

                        mov     counter,               #16                          ' Setup to compare CIDs.
                        mov     SPIBuffer,             CIDRegisterAddress           '
                        rdlong  SPICounter,            par                          '

CIDCompareLoop          rdbyte  SPIExtraBuffer,        SPIBuffer                    ' Compare CIDs.
                        add     SPIBuffer,             #1                           '
                        rdbyte  SPIExtraCounter,       SPICounter                   '
                        add     SPICounter,            #1                           '
                        cmp     SPIExtraBuffer,        SPIExtraCounter wz           '
if_nz                   jmp     #instructionError                                   '
                        djnz    counter,               #CIDCompareLoop              '

                        cmp     cardCommand,           #"B" wz                      ' If rebooting was requested do it.
if_z                    jmp     #rebootChip                                         '

                        cmp     cardCommand,           #"R" wz                      ' If reading was requested do it.
if_z                    jmp     #readBlock                                          '

                        cmp     cardCommand,           #"W" wz                      ' If writing was requested do it. (fall in)
if_nz_or_c              jmp     #instructionError                                   '

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Write Block
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

writeBlock              rdlong  SPIextraBuffer,        sectorPntrAddress            ' Write a block.
                        shl     SPIextraBuffer,        SPIShift                     '
                        movs    commandSPIIndex,       #($40 | 24)                  '
                        call    #commandSPI                                         '

                        tjnz    SPIextraBuffer,        #instructionFlush            ' If failure abort.

                        call    #readSPI                                            ' Send dummy byte.

                        mov     phsb,                  #$FE                         ' Send start of data token.
                        call    #writeSPI                                           '

                        mov     counter,               fiveHundredAndTwelve         ' Setup loop.
                        rdlong  buffer,                blockPntrAddress             '

writeBlockLoop          rdbyte  phsb,                  buffer                       ' Write data out from memory.
                        add     buffer,                #1                           '
                        call    #writeSPI                                           '
                        djnz    counter,               #writeBlockLoop              '

                        call    #wordSPI                                            ' Write out the bogus 16 bit CRC.

                        call    #repsonceSPI                                        ' If failure abort.
                        and     SPIextraBuffer,        #$1F                         '
                        cmp     SPIextraBuffer,        #$5 wz                       '
if_nz                   jmp     #instructionFlush                                   '

                        wrbyte  fiveHundredAndTwelve,  commandFlagAddress           ' Clear instruction.

                        mov     counter,               cnt                          ' Setup loop.

writeBlockBusyLoop      call    #readSPI                                            ' Wait until the card is not busy.
                        cmp     SPIBuffer,             #0 wz                        '
if_z                    mov     SPICounter,            cnt                          '
if_z                    sub     SPICounter,            counter                      '
if_z                    cmpsub  writeTimeout,          SPICounter wc, nr            '
if_z_and_c              jmp     #writeBlockBusyLoop                                 '

if_z                    mov     cardMounted,           #0                           ' Unmount card on failure.

                        call    #shutdownSPI                                        ' Shutdown SPI clock.

                        jmp     #instructionWait                                    ' Return. (instruction already cleared)

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Read Block
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

readBlock               rdlong  SPIextraBuffer,        sectorPntrAddress            ' Read a block.
                        shl     SPIextraBuffer,        SPIShift                     '
                        movs    commandSPIIndex,       #($40 | 17)                  '
                        call    #commandSPI                                         '

                        tjnz    SPIextraBuffer,        #instructionFlush            ' If failure abort.

                        mov     counter,               cnt                          ' Setup loop.

readBlockWaitLoop       call    #readSPI                                            ' Wait until the card sends the data.
                        cmp     SPIBuffer,             #$FF wz                      '
if_z                    mov     SPICounter,            cnt                          '
if_z                    sub     SPICounter,            counter                      '
if_z                    cmpsub  readTimeout,           SPICounter wc, nr            '
if_z_and_c              jmp     #readBlockWaitLoop                                  '

                        cmp     SPIBuffer,             #$FE wz                      ' If failure abort.
if_nz                   jmp     #instructionFlush                                   '

                        mov     counter,               fiveHundredAndTwelve         ' Setup loop.
readBlockModify         rdlong  buffer,                blockPntrAddress             '

readBlockLoop           call    #readSPI                                            ' Read data into memory.
                        wrbyte  SPIBuffer,             buffer                       '
                        add     buffer,                #1                           '
                        djnz    counter,               #readBlockLoop               '

                        call    #wordSPI                                            ' Shutdown SPI clock.
                        call    #shutdownSPI                                        '

readBlock_ret           jmp     #instructionLoop                                    ' Return. Becomes RET when rebooting.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Reboot Chip
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

rebootChip              mov     counter,               #8                           ' Setup cog stop loop.
                        cogid   buffer                                              '

rebootCogLoop           sub     counter,               #1                           ' Stop all cogs but this one.
                        cmp     counter,               buffer wz                    '
if_nz                   cogstop counter                                             '
                        tjnz    counter,               #rebootCogLoop               '

                        mov     counter,               #8                           ' Free all locks. (07654321)
rebootLockLoop          lockclr counter                                             '
                        lockret counter                                             '
                        djnz    counter,               #rebootLockLoop              '

' //////////////////////Setup Memory///////////////////////////////////////////////////////////////////////////////////////////

                        mov     counter,               #64                          ' Setup to grab all sector addresses.
                        rdlong  buffer,                sectorPntrAddress            '

rebootSectorLoadLoop    rdlong  cardRebootSectors,     buffer                       ' Get all addresses of the 64 sectors.
                        add     buffer,                #4                           '
                        add     rebootSectorLoadLoop,  fiveHundredAndTwelve         '
                        djnz    counter,               #rebootSectorLoadLoop        '

' //////////////////////Fill Memory////////////////////////////////////////////////////////////////////////////////////////////

                        mov     readBlock,             #0                           ' Fill these two commands with NOPs.
                        mov     readBlockModify,       #0                           '

                        mov     SPIExtraCounter,       #64                          ' Ready to fill all memory. Pointer at 0.
                        mov     buffer,                #0                           '

rebootCodeFillLoop      mov     SPIextraBuffer,        cardRebootSectors            ' Reuse read block code. Finish if 0 seen.
                        tjz     SPIextraBuffer,        #rebootCodeClear             '
                        add     rebootCodeFillLoop,    #1                           '
                        call    #readBlock                                          '
                        djnz    SPIExtraCounter,       #rebootCodeFillLoop          '

' //////////////////////Clear Memory///////////////////////////////////////////////////////////////////////////////////////////

rebootCodeClear         rdword  counter,               #$8                          ' Setup to clear the rest.
                        mov     SPIExtraCounter,       fiveHundredAndTwelve         '
                        shl     SPIExtraCounter,       #6                           '

rebootCodeClearLoop     wrbyte  fiveHundredAndTwelve,  counter                      ' Clear the remaining memory.
                        add     counter,               #1                           '
                        cmp     counter,               SPIExtraCounter wz           '
if_nz                   jmp     #rebootCodeClearLoop                                '

                        rdword  buffer,                #$A                          ' Setup the stack markers.
                        sub     buffer,                #4                           '
                        wrlong  rebootStackMarker,     buffer                       '
                        sub     buffer,                #4                           '
                        wrlong  rebootStackMarker,     buffer                       '

' //////////////////////Verify Memory//////////////////////////////////////////////////////////////////////////////////////////

                        mov     counter,               #0                           ' Setup to compute the checksum.

rebootCheckSumLoop      sub     SPIExtraCounter,       #1                           ' Compute the RAM checksum.
                        rdbyte  buffer,                SPIExtraCounter              '
                        add     counter,               buffer                       '
                        tjnz    SPIExtraCounter,       #rebootCheckSumLoop          '

                        and     counter,               #$FF                         ' Crash if checksum not 0.
                        tjnz    counter,               #instructionHalt             '

                        rdword  buffer,                #$6                          ' Crash if program base invalid.
                        cmp     buffer,                #$10 wz                      '
if_nz                   jmp     #instructionHalt                                    '

' //////////////////////Boot Interpreter///////////////////////////////////////////////////////////////////////////////////////

                        rdbyte  buffer,                #$4                          ' Switch clock mode for PLL stabilization.
                        and     buffer,                #$F8                         '
                        clkset  buffer                                              '

rebootDelayLoop         djnz    twentyMilliseconds,    #rebootDelayLoop             ' Allow PLL to stabilize.

                        rdbyte  buffer,                #$4                          ' Switch to new clock mode.
                        clkset  buffer                                              '

                        coginit rebootInterpreter                                   ' Restart running new code.

                        cogid   buffer                                              ' Shutdown.
                        cogstop buffer                                              '

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Mount Card
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

mountCard               mov     SPITiming,             #0                           ' Setup SPI parameters.
                        call    #flushSPI                                           '

' //////////////////////Go Idle State//////////////////////////////////////////////////////////////////////////////////////////

                        mov     SPITimeout,            cnt                          ' Setup to try for 1 second.

enterIdleStateLoop      movs    commandSPIIndex,       #($40 | 0)                   ' Send out command 0.
                        mov     SPIextraBuffer,        #0                           '
                        movs    commandSPICRC,         #$95                         '
                        call    #commandSPI                                         '
                        call    #shutdownSPI                                        '

                        cmp     SPIextraBuffer,        #1 wz                        ' Check time.
if_nz                   call    #timeoutSPI                                         '
if_nz                   jmp     #enterIdleStateLoop                                 '

' //////////////////////Send Interface Condition///////////////////////////////////////////////////////////////////////////////

                        movs    commandSPIIndex,       #($40 | 8)                   ' Send out command 8.
                        mov     SPIextraBuffer,        #$1_AA                       '
                        movs    commandSPICRC,         #$87                         '
                        call    #commandSPI                                         '
                        call    #longSPI                                            '
                        call    #shutdownSPI                                        '

                        test    SPIextraBuffer,        #$4 wz                       ' If failure goto SD 1.X initialization.
if_nz                   jmp     #exitIdleState_SD                                   '

                        and     SPIResponce,           #$1_FF                       ' SD 2.0/3.0 initialization.
                        cmp     SPIResponce,           #$1_AA wz                    '
if_nz                   jmp     #instructionError                                   '

' //////////////////////Send Operating Condition///////////////////////////////////////////////////////////////////////////////

exitIdleState_SD        movs    commandSPICRC,         #$FF                         ' Setup to try for 1 second.
                        mov     SPITimeout,            cnt                          '

exitIdleStateLoop_SD    movs    commandSPIIndex,       #($40 | 55)                  ' Send out command 55.
                        mov     SPIextraBuffer,        #0                           '
                        call    #commandSPI                                         '
                        call    #shutdownSPI                                        '

                        test    SPIextraBuffer,        #$4 wz                       ' If failure goto MMC initialization.                                 '
if_nz                   jmp     #exitIdleState_MMC                                  '

                        movs    commandSPIIndex,       #($40 | 41)                  ' Send out command 41 with HCS bit set.
                        mov     SPIextraBuffer,        HCSBitMask                   '
                        call    #commandSPI                                         '
                        call    #shutdownSPI                                        '

                        cmp     SPIextraBuffer,        #0 wz                        ' Check time.
if_nz                   call    #timeoutSPI                                         '
if_nz                   jmp     #exitIdleStateLoop_SD                               '

                        rdlong  buffer,                sectorPntrAddress            ' It's an SDC card.
                        wrlong  itsAnSDCard,           buffer                       '
                        jmp     #readOCR                                            '

' //////////////////////Send Operating Condition///////////////////////////////////////////////////////////////////////////////

exitIdleState_MMC       mov     SPITimeout,            cnt                          ' Setup to try for 1 second.

exitIdleStateLoop_MMC   movs    commandSPIIndex,       #($40 | 1)                   ' Send out command 1.
                        mov     SPIextraBuffer,        HCSBitMask                   '
                        call    #commandSPI                                         '
                        call    #shutdownSPI                                        '

                        cmp     SPIextraBuffer,        #0 wz                        ' Check time.
if_nz                   call    #timeoutSPI                                         '
if_nz                   jmp     #exitIdleStateLoop_MMC                              '

                        rdlong  buffer,                sectorPntrAddress            ' It's an MMC card.
                        wrlong  itsAnMMCard,           buffer                       '

' //////////////////////Read OCR Register//////////////////////////////////////////////////////////////////////////////////////

readOCR                 movs    commandSPIIndex,       #($40 | 58)                  ' Ask the card for its OCR register.
                        mov     SPIextraBuffer,        #0                           '
                        call    #commandSPI                                         '
                        call    #longSPI                                            '
                        call    #shutdownSPI                                        '

                        tjnz    SPIextraBuffer,        #instructionError            ' If failure abort.

                        test    SPIResponce,           OCRCheckMask wz              ' If voltage not supported abort.
                        shl     SPIResponce,           #1 wc                        '
if_z_or_nc              jmp     #instructionError                                   '

                        shl     SPIResponce,           #1 wc                        ' SDHC/SDXC supported or not.
if_c                    mov     SPIShift,              #0                           '
if_nc                   mov     SPIShift,              #9                           '

' //////////////////////Read CSD Register//////////////////////////////////////////////////////////////////////////////////////

                        movs    commandSPIIndex,       #($40 | 9)                   ' Ask the card for its CSD register.
                        mov     SPIextraBuffer,        #0                           '
                        call    #commandSPI                                         '

                        tjnz    SPIextraBuffer,        #instructionFlush            ' If failure abort.
                        call    #repsonceSPI                                        '
                        cmp     SPIextraBuffer,        #$FE wz                      '
if_nz                   jmp     #instructionFlush                                   '

                        mov     counter,               #16                          ' Setup to read the CSD register.
                        mov     buffer,                CSDRegisterAddress           '

readCSDLoop             call    #readSPI                                            ' Read the CSD register in.
                        wrbyte  SPIBuffer,             buffer                       '
                        add     buffer,                #1                           '
                        djnz    counter,               #readCSDLoop                 '

                        call    #wordSPI                                            ' Shutdown SPI clock.
                        call    #shutdownSPI                                        '

' //////////////////////Read CID Register//////////////////////////////////////////////////////////////////////////////////////

                        movs    commandSPIIndex,       #($40 | 10)                  ' Ask the card for its CID register.
                        mov     SPIextraBuffer,        #0                           '
                        call    #commandSPI                                         '

                        tjnz    SPIextraBuffer,        #instructionFlush            ' If failure abort.
                        call    #repsonceSPI                                        '
                        cmp     SPIextraBuffer,        #$FE wz                      '
if_nz                   jmp     #instructionFlush                                   '

                        mov     counter,               #16                          ' Setup to read the CID register.
                        mov     buffer,                CIDRegisterAddress           '

readCIDLoop             call    #readSPI                                            ' Read the CID register in.
                        wrbyte  SPIBuffer,             buffer                       '
                        add     buffer,                #1                           '
                        djnz    counter,               #readCIDLoop                 '

                        call    #wordSPI                                            ' Shutdown SPI clock.
                        call    #shutdownSPI                                        '

' //////////////////////Set Block Length///////////////////////////////////////////////////////////////////////////////////////

                        movs    commandSPIIndex,       #($40 | 16)                  ' Send out command 16.
                        mov     SPIextraBuffer,        fiveHundredAndTwelve         '
                        call    #commandSPI                                         '
                        call    #shutdownSPI                                        '

                        tjnz    SPIextraBuffer,        #instructionError            ' If failure abort.

                        neg     SPITiming,             #1                           ' Setup SPI parameters.

' //////////////////////Setup Card Variables///////////////////////////////////////////////////////////////////////////////////

                        neg     cardMounted,           #1                           ' Return.
                        jmp     #instructionLoop                                    '

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Flush SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

flushSPI                or      dira,                  dataInPin                    ' Untristate the I/O lines.
                        or      dira,                  clockPin                     '

                        mov     SPIExtraCounter,       #74                          ' Send out more than 74 clocks.
flushSPILoop            call    #readSPI                                            '
                        djnz    SPIExtraCounter,       #flushSPILoop                '

flushSPI_ret            ret                                                         ' Return.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Timeout SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

timeoutSPI              mov     SPICounter,            cnt                          ' Check if a second has passed.
                        sub     SPICounter,            SPITimeout                   '
                        rdlong  SPIBuffer,             #0                           '
                        cmpsub  SPIBuffer,             SPICounter wc, nr            '
if_nc                   jmp     #instructionError                                   '

timeoutSPI_ret          ret                                                         ' Return.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Command SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

commandSPI              or      dira,                  dataInPin                    ' Untristate the I/O lines.
                        or      dira,                  clockPin                     '

                        or      dira,                  chipSelectPin                ' Activate the SPI bus.
                        call    #readSPI                                            '

commandSPIIndex         mov     phsb,                  #$FF                         ' Send out command.
                        call    #writeSPI                                           '

                        movs    writeSPI,              #32                          ' Send out parameter.
                        mov     phsb,                  SPIextraBuffer               '
                        call    #writeSPI                                           '
                        movs    writeSPI,              #8                           '

commandSPICRC           mov     phsb,                  #$FF                         ' Send out CRC token.
                        call    #writeSPI                                           '

                        call    #repsonceSPI                                        ' Read in responce.

commandSPI_ret          ret                                                         ' Return.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Responce SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

repsonceSPI             mov     SPIextraBuffer,         #9                          ' Setup responce poll counter.

repsonceSPILoop         call    #readSPI                                            ' Poll for responce.
                        cmpsub  SPIBuffer,              #$FF wc, nr                 '
if_c                    djnz    SPIextraBuffer,         #repsonceSPILoop            '

                        mov     SPIextraBuffer,         SPIBuffer                   ' Move responce into return value.

repsonceSPI_ret         ret                                                         ' Return.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Result SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

longSPI                 add     readSPI,               #16                          ' Read in 32, 16, or 8 bits.
wordSPI                 add     readSPI,               #8                           '
byteSPI                 call    #readSPI                                            '
                        movs    readSPI,               #8                           '

                        mov     SPIResponce,           SPIBuffer                    ' Move long into return value.

byteSPI_ret                                                                         ' Return.
wordSPI_ret                                                                         '
longSPI_ret             ret                                                         '

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Shutdown SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

shutdownSPI             call    #readSPI                                            ' Shutdown the SPI bus.
                        andn    dira,                  chipSelectPin                '
                        call    #readSPI                                            '

                        andn    dira,                  dataInPin                    ' Tristate the I/O lines.
                        andn    dira,                  clockPin                     '

shutdownSPI_ret         ret                                                         ' Return.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Read SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

readSPI                 mov     SPICounter,            #8                           ' Setup counter to read in 1 - 32 bits.
                        mov     SPIBuffer,             #0 wc                        '

readSPIAgain            mov     phsa,                  #0                           ' Start clock low.
                        tjnz    SPITiming,             #readSPISpeed                '

' //////////////////////Slow Reading///////////////////////////////////////////////////////////////////////////////////////////

                        movi    frqa,                  #%0000_0001_0                ' Start the clock - read 1 .. 32 bits.

readSPILoop             waitpne clockPin,              clockPin                     ' Get bit.
                        rcl     SPIBuffer,             #1                           '
                        waitpeq clockPin,              clockPin                     '
                        test    dataOutPin,            ina wc                       '

                        djnz    SPICounter,            #readSPILoop                 ' Loop until done.
                        jmp     #readSPIFinish                                      '

' //////////////////////Fast Reading///////////////////////////////////////////////////////////////////////////////////////////

readSPISpeed            movi    frqa,                  #%0010_0000_0                ' Start the clock - read 8 bits.

                        test    dataOutPin,            ina wc                       ' Read in data.
                        rcl     SPIBuffer,             #1                           '
                        test    dataOutPin,            ina wc                       '
                        rcl     SPIBuffer,             #1                           '
                        test    dataOutPin,            ina wc                       '
                        rcl     SPIBuffer,             #1                           '
                        test    dataOutPin,            ina wc                       '
                        rcl     SPIBuffer,             #1                           '
                        test    dataOutPin,            ina wc                       '
                        rcl     SPIBuffer,             #1                           '
                        test    dataOutPin,            ina wc                       '
                        rcl     SPIBuffer,             #1                           '
                        test    dataOutPin,            ina wc                       '
                        rcl     SPIBuffer,             #1                           '
                        test    dataOutPin,            ina wc                       '

' //////////////////////Finish Up//////////////////////////////////////////////////////////////////////////////////////////////

readSPIFinish           mov     frqa,                  #0                           ' Stop the clock.
                        rcl     SPIBuffer,             #1                           '

                        cmpsub  SPICounter,            #8                           ' Read in any remaining bits.
                        tjnz    SPICounter,            #readSPIAgain                '

readSPI_ret             ret                                                         ' Return. Leaves the clock high.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Write SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

writeSPI                mov     SPICounter,            #8                           ' Setup counter to write out 1 - 32 bits.
                        ror     phsb,                  SPICounter                   '

writeSPIAgain           mov     phsa,                  #0                           ' Start clock low.
                        tjnz    SPITiming,             #writeSPISpeed               '

' //////////////////////Slow Writing//////////////////////////////////////////////////////////////////////////////////////////

                        movi    frqa,                  #%0000_0001_0                ' Start the clock - write 1 .. 32 bits.

writeSPILoop            waitpeq clockPin,              clockPin                     ' Set bit.
                        waitpne clockPin,              clockPin                     '
                        shl     phsb,                  #1                           '

                        djnz    SPICounter,            #writeSPILoop                ' Loop until done.
                        jmp     #writeSPIFinish                                     '

' //////////////////////Fast Writing//////////////////////////////////////////////////////////////////////////////////////////

writeSPISpeed           movi    frqa,                  #%0100_0000_0                ' Write out data.
                        shl     phsb,                  #1                           '
                        shl     phsb,                  #1                           '
                        shl     phsb,                  #1                           '
                        shl     phsb,                  #1                           '
                        shl     phsb,                  #1                           '
                        shl     phsb,                  #1                           '
                        shl     phsb,                  #1                           '

' //////////////////////Finish Up//////////////////////////////////////////////////////////////////////////////////////////////

writeSPIFinish          mov     frqa,                  #0                           ' Stop the clock.

                        cmpsub  SPICounter,            #8                           ' Write out any remaining bits.
                        shl     phsb,                  #1                           '
                        tjnz    SPICounter,            #writeSPIAgain               '
                        neg     phsb,                  #1                           '

writeSPI_ret            ret                                                         ' Return. Leaves the clock low.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Data
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 
fiveHundredAndTwelve    long    $2_00                                               ' Constant 512.
twentyMilliseconds      long    (((20 * (20_000_000 / 1_000)) / 4) / 1)             ' Constant 100,000.

itsAnSDCard             long    $00_43_44_53                                        ' Card type SD token.
itsAnMMCard             long    $00_43_4D_4D                                        ' Card type MMC token.

OCRCheckMask            long    %00_000000_11111111_00000000_00000000               ' Parameter check mask for OCR bits.
HCSBitMask              long    %01_000000_00000000_00000000_00000000               ' Parameter bit mask for HCS bit.

rebootInterpreter       long    (($00_01 << 18) | ($3C_01 << 4) | ($00_00 << 0))    ' Spin interpreter text boot information.
rebootStackMarker       long    $FF_F9_FF_FF                                        ' Spin interpreter stack boot information.

' //////////////////////Configuration Settings/////////////////////////////////////////////////////////////////////////////////

readTimeout             long    0                                                   ' 100 millisecond timeout.
writeTimeout            long    0                                                   ' 500 millisecond timeout.
clockCounterSetup       long    0                                                   ' Clock control.
dataInCounterSetup      long    0                                                   ' Data in control.

' //////////////////////Pin Masks//////////////////////////////////////////////////////////////////////////////////////////////

dataOutPin              long    0
clockPin                long    0
dataInPin               long    0
chipSelectPin           long    0
writeProtectPin         long    0
cardDetectPin           long    0

' //////////////////////Addresses//////////////////////////////////////////////////////////////////////////////////////////////

blockPntrAddress        long    0
sectorPntrAddress       long    0
WPFlagAddress           long    0
CDFlagAddress           long    0
commandFlagAddress      long    0
errorFlagAddress        long    0
CSDRegisterAddress      long    0
CIDRegisterAddress      long    0

' //////////////////////Run Time Variables/////////////////////////////////////////////////////////////////////////////////////

buffer                  res     1
counter                 res     1

' //////////////////////Card Variables/////////////////////////////////////////////////////////////////////////////////////////

cardCommand             res     1
cardMounted             res     1

cardRebootSectors       res     64

' //////////////////////SPI Variables//////////////////////////////////////////////////////////////////////////////////////////

SPIShift                res     1
SPITiming               res     1
SPITimeout              res     1
SPIResponce             res     1
SPIBuffer               res     1
SPICounter              res     1
SPIExtraBuffer          res     1
SPIExtraCounter         res     1

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

                        fit     496




DAT

' //////////////////////Driver Variable Array//////////////////////////////////////////////////////////////////////////////////

cardBlockAddress        long 0 ' Address of the data block in memory to read bytes from and write bytes to.
cardSectorAddress       long 0 ' Address of the sector on the memory card to write bytes to and read bytes from.
cardWriteProtectedFlag  byte 0 ' The secure digital card driver write protected flag.
cardNotDetectedFlag     byte 0 ' The secure digital card driver not card detected flag.
cardCommandFlag         byte 0 ' The secure digital card driver method command flag.
cardErrorFlag           byte 0 ' The secure digital card driver method result flag.

CSDRegister             byte 0[16] ' The SD/MMC CSD register.
CIDRegister             byte 0[16] ' The SD/MMC CID register.

CIDPointer              long 0 ' Pointer to the SD/MMC CID register copy to compare.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


DAT

' //////////////////////Global Variable Array//////////////////////////////////////////////////////////////////////////////////
{
cardClockID             byte 0 ' The secure digital card driver real time clock installed flag. }
cardLockID              byte 0 ' The secure digital card driver lock number.
cardCogID               byte 0 ' The secure digital card driver cog number.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

{{

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                  TERMS OF USE: MIT License
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
}}