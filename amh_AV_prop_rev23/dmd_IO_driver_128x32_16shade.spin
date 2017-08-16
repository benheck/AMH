VAR

  long parameterX                                       'to pass memory location to ASM 


PUB Launch(display_memory, DMD_cog) | g

  parameterX := display_memory                         'Make sure memory location is long-aligned
  coginit(DMD_cog, @Loader, @parameterX)                'Start cog 7 and pass the screen memory location into it.   



DAT     org                                             'New version that uses all internal COG RAM

Loader
        rdlong memstart, par                            'Get location of the beginning of screen memory

        mov enableML, #1
        rol enableML, #21
        mov rdataML, #1
        rol rdataML, #20
        mov rclockML, #1
        rol rclockML, #19
        mov clatchML, #1
        rol clatchML, #18
        mov cclockML, #1
        rol cclockML, #17
        mov cdataML, #1
        rol cdataML, #16

        mov zilch, #0                                   'Set this to a Zero
        
        or dira, cdataML                                'Set all ouput pins to OUT direction (=1)
        or dira, cclockML
        or dira, clatchML
        or dira, rclockML
        or dira, rdataML
        or dira, enableML

        mov outa, rclockML                              'Set row strobe to DISABLE (active low)
        or outa, enableML                               'Set DMD disable to ENABLE (active high) (omit this to control from SPIN)

StartPWM
        mov doublecount, #0
        mov pwmcount, #0                                'Reset PWM counter

DoFrame
        mov pointer, memstart                           'Set pointer to start of frames          
        mov row, #32                                    'Reset row counter

DoRow
        mov column, #64                                 'Number of bytes per row (128 pixels wide, 2 pixels per byte = 64 bytes per row)

DoColumns
        rdbyte datatemp, pointer                        'Load Datatemp with the current byte of screen data
        mov colormask, datatemp                         'Make a copy of Datatemp
        shr colormask, #4

        cmp pwmcount, colormask wc                      'If current PWM count (0-2) is less than the color value (1-3), display that color
        muxc outa, cdataML                              'Assert serial output bit
        muxz outa, cclockML                             'Pulse dot clock
        muxnz outa, cclockML

        mov colormask, datatemp                         'Make a copy of Datatemp
        and colormask, #15                             'AND it with the top 4 bits

        cmp pwmcount, colormask wc                      'If current PWM count (0-2) is less than the color value (1-3), display that color
        muxc outa, cdataML                              'Assert serial output bit
        muxz outa, cclockML                             'Pulse dot clock
        muxnz outa, cclockML

        add pointer, #1                                 'Increment memory pointer (4 bytes per chunk since it's long-aligned)
        djnz column, #DoColumns                         'Keep going until out of columns
 
RowEnd
        cmp row, #32 wz                                 'Check if we're on the first row of the display (counter starts at 32, decrementing)
        muxz outa, rdataML                              'If on row 32, z = 1, else z = 0

        cmp zilch, #0 wz                                'Latch the data onto the registers
        muxz outa, clatchML
        muxnz outa, clatchML
        muxz outa, rclockML                             'Advance the row clock
        muxnz outa, rclockML 

        djnz row, #DoRow                                'Repeat until we've done all 32 rows

FrameEnd
        add pwmCount, #1                                'Increment PWM count
        cmp pwmCount, #16 wc                            'Did it hit 16 yet?
        if_c jmp #DoFrame                               'If not, do next color level

        jmp #StartPWM      


'Set pin #'s                 Prop Pin #         DMD SIGNAL:   DMD PIN #:        Remember to also tie the DMD and Propeller's ground signals together!

enableML      res       1                            'DMD Enable   (pin 1)    
rdataML       res       1                           'Row Data     (pin 3)  
rclockML      res       1                           'Row Clock    (pin 5) 
clatchML      res       1                          'Column Latch (pin 7)  
cclockML      res       1                           'Dot Clock   (pin 9)  
cdataML       res       1                           'Serial Data (pin 11)                  

'Variables

WaitCount     res       1    
row           res       1                       'Which row we are on (0-31)
column        res       1                       'Which column we are on (0-7)
datatemp      res       1                       'Used for temp data storage and bitwise operations
memstart      res       1                       'Start of screen memory
pointer       res       1                       'Current location in screen memory
pwmcount      res       1                       'Which cycle of PWM we are on
colormask     res       1                       'Used to chop up Datatemp into grayscale levels
doublecount   res       1                       'Counter to run "Frame 3" of the PWM twice to make it more distinct
toDoPixels    res       1                       'Counts how many bits need to be shifted out of current long data position

zilch         res       1                       'The number 0. All of my salesmen are ZEROS!!!

rate          long      100                       'Delay between rows for persistance
