// America's Most Haunted - Game Logic
// For PIC32 based pinHeck system
// 2011-2016 Benjamin J Heckendorn

// Have fun!

//Include pin definitions and variables
#include "gs_pins.h"							//System and gameplay variable declarations
#include "lightshow.h"							//Lots of constant 8x8 grid definitions for doing insert lighting "shows"

//Include hardware libraries
#include <p32xxxx.h>							//PIC32 
#include <plib.h>								  //PIC32
#include <Servo.h>								//Servo control for toys

//GIbg: Lightning, Ball, Theater, Hotel, War, Whore, Doctor, Prison
//GIpf: Near, Middle, Far, Scoop Flasher, 0000

unsigned long versionNumber = 23;				//Code Revision 23, August 2016

Servo myservo[7];								//Setup servo objects

//The Main Loop of the Game. We always keep this at the top.........................
void setup() {									//Assign functions, begin interrupts, low level stuff                

  //Wire.begin(); // join i2c bus (address optional for master)

//Enable interrupt for Light Driver.-------------------------------------
	ConfigIntTimer2(T2_INT_ON | T2_INT_PRIOR_6);
	OpenTimer2(T2_ON | T2_PS_1_1, F_CPU / lightcyclefreq);
//-----------------------------------------------------------------------


//Enable interrupt for Switch Driver-------------------------------------
	ConfigIntTimer3(T3_INT_ON | T3_INT_PRIOR_3);
	OpenTimer3(T3_ON | T3_PS_1_1, F_CPU / switchfreq);
//-----------------------------------------------------------------------

	Serial.begin(115200);
	commandByte = 0;
 
 
//Set MSB's of Port D to output (row low trigger) and LSB's to input (switch column sense)---------------------------------------- 
	TRISD = (B00000000 << 8 ) + B11111111;
//-----------------------------------------------------------------------

//Set port B to output for light control-------------------------------- 
	TRISB = 0; 
//-----------------------------------------------------------------------

//Configure servos to data pins-----------------------------------------

	myservo[0].attach(46);
	myservo[1].attach(44);
	myservo[2].attach(17);
	myservo[3].attach(34);
	//myservo[4].attach(33);
	//myservo[5].attach(32);
	//myservo[6].attach(31);
	
//-----------------------------------------------------------------------

//Set I/O directions-----------------------------------------------------

	pinMode(RGBData, OUTPUT);   //E1
	pinMode(RGBClock, OUTPUT);  //E2
			
	pinMode(solenable, OUTPUT);

	for (int x = 0 ; x < 24 ; x++) {    //Set all solenoid pins to OUTPUTS and set OFF.
		pinMode(SolPin[x], OUTPUT);
		digitalWrite(SolPin[x], 0);  
	}

	pinMode(cdatain, INPUT);
	pinMode(cclock, OUTPUT);
	pinMode(clatch, OUTPUT);
	pinMode(GIdata, OUTPUT);

	pinMode(startLight, OUTPUT);
	digitalWrite(startLight, 0);		//Disable Start Light
	
//digitalWrite(clatch, 1); //Reset load values (default position)

//Set command bus pins to output-----------------------------------------
	//digitalWrite(ATN, 0);
	//digitalWrite(SDI, 0);	
	digitalWrite(CLK, 0);
	digitalWrite(SDO, 0);

	//pinMode(SDI, OUTPUT);	
	pinMode(SDI, INPUT);
	pinMode(CLK, OUTPUT);
	pinMode(SDO, OUTPUT);
//-----------------------------------------------------------------------


//-----------------------------------------------------------------------

	killQ();									//If we reset, make sure nothing's in the video queue
	stopMusic();								//Has no purpose on cold boot, but useful when debugging
	stopVideo(0);								//Likewise
	killCustomScore();							//Likewise
	graphicsMode(255, 0);						//AV will be waiting in Mode 10 state. Set 255 so it will advance to Attract Mode
	
	loadHighScores();							//Get high scores from EEPROM
	loadSettings();								//Get game settings from EEPROM

	Serial.println("pinHeck System 2011-2016");
	Serial.println("Benjamin J Heckendorn, Parker Dillmann, Chris Kraft, Roy Ethlam");
	Serial.println("-------------------------------");	
	Serial.print("Game:");
	printName();
	Serial.println("");
	Serial.print("Version:");
	printVersion();
	Serial.println("");	
	Serial.println("-------------------------------");		
	
	Serial.println("Type [HELP!!] for list of serial commands"); 	
	Serial.println(" ");
	
	//showCommands();
	
}
	
void loop() {									//Arduino-style "main loop"
	
	MachineReset(); 							//Comment this out when testing board OFF the machine

	multiTimer = 0;								//Use to run backglass lights
	multiCount = 0;
	
	leftRGB[0] = 175;
	leftRGB[1] = 175;
	leftRGB[2] = 175;
	rightRGB[0] = 175;
	rightRGB[1] = 175;
	rightRGB[2] = 175;
	
	run = 0;
	modeTimer = 0;								//Use for Attract Mode
	
	houseKeeping();								//Check a few times, so we don't get a false positive on the door open or close state
	houseKeeping();

	if (bitRead(cabinet, Door) == 0) {			//Is door open?	We need to check even if DOOR WARN is disabled	
		coinDoorState = 1;						//Set state to OPEN
	}
	else {
		coinDoorState = 0;						//Set state to CLOSED	
	}	
	
	//Serial.println(coinDoorDetect);

	switchDebounceClear(16, 63);					//Reset debounces manually just in case
	drainTries = 0;									//We haven't tried to kick the drain yet

	animatePF(0, 30, 1);							//Original attract lights, set to repeat
	
	modeTimer = 0;
	multiTimer = 0;
	
	while(run == 0) {  								//While waiting for a start condition. Attract mode

		houseKeeping();

    if (skillScoreTimer) {          //Used to time flipper sounds (fun for kids!)     
      skillScoreTimer -= 1;      
    }
    
		//			playSFX(2, 'C', 'B', 65 + random(21), 100);			//Ghost wail + Team Dialog
		
		if (cabSwitch(Menu) and freePlay == 0) {				  //Push menu for service credit if not in freeplay mode		
			playSFX(0, 'C', 'B', 65 + random(20), 255);			//Ghost wail + Team Dialog			
			credits += 1;
			Update(startingAttract);						            //Set attract mode to ON (also sets Freeplay, number credits)
		}

		if (countBalls() < 4) {						//Not enough balls in trough?
			ballSearchDebounce(1);					//Set slow debounce
			ballSearch();
		}
	
		if (kickTimer > 0) {						//Ball needs kicked from the drain?
			swDebounce[63] = swDBTime[63];			//Keep the debounce on to prevent a re-trigger until it's gone
			kickTimer -= 1;
			if (kickTimer == 6000) {				//Ready to kick it?
				Coil(drainKick, drainStrength + drainTries);		//Give it a kick!
				drainTries += 2;					//Increase the power. If the ball hits Switch 4, then it loaded and this is clear. If not, it kicks harder with each re-try
				if (drainTries == 10) {
					drainTries = 0;
				}
			}
			if (kickTimer < drainPWMstart) {		//After the kick, pulse hold the coil a bit...
				kickPulse += 1;
				if (kickPulse > 75) {				//Wait appx 10 ms
					kickPulse = 0;					//Reset timer
					Coil(drainKick, 1);				//Kick for 1 ms
				}
			}
			if (kickTimer == 0) {					//Then turn off the coil
				digitalWrite(SolPin[drainKick], 0); //Make sure it's off
			}
		}	

		if (Switch(62)) {							//Ball on Ball Switch 4?	
				
			if (kickFlag) {												//Ball got her via a drain kick?
				kickFlag = 0;											//Clear flag, ball kick complete
				drainTries = 0;		
			}
	
		}
		
		if (cabSwitch(Enter) or menuAbortFlag) {		//Did user press the switch, or press it during a game and aborted the game?
			//video('A', 'Z', 'Z', 0, 0, 255);			//Play a fake video
			
			menuAbortFlag = 0;							//Clear flag
      playSFX(1, 'O', 'R', 'Y', 255);	//Play the entry sound!
			topMenu();
		}
		
		if (coinDoorDetect) {							//Warn on door open?
			if (bitRead(cabinet, Door) == 0) {							//Is door open?
				if (coinDoorState == 0) {								//Was it closed before?			
					coinDoorState = 1;									//Set state to OPEN
					video('A', 'T', 'Z', 0, 0, 255);					//Play video
					playSFX(2, 'X', 'X', '8', 255);
				}
			}			
			if (cabSwitch(Door)) {										//Is door closed?
				if (coinDoorState == 1) {								//Was door opened before?
					coinDoorState = 0;									//Set state to CLOSED
					playSFX(2, 'X', 'X', '9', 255);
				}			
			}
		}
				
		if (attractLights) {
			AttractMode();

			//stressTest();
			
		}
				
		if (cabSwitch(LFlip)) {		//If flipper button pressed in Attract Mode...
      
      if (skillScoreTimer == 0) {        
        playSFX(2, 'C', 'B', 65 + random(21), 100);			//Ghost wail + Team Dialog
        skillScoreTimer = 600000;                      //Can't trigger another sound for at least a minute       
      }
    
			if (tournament) {		//If Tourney, both flippers do same thing
				Update(holdTourneyScores);			//Jump to last game's scores and stay there
			}
			else {					//Normal operation
				Update(highScoreTable);			//Jump to High Score Table			
			}
			stopVideo(0);		//In case attract mode was on a video		
		}
	
		if (cabSwitch(RFlip)) {		//If flipper button pressed in Attract Mode
    
       if (skillScoreTimer == 0) {        
        playSFX(2, 'C', 'B', 65 + random(21), 100);			//Ghost wail + Team Dialog
        skillScoreTimer = 600000;                      //Can't trigger another sound for at least a minute       
      }
      
			if (tournament) {		//If Tourney, both flippers do same thing
				Update(holdTourneyScores);			//Jump to last game's scores and stay there
			}
			else {					//Normal operation
				if (showScores) {
					Update(lastGameScores);			//Jump to last game's scores	
				}
				else {					//If there wasn't a last game, jump to High Scores
					Update(highScoreTable);			//Jump to last game's scores and stay there							
				}						
			}
			stopVideo(0);		//In case attract mode was on a video		
		}
	
		if (debugSwitch) {
			switchTest();				//Show matrix switches on serial monitor
			delay(10);
		}

		if (switchDead) {						//To unstick balls while we're trying to start a game		
			switchDead += 1;			
			switchDeadCheck();	
		}
		
		//Why don't these work??? They work only if a game has completed. What is enabled only when a game starts?
		if (HellSpeed) {							//Is the elevator supposed to be moving?
			//Serial.println("Moving hell");
			MoveElevator();			//Do routine.
		}	
		if (TargetSpeed) {							//Is the target supposed to be moving?
			//Serial.println("Moving target");
			MoveTarget();
		}
		if (DoorSpeed) {							//Is the door supposed to be moving?
			//Serial.println("Moving door");
			MoveDoor();				//Do routine.
		}	
			
		checkStartButton(0);              //Look for coins and Start button presses
	
		lookForSerial();
		
	}
	
	startAnyway = 0;
	ballsInGame = countBalls();					    //Double check the # of balls in the game

	if (ballsInGame < 4) {						     //Did we lose one during play?
		creditDot = 1;
	}
	else {
		creditDot = 0;		
	}
	
	StartGame(1);								            //Begin game (load a ball)
		
	while(ball < ballsPerGame) {     			 //As long as we haven't advanced to ball 4...
		
		MainLoop();			//Do the main loop
		
	}

	ballsInGame = countBalls();					   //Double check the # of balls in the game

	if (ballsInGame < 4) {						     //Did we lose one during play? Set credit dot, will get saved during audits
		creditDot = 1;
	}
	else {
		creditDot = 0;		
	}

	//Be sure the flippers are off!
	leftDebounce = 0;
	LFlipTime = -10;							        //Make flipper re-triggerable, with debounce
	LholdTime = 0;								        //Disable hold timer.
	digitalWrite(LFlipHigh, 0); 				  //Turn off high power
	digitalWrite(LFlipLow, 0);  				  //Switch off hold current	
	
	rightDebounce = 0;
	RFlipTime = -10;							        //Make flipper re-triggerable, with debounce
	RholdTime = 0;								        //Disable hold timer
	digitalWrite(RFlipHigh, 0); 				  //Turn off high power
	digitalWrite(RFlipLow, 0);  				  //Switch off hold current			
	
	if (menuAbortFlag == 0) {					    //Game ended normally? (we didn't abort by entering the menu?)
		GameOver();								          //Do normal game over stuff	
		gamesPlayed += numPlayers;				  //Increment games played
		saveAudits();							          //Save game stats		
	}
			
}

void MainLoop() {								//The Main Loop of the Game. We always keep this at the top

	houseKeeping();								//Do lights, switch debounce, get cab switches and control solenoids
	
	flippers();

	Timers();									//Event timers

	if (skillShot) {
		if (bitRead(switches[7], 1) == 1) {		//Skill shot not collected yet, and ball sitting in shooter lane? Then we can change it! (and also restart game if desired)
			if (cabSwitch(LFlip)) {
				skillShot -= 1;
        skillScoreTimer = 0;
               
				if (skillShot < 1) {
					skillShot = 3;
				}
        killQ();
				video('K', '9', '9', noExitFlush, 0, 255);	//Static transition shot
        
				if (numPlayers == 1) {														//In single player games, do not indicate Player #	
					customScore('K', '0', 64 + skillShot, allowSmall | loopVideo);			//Custom Score for skill shot
				}
				else {																		//Multiplayer, show which player is up and has the skill shot
        
          videoQ('K', 48 + player, 64 + skillShot, allowSmall | noEntryFlush, 0, 1);
          numbers(7, 2, 44, 27, numPlayers);										//Update Number of players indicator
          numbers(6, numberScore | 6, 0, 0, player);						//Put player score upper left, using Double Zeros
          numbers(5, 9, 88, 0, 0);										          //Ball # upper right	             

				}
				playSFX(1, 'S', '9', '9', 255);	//Static sound
			}
			if (cabSwitch(RFlip)) {
				skillShot += 1;
        skillScoreTimer = 0;
				if (skillShot > 3) {
					skillShot = 1;
				}
        killQ();
				video('K', '9', '9', noExitFlush, 0, 255);	//Static transition shot
        
				if (numPlayers == 1) {														//In single player games, do not indicate Player #	
					customScore('K', '0', 64 + skillShot, allowSmall | loopVideo);			//Custom Score for skill shot
				}
				else {																		//Multiplayer, show which player is up and has the skill shot
        
          videoQ('K', 48 + player, 64 + skillShot, allowSmall | noEntryFlush, 0, 1);
          numbers(7, 2, 44, 27, numPlayers);										//Update Number of players indicator
          numbers(6, numberScore | 6, 0, 0, player);						//Put player score upper left, using Double Zeros
          numbers(5, 9, 88, 0, 0);										          //Ball # upper right	   	      
          
				}
				playSFX(1, 'S', '9', '9', 255);	//Static sound
			}		
      if (bitRead(cabinet, Start) == 1 and ball > 1) {		//Start button held on Ball 2 or later?
        
				if (freePlay == 0) {				                      //Not on freeplay?
					if (credits) {					                        //Then we need a credit
            gameRestart += 1;
            if (gameRestart > cycleSecond6) {                //Held long enough?
              credits -= 1;
              StartGame(0);								                   //Restart game (and do NOT load a ball)
            } 			
					}
				}
				else {								                              //If on freeplay, go for it!
          gameRestart += 1;
          if (gameRestart > cycleSecond6) {                 //Held long enough?
            StartGame(0);								                    //Restart game (and do NOT load a ball)
          } 			
				}        
       
      }      
		}

		if (numPlayers > 1) {
      
			skillScoreTimer += 1;
			
			if (skillScoreTimer > (cycleSecond4 + (10000 * numPlayers))) {	//4 seconds of video, then 1 second of scores for each player (up to 4 extra seconds)
				skillScoreTimer = 0;
        //killQ();
        video('K', 48 + player, 64 + skillShot, allowSmall | noEntryFlush, 0, 1);
        numbers(7, 2, 44, 27, numPlayers);										//Update Number of players indicator
        numbers(6, numberScore | 6, 0, 0, player);						//Put player score upper left, using Double Zeros
        numbers(5, 9, 88, 0, 0);										          //Ball # upper right	      

			}			
			
		}    
    
	}
	
	if (run == 2) {								//Ball has been loaded, waiting for the ball to be launched?
		
		if (bitRead(switches[7], 1) == 0) {		//Ball launched off shooter lane?
			launchCounter += 1;
			//Serial.print("LAUNCH#");
			//Serial.println(launchCounter, DEC);
			run = 3;								//Set condition
			playMusic('M', '2');					//Normal music
		}
    
	}

	if (run == 3) {								//If NOT in a drain state, do Logic and Switches
		logic();								//Think about things! Think... different...
		switchCheck();							//Interpet the switches
		
		secondsCounter += 1;
		
		if (secondsCounter > cycleSecond) {		//Count # of seconds game has been active
			secondsCounter = 0;
			totalBallTime += 1;			
		}
			
		if (cabSwitch(Tilt)) {
			if (tiltFlag == 0 and skillShot == 0 and deProgress[player] != 50 and videoMode[player] < 100) {	//Tilt warning? Can't get one until full ball launch, or during game credits, or during video mode

				tiltCounter += 1;
				
				if (tiltCounter > (tiltLimit - 1)) {
					tiltCounter = 0;									                //Stop counting...
					tilt();												                    //and TILT the game			
				}
				else {													                    //Warn the player!
          stopVideo(0);	
					video('K', 'Z', 'W', 0, 0, 255);              //New warning video
					if (tiltCounter < 5) {										//Four increasing lower TILT warning sounds
						playSFX(0, 'K', 'A', 47 + tiltCounter, 255);								
					}
          else {
            playSFX(0, 'K', 'A', '3', 255);								//If more than that, use the lowest one	  
          }														
				}		        
			}
		}
		
	}
	
	if (cabSwitch(Menu)) {
		showGameStatus();
	}	
	
	if (coinDoorDetect) {						//Warn if door opened?

		if (bitRead(cabinet, Door) == 0) {							//Is door open?
			if (coinDoorState == 0) {								//Was it closed before?			
				coinDoorState = 1;									//Set state to OPEN
				video('A', 'T', 'Z', 0, 0, 255);					//Play video
				playSFX(2, 'X', 'X', '8', 255);
			}
		}
		
		if (cabSwitch(Door)) {										//Is door closed?
			if (coinDoorState == 1) {								//Was door opened before?
				coinDoorState = 0;									//Set state to CLOSED
				playSFX(2, 'X', 'X', '9', 255);
			}			
		}
	
	}
		
	if (cabSwitch(Enter) and menuAbortFlag == 0) {		//Did user press the Enter switch during a game?
		//extraBalls = 1;								//TESTING!
		//video('A', 'Z', 'Z', 0, 0, 255);			//Play a fake video
		
		menuAbortFlag = 1;								//Set flag
		stopMusic();
		ball = ballsPerGame;							//This will end the game
	}
				
	checkStartButton(run);						//Check the start button and coin slot

}

void runVideoMode() {							//The video mode
	
	TargetSet(TargetUp);						//Trap it using the targets

	//player = 1;											//TESTING ONLY REMOVE FOR REALS

	//KILL LIGHTS TO DRAW ATTENTION TO DMD

	AutoEnable = 0;								//Disable flippers
	
	//Make sure flippers are dead!
	leftDebounce = 0;
	LFlipTime = -10;							//Make flipper re-triggerable, with debounce
	LholdTime = 0;								//Disable hold timer.
	digitalWrite(LFlipHigh, 0); 				//Turn off high power
	digitalWrite(LFlipLow, 0);  				//Switch off hold current	
		
	rightDebounce = 0;
	RFlipTime = -10;							//Make flipper re-triggerable, with debounce
	RholdTime = 0;								//Disable hold timer
	digitalWrite(RFlipHigh, 0); 				//Turn off high power
	digitalWrite(RFlipLow, 0);  				//Switch off hold current
	
	playSFX(0, 'G', 'Z', 'Z', 255);						//Starting sound or something
	stopMusic();
	modeTotal = 0;
	videoMode[player] = 100;							//Starting state
	
	GIpf(B00000000);
	storeLamp(player);
	allLamp(0);
	
	cabColor(0, 255, 0, 0, 255, 0);
	doRGB();
	
	ghostY = 24;										//Starts at the bottom	
	
	comboKill();
	killQ();	
	killNumbers();
	video('V', '0', '0', loopVideo, 0, 255);			//Instructions will loop until you flip ghost up halfway
	modeTimer = 0;

	int ghostSprite = 38;
	int x = 0;
	
	int dead = 0;
	
	videoCount = 0;
	videoCycles = 200;
	videoSpeed = videoSpeedStart;
	vidBank = 65;										

	for (x = 0 ; x < 16 ; x++) {						//Clear any possible collision registers
		dataIn[x] = 0;		
	}
	
	x = 0;

	while(dead == 0) {
	
		houseKeeping();
	
		modeTimer += 1;
	
		if (modeTimer > videoCycles) {										//This inner condition is the speed at which video mode actually runs
			
			modeTimer = 0;

			if (cabSwitch(LFlip) or cabSwitch(RFlip)) {						//Hit either button. By alternating you can avoid debounce a bit and speed up the movement
				ghostY -= 8;
				if (ghostY < 0) {
					ghostY = 0;
				}
				if (ghostY < 12 and videoMode[player] == 100) {				//Waiting for start condition?
					videoMode[player] = 101;														//Motion started!
					video('V', '1', '0' + random(5), manualStep | allowSmall | noExitFlush, 0, 255);				//Starting path (ends with A screen)	
					numbers(1, numberScore | 2, 128, 0, player);									//Show small player's score in upper left corner of screen
					frameNumber = 0;
					playMusic('V', 'M');									//Video Mode Music
				}				
			}
			else {
				ghostY += 1;				
				if (ghostY > 24) {
					ghostY = 24;
				}
			}
			
			x += 1;
			
			if (x == 10) {
				x = 0;
				ghostSprite += 1;
				if (ghostSprite > 39) {
					ghostSprite = 38;
				}
			}
			
			characterSprite(0, returnPixels, 24, ghostY, 8, ghostSprite);							//Command
			
			videoCount += 1;
			
			if (videoCount > videoSpeed and videoMode[player] == 101) {								//Screen is moving?
			
				AddScore(1010);	
				modeTotal += 1010;				
				videoCount = 0;
				videoControl(6);																	//Command

				frameNumber += 1;
				
				//Serial.println();
				
				for (int xx = 0 ; xx < 16 ; xx++) {
					
					// Serial.print(" ");
					// Serial.print(dataIn[xx], BIN);
					
					if (dataIn[xx]) {
						dead = 1;
					}
				}
				
				//Serial.println();				
																
				if (frameNumber == 100) {																	//Getting close to end of current video?					
					videoQ('V', vidBank, '0' + random(5), manualStep | noEntryFlush | allowSmall | noExitFlush, 0, 255);	//Get next video ready (don't flush numbers)
					
					vidBank += 1;
					
					if (vidBank == 67) {
						vidBank = 65;
					}									
				}
				if (frameNumber == 150) {
				
					frameNumber = 0;
					
					videoSpeed -= 1;
					
					if (videoSpeed < 1) {
						videoSpeed = 1;
						videoCycles -= 5;
						if (videoCycles < 100) {
							videoCycles = 100;
						}
					}			
				}
			}	

			if (videoMode[player] == 100) {															//After about 6 seconds, start the mode even if player hasn't flipped
				frameNumber += 1;
				if (frameNumber == 400) {
					videoMode[player] = 101;																//Motion started!
					video('V', '1', '0' + random(5), manualStep | allowSmall | noExitFlush, 0, 255);		//Starting path (ends with A screen)	
					numbers(1, numberScore | 2, 128, 0, player);											//Show small player's score in upper left corner of screen
					frameNumber = 0;
					playMusic('V', 'M');									//Video Mode Music					
				}
			}			
		}		
	}
	
	playSFX(0, 'G', 'Z', 'Z', 255);

	frameNumber = cycleSecond * 5; //10000;
	
	fadeMusic(2, 0);											//Fade to 0	
	
	while (frameNumber) {										//Short pause to see your crash + final score + LOOK DOWN prompt
		houseKeeping();
		frameNumber -= 1;
		if (frameNumber == (cycleSecond * 4)) {							//Watch crash for 1 second, then move on to end		
			killQ();
			killNumbers();
			stopVideo(0);		
			video('V', '9', '9', allowLarge, 0, 255); 					//Video Mode Total
			numbers(0, numberFlash | 1, 255, 11, modeTotal);			//Load Mode Total Points	
			videoSFX('V', '9', '8', 0, 0, 255, 0, 'C', 'Z', 'Z', 255);	//"3 2 1!" ball release				
		}		
	}	

	stopMusic();
		
	videoMode[player] = 0;										//Ending state
	setCabModeFade(defaultR, defaultG, defaultB, 100);			//Reset to default color
	
	//RESTORE LIGHTS
	
	GIpf(B11100000);
	loadLamp(player);
	TargetSet(TargetDown);										//Put them down to release the ball
	TargetTimerSet(12000, TargetUp, 10);						//and after a second, put the back up

	playMusic('M', '2');										//Normal music		
	minionEnd(2);												//Re-enable Minion find but do NOT let it control targets since this mode needs to do that	

	if (saveTimer < (cycleSecond * 5)) {					//Time for targets to go down + 2 seconds in case the ball STDM's
		saveTimer = (cycleSecond * 5);						//Now it's user defined, in milliseconds
	}
	
	spookCheck();												//See what to do with the Save Timer light	
	
	AutoEnable = 255;											//Re-enable flippers
		
}

void topMenu() {								//These functions do the logic for the service

	animatePF(0, 0, 0);							//Kill attract animation
	allLamp(0);
	GIpf(0);
	GIbg(0);
	Update(0);
	stopVideo(0);
	whichMenu = 1;
	whichSelection = 9;						//Menu should bring you back into whichever one you last left, since that's the one you're likely to want to tweak again. Mostly.
	audioSwitch = 0;
	
	graphicsMode(10, clearScreen);
	graphicsMode(10, loadScreen);
	graphicsMode(10, clearScreen);
	graphicsMode(10, loadScreen);
	
	menuDisplay();
	menuDisplay();
	
	while (whichSelection < 255) {
	
		houseKeeping();				//Get switches, lights, etc
		lookForSerial();
		
		if (cabSwitch(RFlip)) {
			playSFX(1, 'O', 'R', 'X', 255);
			whichSelection += 1;
			if (whichSelection > 11) {
				whichSelection = 1;
			}
			menuDisplay();
		}		
		if (cabSwitch(LFlip)) {
			playSFX(1, 'O', 'R', 'W', 255);		
			whichSelection -= 1;
			if (whichSelection < 1) {
				whichSelection = 11;
			}
			menuDisplay();			
		}
		if (cabSwitch(Enter) or cabSwitch(Start)) {	
			playSFX(1, 'O', 'R', 'Y', 255);
			switch (whichSelection) {				
				case 1:
					switchMenu();			
					break;
				case 2:
					audioMenu();			
					break;							
				case 3:
					solenoidMenu();			
					break;		
				case 4:
					servoMenu();			
					break;
				case 5:
					servoSettingsMenu();
					break;
				case 6:
					lampMenu();
					break;
				case 7:
					rgbMenu();
					break;
				case 8:
					coilMenu();
					break;
				case 9:
					mainSettingsMenu();
					break;	
				case 10:
					gameSettingsMenu();
					break;
				case 11:
					auditMenu();
					break;			
			}
			whichMenu = 1;
			menuDisplay();
		}		
		if (cabSwitch(Menu)) {		//Abort menu?
			whichSelection = 255;			//Jump out
		}				
	}

	graphicsMode(0, 0);
	modeTimer = 0;
	Update(1);
	animatePF(0, 30, 1);						//Restart animation
	
} 

void switchMenu() {								//Menu for looking at the switch matrix

	whichMenu = 2;
	whichSelection = 0;
	modeTimer = 0;
	
	menuDisplay();
	
	while (whichSelection < 255) {
	
		houseKeeping();								//Get switches, lights, etc
		lookForSerial();
		
		if (cabSwitch(Enter) or cabSwitch(Start)) {	
			audioSwitch += 1;
			if (audioSwitch > 1) {
				audioSwitch = 0;
				playSFX(1, 'X', 'X', '1', 255);	
			}
			else {
				playSFX(1, 'X', 'X', '0', 255);	
			}
			menuDisplay();
			modeTimer = 0;							//To prevent data being resent too quickly
		}		
		if (cabSwitch(Menu)) {						//Abort menu?
			playSFX(1, 'O', 'R', 'Z', 255);	
			whichSelection = 255;					//Jump out
		}
		
		modeTimer += 1;		
		if (modeTimer > 1750) {
			menuDisplay();
			modeTimer = 0;
		}		
	}
	
	whichSelection = 1;								//So the upper level menu won't abort out
	modeTimer = 0;									//Reset to be safe
	
}

void audioMenu() {								//Menu for testing audio

	whichMenu = 3;
	whichSelection = 1;

	menuDisplay();
	
	while (whichSelection < 255) {
	
		houseKeeping();				//Get switches, lights, etc
		lookForSerial();
		
		if (cabSwitch(RFlip)) {
			playSFX(1, 'O', 'R', 'X', 255);	
			whichSelection += 1;
			if (whichSelection > 6) {
				whichSelection = 1;
			}
			menuDisplay();							
		}		
		if (cabSwitch(LFlip)) {
			playSFX(1, 'O', 'R', 'W', 255);			
			whichSelection -= 1;
			if (whichSelection < 1) {
				whichSelection = 6;
			}
			menuDisplay();			
		}
		if (cabSwitch(Enter) or cabSwitch(Start)) {	
			switch (whichSelection) {
				case 1:
					stereoSFX(0, 'C', 'A', 65 + random(14), 255, sfxDefault, 0);				
					break;		
				case 2:
					stereoSFX(0, 'C', 'A', 65 + random(14), 255, 0, sfxDefault);						
					break;	
				case 3:
					playSFX(0, 'C', 'A', 65 + random(14), 255); 			//Random ghost wails						
					break;													
				case 4:
					playMusic('C', 'S');								//Dey da Ghost Squad!						
					break;		
				case 5:
					stopMusic();							
					break;
				case 6:
					fadeMusic(3, 0);				//Fade to 0							
					break;					
			}	
			
		}		
		if (cabSwitch(Menu)) {						//Abort menu?
			playSFX(1, 'O', 'R', 'Z', 255);	
			whichSelection = 255;					//Jump out
		}
		
	}
	
	whichSelection = 2;								//So the upper level menu won't abort out

}

void solenoidMenu() {							//Menu for testing MOSFETs

	whichMenu = 4;
	whichSelection = 16;
	
	menuDisplay();
	
	while (whichSelection < 255) {
	
		houseKeeping();				//Get switches, lights, etc
		lookForSerial();
		
		if (cabSwitch(RFlip)) {
			playSFX(1, 'O', 'R', 'X', 255);	
			whichSelection += 1;
			if (whichSelection > 23) {
				whichSelection = 0;
			}
			menuDisplay();
		}		
		if (cabSwitch(LFlip)) {	
			playSFX(1, 'O', 'R', 'W', 255);	
			whichSelection -= 1;
			if (whichSelection < 0) {
				whichSelection = 23;
			}
			menuDisplay();			
		}
		if (cabSwitch(Enter) or cabSwitch(Start)) {	
			playSFX(1, 'O', 'R', 'Y', 255);	
			if (whichSelection == Magnet) {
				Coil(whichSelection, 250);			//Pulse the magnet for longer			
			}
			else {
				Coil(whichSelection, 25);			//Else a short test burst
			}
		}		
		if (cabSwitch(Menu)) {						//Abort menu?
			playSFX(1, 'O', 'R', 'Z', 255);	
			whichSelection = 255;					//Jump out
		}				
	}
	
	whichSelection = 3;				//So the upper level menu won't abort out

}

void servoMenu() {								//Menu for testing Servos

	whichMenu = 5;
	whichSelection = 1;
	
	menuDisplay();
	
	while (whichSelection < 255) {
	
		houseKeeping();				//Get switches, lights, etc
		lookForSerial();
		
		if (cabSwitch(RFlip)) {
			playSFX(1, 'O', 'R', 'X', 255);	
			whichSelection += 1;
			if (whichSelection > 9) {
				whichSelection = 1;
			}
			menuDisplay();
		}		
		if (cabSwitch(LFlip)) {
			playSFX(1, 'O', 'R', 'W', 255);	
			whichSelection -= 1;
			if (whichSelection < 1) {
				whichSelection = 9;
			}
			menuDisplay();			
		}
		if (cabSwitch(Enter) or cabSwitch(Start)) {	
			playSFX(1, 'O', 'R', 'Y', 255);	
			switch (whichSelection) {												//What to show, and where to go
				case 1:		
					DoorLocation = DoorOpen;
					myservo[DoorServo].write(DoorLocation);				
					break;		
				case 2:			
					DoorLocation = DoorClosed;
					myservo[DoorServo].write(DoorLocation);				
					break;						
				case 3:	
					TargetLocation = TargetUp;
					myservo[Targets].write(TargetLocation);							
					break;		
				case 4:		
					TargetLocation = TargetDown;
					myservo[Targets].write(TargetLocation);					
					break;	
				case 5:		
					GhostLocation = 10;
					myservo[GhostServo].write(GhostLocation);	
					break;		
				case 6:		
					GhostLocation = 90;
					myservo[GhostServo].write(GhostLocation);				
					break;	
				case 7:		
					GhostLocation = 170;
					myservo[GhostServo].write(GhostLocation);			
					break;		
				case 8:
					HellLocation = hellUp;
					myservo[HellServo].write(HellLocation);			
					break;	
				case 9:		
					HellLocation = hellDown;
					myservo[HellServo].write(HellLocation);				
					break;		
			}					
		}		
		if (cabSwitch(Menu)) {		//Abort menu?
			playSFX(1, 'O', 'R', 'Z', 255);	
			whichSelection = 255;			//Jump out
		}				
	}
	
	whichSelection = 4;				//So the upper level menu won't abort out

}

void servoSettingsMenu() {						//Menu for manually change servo position defaults

	whichMenu = 6;
	whichSelection = 1;
	
	menuDisplay();

	settingsState = 0;							//0 = Selecting servo, 1 = Changing servo
	
	while (whichSelection < 255) {
	
		houseKeeping();				//Get switches, lights, etc
		lookForSerial();
		
		if (settingsState) {						//What flippers do change based off the Enter toggle (either select a servo, or change the servo)
			if (cabSwitch(RFlip)) {					//Increment number?
				playSFX(1, 'O', 'R', 'X', 255);	
				
				switch (whichSelection) {
					case 1:		
						if (DoorOpen < DoorOpenDefault + 10) {
							DoorOpen += 1;							
						}
						DoorLocation = DoorOpen;
						myservo[DoorServo].write(DoorLocation);	
						break;		
					case 2:			
						if (DoorClosed < DoorClosedDefault) {
							DoorClosed += 1;							
						}
						DoorLocation = DoorClosed;
						myservo[DoorServo].write(DoorLocation);							
						break;						
					case 3:		
						if (TargetUp < TargetUpDefault + 30) {
							TargetUp += 1;							
						}		
						TargetLocation = TargetUp;
						myservo[Targets].write(TargetLocation);							
						break;		
					case 4:		
						if (TargetDown < TargetDownDefault) {
							TargetDown += 1;							
						}		
						TargetLocation = TargetDown;
						myservo[Targets].write(TargetLocation);							
						break;		
					case 5:		
						if (hellUp < hellUpDefault) {
							hellUp += 1;							
						}	
						HellLocation = hellUp;
						myservo[HellServo].write(HellLocation);							
						break;	
					case 6:		
						if (hellDown < hellDownDefault + 10) {
							hellDown += 1;							
						}		
						HellLocation = hellDown;
						myservo[HellServo].write(HellLocation);							
						break;							
				}
				
				menuDisplay();
			}		
			if (cabSwitch(LFlip)) {						//Decrement number?
				playSFX(1, 'O', 'R', 'W', 255);	
				
				switch (whichSelection) {
					case 1:		
						if (DoorOpen > DoorOpenDefault) {
							DoorOpen -= 1;							
						}
						DoorLocation = DoorOpen;
						myservo[DoorServo].write(DoorLocation);							
						break;		
					case 2:			
						if (DoorClosed > DoorClosedDefault - 10) {
							DoorClosed -= 1;							
						}
						DoorLocation = DoorClosed;
						myservo[DoorServo].write(DoorLocation);							
						break;						
					case 3:		
						if (TargetUp > TargetUpDefault) {
							TargetUp -= 1;							
						}
						TargetLocation = TargetUp;
						myservo[Targets].write(TargetLocation);								
						break;		
					case 4:		
						if (TargetDown > TargetDownDefault - 30) {
							TargetDown -= 1;							
						}	
						TargetLocation = TargetDown;
						myservo[Targets].write(TargetLocation);							
						break;		
					case 5:		
						if (hellUp > hellUpDefault - 10) {
							hellUp -= 1;							
						}	
						HellLocation = hellUp;
						myservo[HellServo].write(HellLocation);							
						break;	
					case 6:		
						if (hellDown > hellDownDefault) {
							hellDown -= 1;							
						}	
						HellLocation = hellDown;
						myservo[HellServo].write(HellLocation);							
						break;							
				}
				
				menuDisplay();			
			}					
		}
		else {
			if (cabSwitch(RFlip)) {
				playSFX(1, 'O', 'R', 'X', 255);	
				whichSelection += 1;
				if (whichSelection > 6) {
					whichSelection = 1;
				}				
				menuDisplay();
			}		
			if (cabSwitch(LFlip)) {
				playSFX(1, 'O', 'R', 'W', 255);	
				whichSelection -= 1;
				if (whichSelection < 1) {
					whichSelection = 6;
				}
				menuDisplay();			
			}						
		}
	
		if (cabSwitch(Enter) or cabSwitch(Start)) {	
			playSFX(1, 'O', 'R', 'Y', 255);
			settingsState += 1;						//Toggle state of what the flippers do			
			if (settingsState > 1) {
				settingsState = 0;				
			}
			menuDisplay();
		}		
		if (cabSwitch(Menu)) {		//Abort menu?
			playSFX(1, 'O', 'R', 'Z', 255);	
			if (settingsState == 1) {				//If you're changing a servo value, MENU bounces you back like ENTER would
				settingsState = 0;
				menuDisplay();
			}
			else {									//Else, MENU bounces you back to main menu, as normal
				saveSettings(1);							//Save what we changed to EEPROM			
				whichSelection = 255;					//Jump out				
				
			}
		}				
	}
	
	whichSelection = 5;							//So the upper level menu won't abort out
		
}

void lampMenu() {								//Menu for testing insert lights	

	whichMenu = 7;
	whichSelection = 65;
	
	menuDisplay();
	
	while (whichSelection < 255) {
	
		houseKeeping();				//Get switches, lights, etc
		lookForSerial();
		
		if (cabSwitch(RFlip)) {
			playSFX(1, 'O', 'R', 'X', 255);	
			whichSelection += 1;
			if (whichSelection > 85) {
				whichSelection = 0;
			}
			menuDisplay();
		}		
		if (cabSwitch(LFlip)) {	
			playSFX(1, 'O', 'R', 'W', 255);	
			whichSelection -= 1;
			if (whichSelection < 0) {
				whichSelection = 85;
			}
			menuDisplay();			
		}	
		if (cabSwitch(Menu)) {						//Abort menu?
			playSFX(1, 'O', 'R', 'Z', 255);	
			whichSelection = 255;					//Jump out
		}				
	}
	
	allLamp(0);
	GIbg(0);						//Turn off any GI and lamps you might have left on
	GIpf(0);
	whichSelection = 6;				//So the upper level menu won't abort out

}

void rgbMenu() {								//Menu for testing RGB lighting

	whichMenu = 8;
	whichSelection = 0;
	
	menuDisplay();
	
	while (whichSelection < 255) {
	
		houseKeeping();				//Get switches, lights, etc
		lookForSerial();
		
		if (cabSwitch(RFlip)) {
			playSFX(1, 'O', 'R', 'X', 255);	
			whichSelection += 1;
			if (whichSelection > 9) {
				whichSelection = 0;
			}
			menuDisplay();
		}		
		if (cabSwitch(LFlip)) {
			playSFX(1, 'O', 'R', 'W', 255);	
			whichSelection -= 1;
			if (whichSelection < 0) {
				whichSelection = 9;
			}
			menuDisplay();			
		}			
		if (cabSwitch(Enter) or cabSwitch(Start)) {	
			playSFX(1, 'O', 'R', 'Y', 255);	
			switch (whichSelection) {												//What to show, and where to go
				case 9:						
					if (rgbType) {
						rgbType = 0;
					}
					else {
						rgbType = 1;
					}
					break;										
			}		
			menuDisplay();				
		}		
			
		if (cabSwitch(Menu)) {						//Abort menu?
			playSFX(1, 'O', 'R', 'Z', 255);
			saveSettings(1);							//Save what we changed to EEPROM			
			whichSelection = 255;					//Jump out
		}				
	}
	
	leftRGB[0] = 0;							//Send out Red data
	leftRGB[1] = 0;							//Send out Green data		
	leftRGB[2] = 0;							//Send out Blue data	

	rightRGB[0] = 0;						//Send out Red data
	rightRGB[1] = 0;						//Send out Green data		
	rightRGB[2] = 0;						//Send out Blue data	
	
	ghostRGB[0] = 0;						//Send out Red data
	ghostRGB[1] = 0;						//Send out Green data		
	ghostRGB[2] = 0;						//Send out Blue data	
	doRGB();
	
	whichSelection = 7;				//So the upper level menu won't abort out

}

void coilMenu() {								//Menu for changing game settings

	whichMenu = 9;
	whichSelection = 0;
	
	menuDisplay();
	
	while (whichSelection < 255) {
	
		houseKeeping();				//Get switches, lights, etc
		lookForSerial();
		
		if (cabSwitch(RFlip)) {
			playSFX(1, 'O', 'R', 'X', 255);	
			whichSelection += 1;
			if (whichSelection > 8) {
				whichSelection = 0;
			}
			menuDisplay();
		}		
		if (cabSwitch(LFlip)) {
			playSFX(1, 'O', 'R', 'W', 255);	
			whichSelection -= 1;
			if (whichSelection < 0) {
				whichSelection = 8;
			}
			menuDisplay();			
		}
		if (cabSwitch(Enter) or cabSwitch(Start)) {
			playSFX(1, 'O', 'R', 'Y', 255);	
			if (whichSelection < 8) {
				coilSettings[whichSelection] += 1;
				if (coilSettings[whichSelection] > 9) {
					coilSettings[whichSelection] = 0;
				}
			}
			if (whichSelection == 8) {				//Reset defaults?
				for (int x = 0 ; x < 8 ; x++) {		//Copy coil defaults
					coilSettings[x] = coilDefaults[x];	
				}
			}						
			menuDisplay();							//Show what we changed				
		}		
		if (cabSwitch(Menu)) {						//Abort menu?
			playSFX(1, 'O', 'R', 'Z', 255);	
			saveSettings(1);							//Save what we changed to EEPROM
			calculateCoils();						//Set the actual coil timings based off our 0-9 numbers (normally this only occurs on boot so we need to do it here)
			Update(0);								//Update the game on anything we changed (freeplay, etc)
			whichSelection = 255;					//Jump out
		}				
	}
	
	whichSelection = 8;				//Where we were in the upper level menu

}

void mainSettingsMenu() {						//Menu for changing game settings

	whichMenu = 10;
	whichSelection = 0;
	
	menuDisplay();
	
	while (whichSelection < 255) {
	
		houseKeeping();				//Get switches, lights, etc
		lookForSerial();
		
		if (cabSwitch(RFlip)) {
			playSFX(1, 'O', 'R', 'X', 255);	
			whichSelection += 1;
			if (whichSelection > 14) {
				whichSelection = 0;
			}
			menuDisplay();
		}		
		if (cabSwitch(LFlip)) {
			playSFX(1, 'O', 'R', 'W', 255);	
			whichSelection -= 1;
			if (whichSelection < 0) {
				whichSelection = 14;
			}
			menuDisplay();			
		}
		if (cabSwitch(Enter) or cabSwitch(Start)) {
			playSFX(1, 'O', 'R', 'Y', 255);	
			switch (whichSelection) {
				case 0:
					if (freePlay) {
						freePlay = 0;
					}
					else {
						freePlay = 1;
					}					
					break;				
				case 1:		
					pulsesPerCoin += 1;
					if (pulsesPerCoin > 10) {
						pulsesPerCoin = 1;
					}
					break;	
				case 2:		
					pulsesPerCredit += 1;
					if (pulsesPerCredit > 20) {
						pulsesPerCredit = 1;
					}
					break;	
				case 3:		
					ballsPerGame += 1;
					if (ballsPerGame > 6) {
						ballsPerGame = 2;
					}
					break;	
				case 4:		
					tiltLimit += 1;
					if (tiltLimit > 10) {
						tiltLimit = 1;
					}				
					break;
				case 5:		
					tiltTenths += 1;
					if (tiltTenths > 15) {
						tiltTenths = 5;
					}
          cabDBTime[8] = tiltTenths * 1200;               //Set the debounce
					break;	          
				case 6:		
					videoSpeedStart -= 1;
					if (videoSpeedStart < 3) {
						videoSpeedStart = 5;
					}										
					break;		          
				case 7:			
					sfxDefault += 5;
					if (sfxDefault > 35) {
						sfxDefault = 0;
					}									
					break;						
				case 8:		
					musicDefault += 5;
					if (musicDefault > 35) {
						musicDefault = 0;
					}							
					break;		
				case 9:		
					if (coinDoorDetect) {
						coinDoorDetect = 0;
					}
					else {
						coinDoorDetect = 1;
					}					
					break;
				case 10:		
				
					if (cabinet & (1 << LFlip)) {		//Secret button press I'll forget to remove
						setDefaultScoresTest();			//Set the default scores on the EEPROM
					}
					else {
						setDefaultScores();			//Set the default scores on the EEPROM
					}
          
					loadHighScores();			//Load them back into memory
					for (int x = 0 ; x < 5 ; x++) {			//Then send them to the A/V kernel
						sendHighScores(x);	
					}
					
					/*					
					for (int x = 0 ; x < 5 ; x++) {
						getHighScore(x);					//Retrieve each of the 5 high scores and put them into RAM	
					}
					*/
					break;	
				case 11:		
					deadTopSeconds += 1;
					if (deadTopSeconds > 20) {
						deadTopSeconds = 5;
					}							
					break;	
				case 12:		
					searchTimer -= 500;
					if (searchTimer < 2000) {
						searchTimer = 6000;
					}							
					break;	
        case 13:
          defaultSettings();
          break;
        case 14:
          creditDot = 0;
          saveCreditDot();        //Update the EEPROM. Note, system could still decide there should be a credit dot and add one back in later
          Update(0);              //Update the display
          break;
          
			}	
			menuDisplay();							//Show what we changed				
		}		
		if (cabSwitch(Menu)) {						//Abort menu?
			playSFX(1, 'O', 'R', 'Z', 255);	
			saveSettings(1);							//Save what we changed to EEPROM
			Update(0);								//Update the game on anything we changed (freeplay, etc)
			whichSelection = 255;					//Jump out
		}				
	}
	
	whichSelection = 9;				//So the upper level menu won't abort out

}

void gameSettingsMenu() {						//Menu for changing game settings

	whichMenu = 11;
	whichSelection = 0;
	
	menuDisplay();
	
	while (whichSelection < 255) {
	
		houseKeeping();				//Get switches, lights, etc
		lookForSerial();
		
		if (cabSwitch(RFlip)) {
			playSFX(1, 'O', 'R', 'X', 255);	
			whichSelection += 1;
			if (whichSelection > 18) {
				whichSelection = 0;
			}
			menuDisplay();
		}		
		if (cabSwitch(LFlip)) {
			playSFX(1, 'O', 'R', 'W', 255);	
			whichSelection -= 1;
			if (whichSelection < 0) {
				whichSelection = 18;
			}
			menuDisplay();			
		}
		if (cabSwitch(Enter) or cabSwitch(Start)) {
			playSFX(1, 'O', 'R', 'Y', 255);	
			switch (whichSelection) {	
				case 0:
					allowExtraBalls += 1;
					if (allowExtraBalls > 4) {
						allowExtraBalls = 0;
					}				
					break;	
				case 1:		
					spotProgress += 4;
					if (spotProgress > 12) {
						spotProgress = 0;
					}					
					break;	
				case 2:		
					saveStart += 1;
					if (saveStart > 20) {
						saveStart = 1;
					}									
					break;			
				case 3:
					replayValue += 20000000;
					if (replayValue > 950000000) {
						replayValue = 10000000;
					}									
					break;
				case 4:		
					if (allowReplay) {
						allowReplay = 0;
					}
					else {
						allowReplay = 1;
					}						
					break;	
				case 5:		
					if (allowMatch) {
						allowMatch = 0;
					}
					else {
						allowMatch = 1;
					}					
					break;
				case 6:		
					if (tournament) {
						tournament = 0;
						allowExtraBalls = 1;		//Other default stuff
						allowMatch = 1;
						allowReplay = 1;
						videoModeEnable = 1;
						zeroPointBall = 1;
						saveStart = 5;
					}
					else {
						tournament = 1;
						allowExtraBalls = 0;
						allowMatch = 0;
						allowReplay = 0;
						videoModeEnable = 0;
						zeroPointBall = 0;
						saveStart = 1;				//One second might as well be zero!
					}					
					break;	
				case 7:
					EVP_EBsetting += 2;
					if (EVP_EBsetting > 30) {
						EVP_EBsetting = 4;
					}									
					break;	
				case 8:
					comboSeconds += 1;
					if (comboSeconds > 15) {
						comboSeconds = 3;
					}									
					break;	
				case 9:		
					if (videoModeEnable) {
						videoModeEnable = 0;
					}
					else {
						videoModeEnable = 1;
					}					
					break;		
				case 10:		
					if (zeroPointBall) {
						zeroPointBall = 0;
					}
					else {
						zeroPointBall = 1;
					}					
					break;	
				case 11:		
					scoopSaveStart += 250;
					if (scoopSaveStart > 5010) {	//5 seconds is INSANE but whatever.
						scoopSaveStart = 10;			//Lowest it can go is 10. We don't use ZERO else we can't detect an unwritten value in EEPROM
					}									
					break;		
				case 12:
          if (scoopSaveWhen) {
            scoopSaveWhen = 0;
          }
          else {
            scoopSaveWhen = 1;
          }       
        case 13:		
					if (flipperAttract) {
						flipperAttract = 0;
					}
					else {
						flipperAttract = 1;
					}						
					break;
        case 14:
          middleWarBar += 4;
          if (middleWarBar > 8) {
            middleWarBar = 0;
          }         
				case 15:		
					orbSlings += 5;
          if (orbSlings > 100) {
            orbSlings = 20;            
          }
					break;
				case 16:		
					magEnglish += 1;
          if (magEnglish > 3) {
            magEnglish = 0;            
          }
					break;	 
				case 17:		
					winMusic += 1;
          if (winMusic > 5) {
            winMusic = 1;            
          }
					break;
        case 18:
          if (ghostBurstCallout) {
            ghostBurstCallout = 0;
          }
          else {
            ghostBurstCallout = 1;
          } 
          break;
			}	
			menuDisplay();							//Show what we changed				
		}		
		if (cabSwitch(Menu)) {						//Abort menu?
			playSFX(1, 'O', 'R', 'Z', 255);	
			saveSettings(1);							//Save what we changed to EEPROM
			Update(0);								    //Update the game on anything we changed (freeplay, etc)
			whichSelection = 255;					//Jump out
		}				
	}
	
	whichSelection = 10;				//So the upper level menu won't abort out

}

void auditMenu() {								//Menu for changing game settings

	whichMenu = 12;
	whichSelection = 1;
	
	dollarsAndCents();
	
	menuDisplay();
	
	while (whichSelection < 255) {
	
		houseKeeping();				//Get switches, lights, etc
		lookForSerial();
		
		if (cabSwitch(RFlip)) {
			playSFX(1, 'O', 'R', 'X', 255);	
			whichSelection += 1;
			if (whichSelection > 7) {
				whichSelection = 0;
			}
			menuDisplay();
		}		
		if (cabSwitch(LFlip)) {
			playSFX(1, 'O', 'R', 'W', 255);	
			whichSelection -= 1;
			if (whichSelection < 0) {
				whichSelection = 7;
			}
			menuDisplay();			
		}
		if (cabSwitch(Enter) or cabSwitch(Start)) {
			playSFX(1, 'O', 'R', 'Y', 255);	
			switch (whichSelection) {	
				case 0:								//Only choice here is if you want to CLEAR AUDITS
					clearAudits();
					dollarsAndCents();				//Recalculate display value
					break;					
			}	
			menuDisplay();							//Show what we changed				
		}		
		if (cabSwitch(Menu)) {						//Abort menu?
			playSFX(1, 'O', 'R', 'Z', 255);	
			saveAudits();
			Update(0);								//Update the game on anything we changed (freeplay, etc)
			whichSelection = 255;					//Jump out
		}				
	}
	
	whichSelection = 11;				//So the upper level menu won't abort out

}

void dollarsAndCents() {						//Converts # of coins inserted to decimal dollar value

	if (coinsInserted) {
		dollars = coinsInserted / 4;				//Get dollars. Rounds to 4
		cents = coinsInserted - (dollars * 4);		//Get cents in 25 cent increments		
	}
	else {
		dollars = 0;
		cents = 0;
	}

}

void menuDisplay() {							//This function actually draws the menus

	switch(whichMenu) {
	
		case 1: //Main Root Menu
	
			graphicsMode(10, clearScreen);
			//text(2, 0, "-MAIN--MENU-");
			text(1, 0, "MAIN MENU V");			
			value(12, 0, versionNumber);			
			switch (whichSelection) {
				case 1:
					text(0, 1, "TEST:");			
					text(0, 2, "SWITCH EDGE");				
					break;		
				case 2:
					text(0, 1, "TEST:");			
					text(0, 2, "AUDIO/MUSIC");				
					break;						
				case 3:
					text(0, 1, "TEST:");			
					text(0, 2, "SOLENOID");				
					break;		
				case 4:
					text(0, 1, "TEST:");			
					text(0, 2, "SERVO");				
					break;	
				case 5:
					text(0, 1, "CHANGE:");			
					text(0, 2, "SERVO DEFAULT");				
					break;						
				case 6:
					text(0, 1, "TEST:");			
					text(0, 2, "LAMP");				
					break;	
				case 7:
					text(0, 1, "TEST:");			
					text(0, 2, "RGB LIGHTING");				
					break;	
				case 8:
					text(0, 1, "CHANGE:");	
					text(0, 2, "COIL SETTINGS");						
					break;
				case 9:
					text(0, 1, "CHANGE:");	
					text(0, 2, "MAIN SETTINGS");						
					break;
				case 10:
					text(0, 1, "CHANGE:");	
					text(0, 2, "GAME SETTINGS");						
					break;
				case 11:
					text(0, 1, "VIEW:");	
					text(0, 2, "GAME AUDITS");						
					break;						
			}
			text(2, 3, "<L ^EXIT^ R>");
			graphicsMode(10, loadScreen);
			break;
			
		case 2: //Switch Edge Menu
	
			graphicsMode(10, clearScreen);
			loadSprite('Z', 'W', 'M', 0);
			text(5, 0, "SWITCH TEST");	
			
			if (audioSwitch) {
				text(5, 3, "AUDIO: ON");
			}
			else {
				text(5, 3, "AUDIO: OFF");
			}	

			for (int xD = 0 ; xD < 59 ; xD++) {						//Text description of all switches except ball trough		
				if (Switch(xD)) {
					text(5, 1, "SWITCH#");
					value(13, 1, xD);
					if (audioSwitch) {								//Speak the switch #?					
						tens = xD / 10;								//Find tens
						ones = xD - (tens * 10);					//Find ones
						playSFX(0, 'X', '0' + tens, 'A', 255);		//Speak tens
						playSFXQ(0, 'X', 'B', '0' + ones, 255);		//Speaks ones
					}
				}						
			}
			
			switch (cabinet & 0xFFFE) {		//Exclude bit 0, which is always on for some reason
				case 1 << Door:
					text(5, 2, "DOOR CLOSE");				
					break;
				case 1 << User0:
					text(5, 2, "USER0");
					if (audioSwitch) {								//Speak the switch #?	
						playSFX(0, 'X', 'C', '0', 255);					//Speak the switch
					}					
					break;
				case 1 << RFlip:
					text(5, 2, "RFLIP");
					if (audioSwitch) {								//Speak the switch #?	
						playSFX(0, 'X', 'C', '1', 255);					//Speak the switch	
					}
					break;	
				case 1 << LFlip:
					text(5, 2, "LFLIP");
					if (audioSwitch) {								//Speak the switch #?	
						playSFX(0, 'X', 'C', '2', 255);					//Speak the switch	
					}					
					break;										
				case 1 << Coin:
					text(5, 2, "COIN");
					if (audioSwitch) {								//Speak the switch #?	
						playSFX(0, 'X', 'C', '5', 255);					//Speak the switch	
					}							
					break;	
				case 1 << Tilt:
					text(5, 2, "TILT");
					if (audioSwitch) {								//Speak the switch #?	
						playSFX(0, 'X', 'C', '6', 255);					//Speak the switch	
					}						
					break;													
				case 1 << Start:
					text(5, 2, "START");
					if (audioSwitch) {								//Speak the switch #?	
						playSFX(0, 'X', 'C', '7', 255);					//Speak the switch	
					}									
					break;		
				case 1 << ghostOpto:
					text(5, 2, "LOOP");
					if (audioSwitch) {								//Speak the switch #?	
						playSFX(0, 'X', 'C', '8', 255);					//Speak the switch	
					}					
					break;	
				case 1 << doorOpto:
					text(5, 2, "DOOR");
					if (audioSwitch) {								//Speak the switch #?	
						playSFX(0, 'X', 'C', '9', 255);					//Speak the switch						
					}					
					break;					
			}				
										
			sendSwitches();			
			graphicsMode(10, loadScreen);
			break;		

		case 3: //Audio test Menu
	
			graphicsMode(10, clearScreen);
			text(0, 0, ">AUDIO TEST");			
			switch (whichSelection) {
				case 1:
					text(0, 1, "CHANNEL 1");						
					break;		
				case 2:
					text(0, 1, "CHANNEL 2");							
					break;	
				case 3:
					text(0, 1, "BOTH CHANNELS");						
					break;													
				case 4:
					text(0, 1, "MUSIC START");						
					break;		
				case 5:
					text(0, 1, "MUSIC STOP");							
					break;	
				case 6:
					text(0, 1, "MUSIC FADE");							
					break;						
			}
			text(0, 2, "ENTER TO TEST");				
			text(2, 3, "<L ^MENU^ R>");			
			graphicsMode(10, loadScreen);
			break;	
			
		case 4: //Solenoid Menu	
			graphicsMode(10, clearScreen);
			text(0, 0, ">SOLENOID TEST");		
			switch (whichSelection) {
				case 0:		
					text(0, 1, "LOOP MAGNET");				
					break;	
				case 1:		
					text(0, 1, "UNUSED");				
					break;	
				case 2:		
					text(0, 1, "UNUSED");			
					break;	
				case 3:		
					text(0, 1, "UNUSED");			
					break;	
				case 4:		
					text(0, 1, "UNUSED");				
					break;	
				case 5:		
					text(0, 1, "UNUSED");				
					break;	
				case 6:		
					text(0, 1, "PROTO BG 1");				
					break;	
				case 7:		
					text(0, 1, "PROTO BG 1");				
					break;						
				case 8:			
					text(0, 1, "LSLING");				
					break;						
				case 9:		
					text(0, 1, "RSLING");				
					break;		
				case 10:		
					text(0, 1, "SCOOPKICK");				
					break;	
				case 11:		
					text(0, 1, "VUK");				
					break;		
				case 12:		
					text(0, 1, "UNUSED");				
					break;	
				case 13:		
					text(0, 1, "POP BUMP 0");				
					break;		
				case 14:		
					text(0, 1, "POP BUMP 1");				
					break;
				case 15:		
					text(0, 1, "POP BUMP 2");				
					break;							
				case 16:		
					text(0, 1, "RFLIP HIGH");				
					break;		
				case 17:		
					text(0, 1, "RFLIP HOLD");				
					break;	
				case 18:		
					text(0, 1, "LFLIP HIGH");				
					break;		
				case 19:		
					text(0, 1, "LFLIP HOLD");				
					break;	
				case 20:		
					text(0, 1, "BALL LOAD");				
					break;		
				case 21:		
					text(0, 1, "DRAIN KICK");				
					break;
				case 22:		
					text(0, 1, "AUTOPLUNGER");				
					break;
				case 23:		
					text(0, 1, "UNUSED");				
					break;						
			}
			text(0, 2, "ENTER TO TEST");
			text(2, 3, "<L ^MENU^ R>");
			graphicsMode(10, loadScreen);	
			break;
			
		case 5:	//Servo menu display	
			graphicsMode(10, clearScreen);
			text(0, 0, ">SERVO TEST");		
			switch (whichSelection) {
				case 1:		
					text(0, 1, "DOOR OPEN");				
					break;		
				case 2:			
					text(0, 1, "DOOR CLOSE");				
					break;						
				case 3:		
					text(0, 1, "TARGET UP");				
					break;		
				case 4:		
					text(0, 1, "TARGET DOWN");				
					break;	
				case 5:		
					text(0, 1, "GHOST LEFT");				
					break;		
				case 6:		
					text(0, 1, "GHOST MIDDLE");				
					break;	
				case 7:		
					text(0, 1, "GHOST RIGHT");				
					break;		
				case 8:		
					text(0, 1, "HELL UP");				
					break;	
				case 9:		
					text(0, 1, "HELL DOWN");				
					break;							
			}
			text(0, 2, "ENTER TO SET");
			text(2, 3, "<L ^MENU^ R>");
			graphicsMode(10, loadScreen);	
			break;


// unsigned char TargetDown = TargetDownDefault;				//Set these to defaults on load
// unsigned char TargetUp = TargetUpDefault;
// unsigned char hellUp =  hellUpDefault;
// unsigned char hellDown = hellDownDefault;
// unsigned char DoorOpen = DoorOpenDefault;
// unsigned char DoorClosed = DoorClosedDefault;			
			
		case 6:	//Servo Settings menu display	
			graphicsMode(10, clearScreen);
			text(0, 0, ">SERVO DEFAULTS");		
			switch (whichSelection) {
				case 1:		
					text(0, 1, "DOOR OPEN=");
					value(13, 1, DoorOpen);
					break;		
				case 2:			
					text(0, 1, "DOOR CLOSE=");
					value(13, 1, DoorClosed);
					break;						
				case 3:		
					text(0, 1, "TARGET UP=");
					value(13, 1, TargetUp);					
					break;		
				case 4:		
					text(0, 1, "TARGET DOWN=");
					value(13, 1, TargetDown);					
					break;		
				case 5:		
					text(0, 1, "HELL UP=");	
					value(13, 1, hellUp);					
					break;	
				case 6:		
					text(0, 1, "HELL DOWN=");
					value(13, 1, hellDown);					
					break;							
			}					
			if (settingsState == 0) {
				text(0, 2, "SELECT A");
				text(9, 2, "SERVO");
				text(2, 3, "<L ^MENU^ R>");					
			}
			else {
				text(0, 2, "ENTER");
				text(6, 2, "WHEN DONE");
				text(2, 3, "-L CHANGE R+");					
			}			
			graphicsMode(10, loadScreen);	
			break;
			
		case 7: //Lamp Menu	
			graphicsMode(10, clearScreen);
			text(0, 0, ">LAMP TEST");
			if (whichSelection > 65 and whichSelection < 74) {			//Testing Playfield GI?
				text(0, 1, "PLAYFIELD GI");
				text(0, 2, "#");
				value(1, 2, whichSelection - 66);
				GIpf(1 << (whichSelection - 66));						//Set the bit to enable
				GIbg(0);
			}
			if (whichSelection > 73 and whichSelection < 82) {			//Testing BackBox GI?
				text(0, 1, "BACKBOX GI");
				text(0, 2, "#");
				value(1, 2, whichSelection - 74);
				GIbg(1 << (whichSelection - 74));						//Set the bit to enable
				GIpf(0);
			}			
			
			if (whichSelection == 64) {
				text(0, 1, "ALL LAMPS ON");
				allLamp(7);
				GIpf(0x00);
				GIbg(0x00);				
			}
			if (whichSelection == 65) {
				text(0, 1, "ALL LAMPS OFF");
				allLamp(0);
				GIpf(0x00);
				GIbg(0x00);						
			}			
			if (whichSelection < 64) {				
				text(0, 1, "LAMP #");
				value(7, 1, whichSelection);
				allLamp(0);
				light(whichSelection, 7);
				GIpf(0x00);
				GIbg(0x00);		
			}
			if (whichSelection == 82) {
				text(0, 1, "ALL PLAYFIELD");
				text(0, 2, "GI ON");
				GIpf(0xFF);
				GIbg(0x00);
			}				
			if (whichSelection == 83) {
				text(0, 1, "ALL BACKBOX");
				text(0, 2, "GI ON");
				GIpf(0x00);
				GIbg(0xFF);
				allLamp(0);
			}		
			if (whichSelection == 84) {
				text(0, 1, "GI AND LAMPS");
				text(0, 2, "ALL ON");
				GIpf(0xFF);
				GIbg(0xFF);
				allLamp(7);
			}			
			if (whichSelection == 85) {
				text(0, 1, "GI AND LAMPS");
				text(0, 2, "ALL OFF");
				GIpf(0x00);
				GIbg(0x00);
				allLamp(0);
			}			
			text(2, 3, "<L ^MENU^ R>");			
			graphicsMode(10, loadScreen);	
			break;	

		case 8:	//RGB Test	
			graphicsMode(10, clearScreen);
			text(0, 0, ">RGB TEST");
			leftRGB[0] = 0;							//Send out Red data
			leftRGB[1] = 0;							//Send out Green data		
			leftRGB[2] = 0;							//Send out Blue data	

			rightRGB[0] = 0;						//Send out Red data
			rightRGB[1] = 0;						//Send out Green data		
			rightRGB[2] = 0;						//Send out Blue data	
			
			ghostRGB[0] = 0;						//Send out Red data			
			ghostRGB[1] = 0;						//Send out Green data	
			ghostRGB[2] = 0;						//Send out Blue data					
		
			switch (whichSelection) {
				case 0:		
					text(0, 1, "GHOST=RED");
					ghostRGB[0] = 255;		
					break;				
				case 1:		
					text(0, 1, "GHOST=GREEN");
					ghostRGB[1] = 255;
					break;		
				case 2:			
					text(0, 1, "GHOST=BLUE");
					ghostRGB[2] = 255;					
					break;						
				case 3:		
					text(0, 1, "RGB1=RED");				
					leftRGB[0] = 255;
					break;		
				case 4:		
					text(0, 1, "RGB1=GREEN");
					leftRGB[1] = 255;					
					break;	
				case 5:		
					text(0, 1, "RGB1=BLUE");
					leftRGB[2] = 255;					
					break;		
				case 6:		
					text(0, 1, "RGB2=RED");
					rightRGB[0] = 255;						
					break;	
				case 7:		
					text(0, 1, "RGB2=GREEN");
					rightRGB[1] = 255;						
					break;		
				case 8:		
					text(0, 1, "RGB2=BLUE");
					rightRGB[2] = 255;						
					break;
				case 9:		
					ghostRGB[2] = 255;				//Set ghost blue to check
					text(0, 1, "GHOST TYPE");						
					if (rgbType) {
						text(0, 2, "REV 2");	//New RGB LED source (Green and blue swapped)						
					}
					else {
						text(0, 2, "REV 1");	//Old LED source (Red, Green, Blue)						
					}					
					break;														
			}
			doRGB();
			
			if (whichSelection == 9) {			//Standard message for RGB test
				text(2, 3, "<- CHANGE ->");	//This option says CHANGE so you know to click ENTER to change the Ghost Rev setting							
			}
			else {
				text(2, 3, "<L ^MENU^ R>");									
			}
			graphicsMode(10, loadScreen);	
			break;
			
		case 9: //Coil Menu	
			graphicsMode(10, clearScreen);
			text(0, 0, ">COIL SETTING");
			text(4, 2, "MIN:0 MAX:9");			
			switch (whichSelection) {
				case 0:		
					text(0, 1, "FLIPPERS");
					text(0, 2, "< >");
					value(1, 2, coilSettings[0]);
					break;
				case 1:		
					text(0, 1, "SLINGS");
					text(0, 2, "< >");
					value(1, 2, coilSettings[1]);
					break;					
				case 2:		
					text(0, 1, "POP BUMPERS");
					text(0, 2, "< >");
					value(1, 2, coilSettings[2]);
					break;	
				case 3:		
					text(0, 1, "LEFT VUK");
					text(0, 2, "< >");
					value(1, 2, coilSettings[3]);
					break;	
				case 4:		
					text(0, 1, "RIGHT SCOOP");
					text(0, 2, "< >");
					value(1, 2, coilSettings[4]);
					break;	
				case 5:		
					text(0, 1, "AUTOLAUNCHER");
					text(0, 2, "< >");
					value(1, 2, coilSettings[5]);
					break;	
				case 6:			
					text(0, 1, "BALL LOADER");
					text(0, 2, "< >");
					value(1, 2, coilSettings[6]);
					break;	
				case 7:		
					text(0, 1, "DRAIN KICK");
					text(0, 2, "< >");
					value(1, 2, coilSettings[7]);
					break;	
				case 8:			
					text(9, 2, "     ");					
					text(0, 1, "LOAD");
					text(0, 2, "DEFAULTS?");
					text(14, 2, "  ");	//To erase the "9" from other screens					
					break;			
			}
			text(2, 3, "<- CHANGE ->");
			graphicsMode(10, loadScreen);	
			break;
			
		case 10: //Settings Menu	
			graphicsMode(10, clearScreen);
			text(0, 0, ">MAIN SETTINGS");		
			switch (whichSelection) {		
				case 0:		
					text(0, 1, "FREE PLAY");
					if (freePlay) {
						text(0, 2, "YES");
					}
					else {
						text(0, 2, "NO");
					}				
					break;	          
				case 1:		
					text(0, 1, "PULSES/COIN");	
					value(0, 2, pulsesPerCoin);
					break;	
				case 2:		
					text(0, 1, "PULSES/CREDIT");	
					value(0, 2, pulsesPerCredit);
					break;	
				case 3:		
					text(0, 1, "BALLS/GAME");
					value(0, 2, ballsPerGame - 1);
					break;		
				case 4:		
					text(0, 1, "TILT WARNINGS");
					text(value(0, 2, tiltLimit - 1) + 1, 2, "BEFORE TILT");						
					break;	
				case 5:		
					text(0, 1, "WARNING DELAY");
          if (tiltTenths < 10) {
            text(0, 2, "0.");
            value(2, 2, tiltTenths);
            text(4, 2, "SECONDS ");           
          }
          else {
            value(0, 2, tiltTenths / 10);
            text(1, 2, ".");
            value(2, 2, tiltTenths - ((tiltTenths / 10) * 10));
            text(4, 2, "SECONDS ");              
          }					
					break;	                   
				case 6:		
					text(0, 1, "VIDEO MODE");
					text(value(0, 2, 6 - videoSpeedStart) + 1, 2, "START SPEED");				
					break;						
				case 7:			
					text(0, 1, "SFX VOLUME");
					text(value(0, 2, sfxDefault), 2, "/35");					
					break;						
				case 8:		
					text(0, 1, "MUSIC VOLUME");					
					text(value(0, 2, musicDefault), 2, "/35");							
					break;							
				case 9:		
					text(0, 1, "DOOR WARNING");
					if (coinDoorDetect) {
						text(0, 2, "YES");
					}
					else {
						text(0, 2, "NO");
					}
					break;
				case 10:		
					text(0, 1, "RESET");
					text(0, 2, "HIGH SCORES?");							
					break;
				case 11:		
					text(0, 1, "BALL SEARCH");
					text(0, 2, "AFTER");
					text(value(6, 2, deadTopSeconds) + 7, 2, "SECONDS");				
					break;						
				case 12:			
					text(0, 1, "BALL SEARCH");
					text(value(0, 2, 4000 - (searchTimer - 2000)) + 1, 2, "INTENSITY");				
					break;	
 				case 13:		
					text(0, 1, "SET FACTORY");
					text(0, 2, "DEFAULTS?");					
					break;	  
 				case 14:		
					text(0, 1, "CLEAR CREDIT");
					text(0, 2, "DOT?");					
					break;	           
			}
			text(2, 3, "<- CHANGE ->");
			graphicsMode(10, loadScreen);	
			break;	

		case 11: //Gameplay Menu	
			graphicsMode(10, clearScreen);
			text(0, 0, ">GAME SETTINGS");		
			switch (whichSelection) {
				case 0:		
					text(0, 1, "EXTRA BALLS");
					switch(allowExtraBalls) {
						case 0:
							text(0, 2, "NO");
							break;
						case 1:
							text(0, 2, "YES");
							break;
						case 2:
							text(0, 2, "AWARD 100K");
							break;
						case 3:
							text(0, 2, "AWARD 500K");
							break;
						case 4:
							text(0, 2, "AWARD 1MIL");
							break;							
					}				
					break;	
				case 1:		
					text(0, 1, "SPOT POPS");
					text(value(0, 2, spotProgress) + 1, 2, "TO START");					
					break;	
				case 2:		
					text(0, 1, "BALL SAVE");        
					text(value(0, 2, saveStart) + 1, 2, "SECONDS");			
					break;			
				case 3:		
					text(0, 1, "REPLAY VALUE");
					text(value(0, 2, replayValue / 1000000) + 1, 2, "MILLION");					
					break;
				case 4:		
					text(0, 1, "ALLOW REPLAY");
					if (allowReplay) {
						text(0, 2, "YES");
					}
					else {
						text(0, 2, "NO");
					}
					break;
				case 5:		
					text(0, 1, "ALLOW MATCH");
					if (allowMatch) {
						text(0, 2, "YES");
					}
					else {
						text(0, 2, "NO");
					}
					break;
				case 6:		
					text(0, 1, "TOURNAMENT");
					if (tournament) {
						text(0, 2, "YES");
					}
					else {
						text(0, 2, "NO");
					}
					break;
				case 7:		
					text(0, 1, "EXTRA BALL AT");
					text(value(0, 2, EVP_EBsetting) + 1, 2, "EVPS");	
					break;	
				case 8:		
					text(0, 1, "COMBO TIMER");
					text(value(0, 2, comboSeconds) + 1, 2, "SECONDS");	
					break;	
				case 9:		
					text(0, 1, "VIDEO MODE");
					if (videoModeEnable) {
						text(0, 2, "YES");
					}
					else {
						text(0, 2, "NO THEY SUCK");
					}
					break;		
				case 10:		
					text(0, 1, "ZERO POINT");
					text(11, 1, "BALL");
					if (zeroPointBall) {
						text(0, 2, "ANOTHER TRY");
					}
					else {
						text(0, 2, "PLAY BETTER");
					}
					break;	
				case 11:		
					text(0, 1, "SCOOP SAVE");
					text(11, 1, "TIME");
					if (scoopSaveStart == 10) {
						text(0, 2, "0 NUDGE");
            text(8, 2, "BETTER");
					}
					else {
						text(value(0, 2, scoopSaveStart - 10) + 1, 2, "MILLISECOND");
					}									
					break;
				case 12:		
					text(0, 1, "SCOOP SAVE");
					text(11, 1, "WHEN?");
					if (scoopSaveWhen == 0) {
						text(0, 2, "ALWAYS");
					}
					else {
						text(0, 2, "NOT IN"); 
            text(7, 2, "MULTIBALL");
					}									
					break;          
				case 13:		
					text(0, 1, "FLIPPER");
					text(8, 1, "ATTRACT");
					if (flipperAttract) {
						text(0, 2, "YES");
					}
					else {
						text(0, 2, "NO");
					}
					break;
 				case 14:		
					text(0, 1, "MIDDLE SHOT");
					if (middleWarBar) {
						text(0, 2, "ADV WAR/BAR");
            value(12, 2, middleWarBar);
					}
					else {
						text(0, 2, "NORMAL USE");
					}
					break;         
				case 15:
          text(0, 1, "SPOT ORB");
					text(9, 1, "LETTER");
          text(value(0, 2, orbSlings) + 1, 2, "SLING HITS");
					break;
				case 16:
          text(0, 1, "MAGNET");
					text(7, 1, "RELEASE");
           switch(magEnglish) {
             case 0:
             text(0, 2, "NORMAL");
             break;
             case 1:
             text(0, 2, "LIGHT TUG");
             break;             
             case 2:
             text(0, 2, "STRONG PUSH");
             break;
             case 3:
             text(0, 2, "SUPER ENGLISH");
             break;                         
           }
					break;
 				case 17:		
					text(0, 1, "MODE WIN MUSIC");
          switch(winMusic) {
            case 1:
              text(0, 2, "MOST HAUNTED");
              break;
            case 2:
              text(0, 2, "GHOST SQUAD");
              break;           
            case 3:
              text(0, 2, "CHUCK RAP");
              break;             
            case 4:
              text(0, 2, "USER: #WD.WAV");
              break;   
            case 5:
              text(0, 2, "USER: #WE.WAV");
              break;                
          }		
          break;
				case 18:
          text(0, 1, "GHOST BURST!");
          if (ghostBurstCallout) {
            text(0, 2, "SFX + VOICE"); 
          }
          else {
            text(0, 2, "SFX ONLY"); 
          }
					break;        
			}
			text(2, 3, "<- CHANGE ->");
			graphicsMode(10, loadScreen);	
			break;	

		case 12: //Display Audits	
			graphicsMode(10, clearScreen);
			text(0, 0, ">DISPLAY AUDITS");		
			switch (whichSelection) {
				case 0:		
					text(0, 1, "PRESS ENTER TO");
					text(0, 2, "CLEAR AUDITS");
					break;	
				case 1:		
					text(0, 1, "EARNINGS");
					text(0, 2, "$");
					cursorPos = value(1, 2, dollars);
					text(cursorPos + 1, 2, ".");
					if (cents) {
						value(cursorPos + 2, 2, 25 * cents);
					}
					else {
						text(cursorPos + 2, 2, "00");
					}
					break;						
				case 2:		
					text(0, 1, "GAMES PLAYED");
					value(0, 2, gamesPlayed);
					break;	
				case 3:		
					text(0, 1, "AV. BALL TIME");
					if (totalBallTime == 0 or ballsPlayed == 0) {	//Don't divide by zero!
						text(0, 2, "NO DATA");	
					}
					else {
						text(value(0, 2, totalBallTime / ballsPlayed) + 1, 2, "SECONDS");
					}					
					break;
				case 4:		
					text(0, 1, "TOTAL TIME");
					if (totalBallTime == 0) {	//Don't divide by zero!
						text(0, 2, "NO DATA");	
					}
					else {
						text(value(0, 2, totalBallTime / 60) + 1, 2, "MINUTES");	
					}													
					break;						
				case 5:		
					text(0, 1, "EXTRA BALLS");
					value(0, 2, extraBallGet);				
					break;			
				case 6:		
					text(0, 1, "REPLAYS");
					value(0, 2, replayGet);				
					break;	
				case 7:		
					text(0, 1, "MATCH SCORE");
					value(0, 2, matchGet);	
					break;
			}
			if (whichSelection) {
				text(2, 3, "<-        ->");
			}
			else {
				text(2, 3, "<- ENTER  ->");
			}			
			graphicsMode(10, loadScreen);	
			break;				
	}
}

void showGameStatus() {							//Press USER0 during a game to see a debug listing of important variables

	Update(0);						//If AV is in attract mode, this'll fix it!

	Serial.print("ballsInGame: ");
	Serial.print(ballsInGame, DEC);
	Serial.print("\tChase Ball: ");
	Serial.print(chaseBall, DEC);			
	Serial.print("\tActive Mode: ");
	Serial.print(Mode[player], DEC);
	Serial.print("\tSwitchDead: ");
	Serial.print(switchDead, DEC);
	Serial.print("\tDeadTop: ");
	Serial.print(deadTop, DEC);			
	Serial.print("\tsaveTimer: ");
	Serial.print(saveTimer, DEC);		
	Serial.print("\tRUN: ");
	Serial.print(run, DEC);		
	Serial.print("\tMultiball: ");
	Serial.print(multiBall, BIN);		
	Serial.print("\tdemonMul: ");
	Serial.print(demonMultiplier[player], DEC);		
	Serial.print("\tLoop Catch: ");
	Serial.print(loopCatch, BIN);
	Serial.print("\tDirtyTimer: ");
	Serial.println(dirtyPoolTimer, DEC);	
	
	Serial.print("\tSpirit Value: ");
	Serial.print(spiritGuide[player], DEC);
	Serial.print("\tSpirit En: ");
	Serial.print(spiritGuideActive, DEC);		
	Serial.print("\tHospital: ");
	Serial.print(hosProgress[player], DEC);
	Serial.print("\tTheater: ");
	Serial.print(theProgress[player], DEC);
	Serial.print("\tFort: ");
	Serial.print(fortProgress[player], DEC);
	Serial.print("\tBar: ");
	Serial.print(barProgress[player], DEC);
	Serial.print("\tHotel: ");
	Serial.print(hotProgress[player], DEC);
	Serial.print("\tPrison: ");
	Serial.print(priProgress[player], DEC);
	Serial.print("\tDemon: ");
	Serial.print(deProgress[player]	, DEC);		
	Serial.println(" ");
	Serial.print("Minion Mode: ");
	Serial.print(minion[player], DEC);					
	Serial.print("\tMinion MB: ");
	Serial.print(minionMB, DEC);	
	Serial.print("\tModeTimer: ");
	Serial.print(modeTimer, DEC);				
	Serial.println(" ");

}

void lookForSerial() {							//See if anything's on the serial buffer, and fill the command if so

	if (Serial.available()) {

		int temp = Serial.read();
		
		if (temp == '[') {						//Command coming in?
			commandByte = 0;
			messageFlag = 1;
			return;
		}
		if (temp == ']') {						//Full command received?
			if (commandByte == 6) {				//If a proper 6 byte command, Interpret() it!
				messageFlag = 0;
				interpret();				
			}
			else {
				messageFlag = 0;
				commandByte = 0;				
			}
			return;
		}
		
		if (messageFlag == 1) {					//If we got a valid leading '[' fill the command buffer with whatever comes in
			command[commandByte] = temp;
			
			commandByte += 1;
			
			if (commandByte > 6) {				//More than 6 bytes? Garbage, abort fill
				messageFlag = 0;
				commandByte = 0;
			}
		}
	}	
}

void interpret() {								//CONTAINS VERSION # STRING UPDATE THIS WHEN CODE CHANGES!

	itemType = command[0];
	
	if (itemType > 96) {							//Convert command letter to uppercase if need be
		itemType -= 32;
	}

	for (int x = 1 ; x < 6 ; x++) {				
		command[x] -= 48;							//Convert ASCII characters to actual numeral	
	}

	itemNumber = (command[1] * 10) + command[2];	//Convert numerals to hundreds, tens and ones
	itemParameter = (command[3] * 100) + (command[4] * 10) + command[5];

	switch (itemType) {								//Now do the command (if valid)
		case 'H':												//Help!!
			showCommands();
			break;
		case 'L':	//Light command?
			if (itemNumber == 99) {								//Attract Lights command?
				attractLights = itemParameter;					//Set if lights should flash or not
				if (itemParameter == 0) {						//If set to NO, clear lamps
					Serial.println("Attract Lights: DISABLED");
					allLamp(0);
				}
				else {
					Serial.println("Attract Lights: ENABLED");
				}
			}
			if (itemNumber == 98) {								//All lights command?
				if (itemParameter == 0) {						//If set to NO, clear lamps
					Serial.println("All inserts: OFF");
					allLamp(0);
				}
				else {
					Serial.println("All inserts: ON");
					allLamp(7);
				}
			}			
			if (itemNumber < 64 and itemParameter < 8) {			//A valid light setting?
				Serial.print("LIGHT: ");
				Serial.print(itemNumber, DEC);
				Serial.print(" @ ");
				Serial.println(itemParameter, DEC);		
				light(itemNumber, itemParameter);					//And finally, set the light		
			}
			break;
		case 'M':	//MOSFET solenoid command?
			if (itemNumber < 24 and itemParameter < 255) {
				Serial.print("MOSFET: ");
				Serial.print(itemNumber, DEC);
				Serial.print(" @ ");
				Serial.print(itemParameter, DEC);
				Serial.println(" ms pulse");		
				Enable();										//Make sure they can run		
				Coil(itemNumber, itemParameter);				//Kick a coil up to 90ms		
			}						
			break;
		case 'E':	//Enable/disable command?
			if (itemNumber == 99) {								//Flag to return current state of the switches?		
				switchBinary();		
			}
			if (itemNumber == 98) {								//Enable / disable switch matrix
				if (debugSwitch) {
					Serial.println("HIDE Switch Matrix");
					debugSwitch = 0;
				}
				else {
					Serial.println("SHOW Switch Matrix");
					debugSwitch  = 1;		
				}
			}							
			if (itemNumber == 97) {								//Ball search enable / disable?
				if (itemParameter == 0) {
					Serial.println("Ball Search: DISABLED");
					ballSearchEnable = 0;
				}
				if (itemParameter == 1) {
					Serial.println("Ball Search: ENABLED");
					ballSearchEnable = 1;		
				}
			}		
			if (itemNumber == 96) {								//Video attract mode enable / disable?
				if (itemParameter == 0) {
					Serial.println("Video Attract Mode: DISABLED");
					Update(0);
				}
				if (itemParameter == 1) {
					Serial.println("Video Attract Mode: ENABLED");
					Update(1);		
				}
			}	
			if (itemNumber == 11) {								//Print human-readable Game Variable Status?
				showGameStatus();
			}		
			if (itemNumber == 00) {								//Get software version #? (parameter doesn't matter)
				//Serial.print("{011}");				
				printInitials();								//Retrieve game name from EEPROM and send via Serial as plain text (no CR/LF)
				printVersion();									//Prints version # as 3 digit plain text (no CR/LF)
				Serial.println("");								//Carriage return
			}	
			break;
		case 'S':	//Servo command?
			if (itemNumber < 5 and itemParameter < 181) {		//Valid numbers?
				Serial.print("Servo: ");
				Serial.print(itemNumber, DEC);
				Serial.print(" @ ");
				Serial.print(itemParameter, DEC);
				Serial.println(" degrees");		
				Enable();										//Make sure they can run		
				myservo[itemNumber].write(itemParameter); 		//Set servo	
			}
			break;
		case 'V':	//Video command?
			Serial.println("Playing Video");
			video(command[3] + 48, command[4] + 48, command[5] + 48, 0, 0, 255);			
			break;
		case 'F':	//SFX or Music command?
			if ((command[3] + 48) == 'Z') {						//Music?
				if (command[4] == 0) {							//Zero zero, stop music?
					Serial.println("Stopping Music");
					stopMusic();
				}
				else {
					Serial.println("Playing Music");
					playMusic(command[4] + 48, command[5] + 48);				
				}
			}
			else {												//Else it's a SFX
				Serial.println("Playing SFX");
				playSFX(0, command[3] + 48, command[4] + 48, command[5] + 48, 255);
			}
			
			break;
		case 'R':	//Read EEPROM command?
			unsigned long readWhat = (command[2] * 1000) + (command[3] * 100) + (command[4] * 10) + command[5];
			Serial.print("EEPROM location <");
			Serial.print(readWhat);
			Serial.print("> long: ");
			unsigned long theContents = readEEPROM(readWhat);
			Serial.print(theContents);
			Serial.print(" high byte:");	
			Serial.print((theContents >> 24) & 0xFF);
			Serial.print(":");	
			Serial.print((theContents >> 16) & 0xFF);
			Serial.print(":");	
			Serial.print((theContents >> 8) & 0xFF);
			Serial.print(":");	
			Serial.print(theContents & 0xFF);
			Serial.print(":low byte  ASCII: ");				
			Serial.write((theContents >> 24) & 0xFF);	
			Serial.write((theContents >> 16) & 0xFF);
			Serial.write((theContents >> 8) & 0xFF);	
			Serial.write(theContents & 0xFF);
			Serial.println(" ");				
			break;			
	}

	for (int x = 0 ; x < 6 ; x++) {							//Erase buffer, reset command byte back to 0
		command[x] = 0;
	}	
	commandByte = 0;
	
}

void showCommands() {							//Display the serial terminal commands

	Serial.println(" ");		
	Serial.println("------SERIAL MONITOR COMMAND LIST-------");
	Serial.println("[E99000] Get current switch state, raw data (2 bytes dedicated, 8 bytes matrix)");
	Serial.println("[E98000] Toggle serial stream of human-readable switch data");
	Serial.println("[E97000] Disable Ball Search (Useful for testing)");
	Serial.println("[E97001] Enable Ball Search (Default)");
	Serial.println("[E96000] Disable Video Attract Mode (Good for testing videos)");
	Serial.println("[E96001] Enable Video Attract Mode");
	Serial.println("[E11000] Print Game Mode Variables for Debugging");
	Serial.println("[E00000] Get Game Code Version # (Returned as {xxx})");		
	Serial.println(" ");
	Serial.println("[F00ABC] Play sound effect ABC");	
	Serial.println("[F00Zxx] Play music file XX (Music files always in _DZ folder)");		
	Serial.println("[F00Z00] Stop music");
	Serial.println("[V00ABC] Play video file ABC");
	Serial.println(" ");	
	Serial.println("[SXXzzz] Set servo XX (0-4) to ZZZ Degrees (Only set if you know proper values!)");	
	Serial.println("[MXXzzz] Activate Coil XX (0-23) for ZZZ Microseconds (0-250)");
	Serial.println("[LXXzzz] Set light XX (0-63) to ZZZ brightness (0-7)");
	Serial.println("[L99000] Disable light attract mode (Also turns off all inserts)");
	Serial.println("[L99001] Enable light attract mode");
	Serial.println("[L98000] All insert lights OFF");
	Serial.println("[L98001] All insert lights ON");	
	Serial.println(" ");	
	Serial.println("[R0XXXX] Read EEPROM position XXXX (0-8191)");	
	
	Serial.println("----------------------------------------");	

}

void addPlayer() {								//Adds additional players beyond Player 1

  skillScoreTimer = 0 - cycleSecond3;       //Go negative so we "eat" the time added by this video, so the score loop timing appears normal on next cycle

  killQ();
  
	if (numPlayers < 4) {											//4 player limit.
  
		numPlayers += 1;
		video('K', 'P', 48 + numPlayers, noExitFlush, 0, 255);		//Show new player intro, with NO NUMBERS			
    resumeSkillShotDisplay();		
		playSFX(0, 'A', numPlayers + 64, '1' + random(4), 255);		//ADJUST BASED OFF PLAYER ADDED
    
	}
	else {															//Player subtract only works in free play, and only removes players who haven't started a ball yet	
  
		if (freePlay and player < 4) {								//If player 3 is ready to launch, Player 4 can be removed. But if player 4 is up, you are stuck with 4 players		
			numPlayers = player;									//Change the total number of players to whichever player is up
			video('K', 'R', '1' + numPlayers, noExitFlush, 0, 255);	//Show message (with offset in filename)
      resumeSkillShotDisplay();		
			playSFX(0, 'P', '9', 'A' + random(4), 255);				//Random "I'm sitting this one out" quotes from Prison mode		
		}	
    
	}
  
}
        
void resumeSkillShotDisplay() {

	if (run != 3) {												//Ball still in shooter lane?		

		if (numPlayers > 1) {
      killCustomScore();
      videoQ('K', 48 + player, 64 + skillShot, allowSmall | noEntryFlush, 0, 1);
      numbers(7, 2, 44, 27, numPlayers);										//Update Number of players indicator
      numbers(6, numberScore | 6, 0, 0, player);						//Put player score upper left, using Double Zeros
      numbers(5, 9, 88, 0, 0);										          //Ball # upper right	     
		}
		else {
			customScore('K', '0', 64 + skillShot, allowSmall | loopVideo);	//Update Skill Shot display
      numbers(8, numberScore | 6, 0, 0, player);						//Put player score upper left, using Double Zeros
      numbers(9, 9, 88, 0, 0);										          //Ball # upper right				
		}	
 
	}	
  
}

void AttractMode() {							//Runs my slightly less crappy light show

	modeTimer += 1;

	if (modeTimer == 1000) {

		//digitalWrite(startLight, 0);
		modeTimer = 0;

		if (lightCurrent == 0) {
			GIpf(B00000000);
			setCabModeFade(255, 0, 0, 25);
		}
		if (lightCurrent == 10) {
			GIpf(B10000000);
			setCabModeFade(0, 0, 255, 25);
		}		
		if (lightCurrent == 15) {
			GIpf(B11010000);
			setCabModeFade(255, 255, 255, 25);
		}	
		if (lightCurrent == 25) {
			GIpf(B11110000);
		}	

		lightCurrent += 1;
	
		if (lightCurrent > lightEnd) {			//Loop the animation
			lightCurrent = lightStart;		
		}

	}

	multiTimer += 1;							//Increment the light timer
	
	if (multiTimer > 5000) {
		multiTimer = 0;							//Reset timer
		if (multiCount) {
			leftRGB[0] += 1;
			leftRGB[1] -= 1;
			leftRGB[2] += 1;
			rightRGB[0] -= 1;
			rightRGB[1] += 1;
			rightRGB[2] -= 1;
			if (leftRGB[0] == 250) {
				multiCount = 0;					//Change direction
			}
		}
		else {
			leftRGB[0] -= 1;
			leftRGB[1] += 1;
			leftRGB[2] -= 1;
			rightRGB[0] += 1;
			rightRGB[1] -= 1;
			rightRGB[2] += 1;
			if (leftRGB[0] == 100) {
				multiCount = 1;					//Change direction
			}
		}
		doRGB();		
	}

}

void AutoPlunge(unsigned long whatTime) {		//Loads a ball and shoots it. If called again before sequence completes, it will enqueue additional balls

	//Serial.print("Autoplunge @ ");
	//Serial.println(whatTime, DEC);
	//Serial.print("RUN= ");
	//Serial.println(run, DEC);
	
	if (plungeTimer) {						//Already active?
		ballQueue += 1;						//Add a ball to the queue, plunge it once current ball is launched
		return;								//Abort
	}

	if (whatTime < 25002) {					//Not the minimum? Set it to minimum
		whatTime = 25002;
	}
	
	plungeTimer = whatTime;

}

void balconyApproach() {						//Fresh hit on right orbit? (Didn't roll down from ORBS or back from balcony)

	animatePF(230, 10, 0);

  if (Mode[player] == 8) {              //Bumps in the night?
    bumpCheck(4);                       //Check that function and return out
    return;
  }
    
	if (hellMB and minion[player] < 100) {
		tourGuide(0, 8, 4, 50000, 1);				//Check for GHOST CATCH
	}		

	if (Mode[player] == 6) {										//Prison?
		tourGuide(0, 6, 4, 25000, 1);								//Check that part of the tour!
	}	

	if (hotProgress[player] > 29 and hotProgress[player] < 40) {	//Fighting the Hotel Ghost? (can't do tour during the Control Box search)
		tourGuide(1, 5, 4, 25000, 1);				//Check that part of the tour!		
	}	

	if (Mode[player] == 4) {						//War fort?
		int x = random(8);
		playSFX(0, 'W', '5', 'A' + x, 210);						//Random Army Ghost lines
		if (tourGuide(0, 4, 4, 25000, 0) == 0) {
			video('W', '5', 'A' + x, allowSmall, 0, 250);		//Synced taunt video
		}														//Check that part of the tour (no WHOOSH sound needed)		
	}		
	
	if (barProgress[player] > 69 and barProgress[player] < 100) {			//Haunted Bar?
		tourGuide(0, 3, 4, 25000, 1);				//Check that part of the tour!
	}	
	
	if (Mode[player] == 1) {			//Hospital?
		tourGuide(1, 1, 4, 25000, 1);				//Check that part of the tour!
	}
		
	if (skillShot) {					//On the off chance it somehow gets by the ORB rollovers on a launch...			
		if (skillShot == 2) {							//Did we hit the Skill shot?
			skillShotSuccess(1, 0);							//Success!
		}
		else {
			skillShotSuccess(0, 255);						//Failure, so just disable it
		}			
	}	

	if (Advance_Enable) {					//Are we trying to advance theater?
		playSFX(0, 'T', '9', 'Y', 200);		//Run and jump sound
		video('T', '9', 'Y', allowSmall, 0, 200);	//Run and jump animation
	}			
	
	if (deProgress[player] > 9 and deProgress[player] < 100) {			//Trying to weaken demon
		DemonCheck(4);
	}
	
	if (hotProgress[player] == 20)	{		//Searching for the Control Box?
		BoxCheck(3);					//Check / flag box for this location
	}

	if (Mode[player] == 7) {				//Are we in Ghost Photo Hunt?
		photoCheck(4);
	}			

	if (theProgress[player] > 9 and theProgress[player] < 100) {			//Theater Ghost?	
		//TheaterPlay(0);					//Incorrect shot, ghost will bitch!
		//Sweet Jumps!
		playSFX(0, 'T', '9', 'Y', 200);		//Run and jump sound
		video('T', '9', 'Y', allowSmall, 0, 210);	//Run and jump animation
            
	}

	if (minionMB > 9) {						//Minion Jackpot increase?
		minionJackpotIncrease();
		lightningStart(50000);
		MagnetSet(100);
	}					
	
}

void balconyJump() {							//What happens when you successfully make the Balcony Jump

	//There are 4 possible things that happen when you make the Balcony Jump
	//1: No Mode Active / Theater Not started = Show combo, advance theater
	//2: Theater Active = Do not show combo (but light it as one) Advance Super Jumps, add 500k per jump. Not combo timer dependent (but mode itself is timed)
	//3: No Mode Active / Theater Completed = Do not show combo, advance Super Jumps, add 100k per jump with combo timer active
	//4: Other Mode Active = Show combo, normal logic (most logic uses the balcony approach, but make the jump to score/light combo)

	if (theProgress[player] < 3) {			  //Has theater not been enabled yet?
		comboCheck(4);											//Normal combo check
		TheaterAdvance(Advance_Enable);			//Advance Theater (with flag since this CAN be advanced during other modes)
		return;
	}
	
	if (theProgress[player] == 100 and Advance_Enable) {		//CASE 3: Theater has been completed?
		sweetJumpBonus += 100000;								//100k added per jump. Resets when combo times out.
		sweetJump += 1;											//So making shot ALWAYS awards at least 100k, and that increases if you combo shots together
		if (sweetJump > 12) {									//Limit the animations/SFX, but no limits of total # of Sweet Jumps and bonus value
			sweetJump = 12;										//You only get 15 seconds per shot in theater mode, so unless you make a jump a second
		}														//highly unlikely you'll ever hit the limit of 12			
		playSFX(1, 'T', 'S', 64 + sweetJump, 255);				//Whooshing jump sound FX
		video('T', 'J', 64 + sweetJump, allowSmall, 0, 255);	//Jump Complete video
		showValue(sweetJumpBonus, 0, 1);
		return;
	}
			
	if (theProgress[player] > 9 and theProgress[player] < 100) {	//During Theater mode, spam this shot for Sweet Jumps!
		sweetJumpBonus += 500000;									//500k more per jump (worth more in actual mode. Resets when you add time by hitting ghost. Risk/reward!
		sweetJump += 1;
		if (sweetJump > 12) {										//Limit the animations, but no limits of total # of Sweet Jumps
			sweetJump = 12;											//You only get 15 seconds per shot in theater mode, so unless you make a jump a second
		}															//highly unlikely you'll ever hit the limit of 12			
		playSFX(1, 'T', 'S', 64 + sweetJump, 255);					//Whooshing jump sound FX
		video('T', 'J', 64 + sweetJump, allowSmall, 0, 255);		//Jump Complete video
    
    if ((achieve[player] & theaterBit) == 0) {            //First time we've done this?
    
      achieve[player] |= theaterBit;                      //Set the bit
      
      if ((achieve[player] & allWinBit) == allWinBit) {             //Did we get them all? Add the multiplier prompt
        videoQ('R', '7', 'E', 0, 0, 255);             //All sub modes complete!
        demonMultiplier[player] += 1;							    //Add multiplier for demon mode
        playSFXQ(1, 'D', 'Y', 'A' + random(6), 255);  //Add Multiplier! 
      }
      
    }     
    
		showValue(sweetJumpBonus, 0, 1);
		return;
	}

	//If in another mode, or Theater is lit but not collected, prompt standard combos   
    
	comboCheck(4);													//Normal combo check
	
	comboVideoFlag = 0;												//Nothing active? Reset video combo flag	
	AddScore(5000);													//Some points

	//Nothing going on default prompt
	video('C', 'G', 'E', allowSmall, 0, 250);						//Regular Combo to the Right ->	
	playSFX(2, 'A', 'Z', 'Z', 255);									//Whoosh!		
	
}

void ballElevatorLogic() {						//What happens when a ball goes in the Elevator on second floor

	//Serial.println("BALL IN HELLAVATOR");

	comboCheck(3);													//Always check for combo shot!
    
	if (Mode[player] != 3) {											//Prevents Ghost Whore from taunting you when loading MB in her mode
		ghostLooking(165);		
	}

	if (HellBall == 0) {												//Ball just went into Hellavator, and we're allowed to lock balls?

		if (hotProgress[player] == 30) {					//Waiting for Jackpot Enable shot?
			HellBall = 10;													//Set flag for ball Transit
			ElevatorSet(hellDown, 20);										//Move elevator down
			light(41, 0);													//Flasher OFF
			HotelLightJackpot();
			return;
		}

		if (theProgress[player] == 10) {					//Waiting for first shot in Theater Mode?
			HellBall = 10;													//Set flag for ball Transit
			TheaterPlay(1);
			return;
		}

		if (deProgress[player] == 4) {										//Third locked ball for Demon Mode?
			DemonLock3();
			return;
		}
		
		if (hotProgress[player] == 3 and Advance_Enable == 1) {				//Ready to start Hotel Mode?
			HotelStart1();
			return;															//So the ghost doesn't move
		}

		if (hellLock[player] == 1) {								//Can we lock a ball? We don't care where the elevator actually is (that caused a bug)
			light(41, 0);											//Turn off flasher
			HellBall = 10;											//Set flag for ball Transit
			ElevatorSet(hellDown, 100);								//Move elevator down (was 150)
			light(25, 7);											//Current state is SOLID
			blink(24);												//Other state BLINKS
			light(30, 0);											//Lock is NOT lit				
				
			if (multiBall & multiballHell) {						//Minion MB is a MB without hell locks, but if Hell is enabled, we must be in Hell MB, or Hell MB + Minion MB
			
				video('Q', 'J', 'D', B00000001, 0, 255);			//Jackpot!
				playSFX(0, 'Q', 'J', 'D' + random(5), 255);			//A random jackpot sound!
				showValue(hellJackpot[player], 40, 1);	
				flashCab(255, 255, 255, 50);
				strobe(26, 5);
				if (hellMB) {
					customScore('Q', 'B', 'A', allowAll | loopVideo);	//Custom Score: Ramp increase, Ghost Catch
				}					
				
			}
			else {													//Only increase if we AREN'T in a multiball

				callHits = 0;													//Reset # of Call Hits
				AddScore(50000);												//Some points
				lockCount[player] += 1;										//Increase count to Multiball. Need 3.
				killQ();
				video('Q', 'A', 48 + lockCount[player], 0, 0, 255); 			//Show people going down in an elevator, or MB starting animation
				light(26, 0);													//Clear hotel progress lights
				light(27, 0);
				light(28, 0);
				light(41, 0);										//Turn off flasher
				blink(30);
				
				//Set lights
				if (lockCount[player] == 1) {						//One ball locked
					light(26, 7);
					//flashCab(255, 0, 255, 100);
          hellFlashFlag = 1;
				}
				if (lockCount[player] == 2) {						//Two balls locked?
					light(26, 7);
					light(27, 7);
          hellFlashFlag = 1;
					//flashCab(255, 0, 255, 100);
				}
				if (lockCount[player] == 3) {						//Three balls locked?
					blink(26);
					blink(27);
					blink(28);						
					multiBallStart(1);						
				}
				else {
					playSFX(0, 'Q', 'A', 48 + lockCount[player], 255); //Ball 1 or 2 LOCKED!
					animatePF(74, 30, 0);								//Vertical lock swoosh
				}
			
			}			
		}	
	
  }
	
}

void ballExitElevatorLogic() {

	//Serial.println("HELL EXITED");

	HellBall = 0;								//Clear flag

	if (hellLock[player]) {			//Can balls be locked?

		if (multiBall == 0 and lockCount[player] < 3) {								//Haven't started multiball yet, but we are able to?
			//Once a Ball is locked, revert the Ramp Lights to HOTEL state
			light(25, 7);															//Current state is SOLID
			blink(24);																//Other state BLINKS

			light(30, 0);															//Lock is NOT lit now (elevator is down)
			
			if (Advance_Enable) {													//We're not in a mode? See if we paint Hotel Lights...
				if (hotProgress[player] < 100) {									//Able to advance hotel?
					if (hotProgress[player] == 0) {									//Show how far it is
						pulse(26);
						light(27, 0);
						light(28, 0);
						light(29, 0);		
					}
					if (hotProgress[player] == 1) {
						light(26, 7);
						pulse(27);
						light(28, 0);
						light(29, 0);		
					}
					if (hotProgress[player] == 2) {
						light(26, 7);
						light(27, 7);
						pulse(28);
						light(29, 0);		
					}		
					if (hotProgress[player] == 3) {
						light(26, 7);
						light(27, 7);
						light(28, 7);
						pulse(29);		
					}	
				}
				else {																	//Hotel complete? No lights. (they didn't leave the light on for ya)
					light(26, 0);
					light(27, 0);
					light(28, 0);
					light(29, 0);
				}		
			}	
		}									
	}		

}

void ballSave() {								//Call this to set (enable) Ball Save. Time can vary per player

	//Serial.println("BALL SAVE ACTIVATED");

	if (saveTimer < ((saveCurrent[player] + 2) * cycleSecond)) {	//If you're awarded a 30 second ball save, don't want a new one that's less! 8-22-14 fix
		saveTimer = ((saveCurrent[player] + 2) * cycleSecond);		//Default is 5 seconds, can be changed in menu 8-22-14 fix
	}
	
	spookCheck();													//See what to do with the light
	
}

void ballSaveScoop() {							//If scoop shoots right down the drain, you get ball back (2 second "silent" ball save)

	//Serial.println("SCOOP SAVE ACTIVATED");

	if (saveTimer < (scoopSaveStart * cycleMilliSecond)) {			//1.5 seconds - 2 is a BIT too much
		saveTimer = scoopSaveStart * cycleMilliSecond;				//Now it's user defined, in milliseconds
	}
	
	spookCheck();													//See what to do with the light
	
}

void ballSearch() {								//Can't find balls? This routine tries to find them

	//Serial.println("Ball Search, please wait...");

	// if (switchDead == 0 and run == 0) {				//Don't move these down if we're trying to find balls to start a game
		// myservo[Targets].write(TargetDown);			//Put targets down
		// myservo[HellServo].write(hellDown); 		//Hellavator down
		// myservo[DoorServo].write(DoorOpen); 		//Open Door
		// myservo[GhostServo].write(90); 				//Center Ghost		
	// }

	if (Switch(63) and kickTimer == 0) {		//Ball in drain?
		//Coil(drainKick, drainStrength);
		kickFlag = 1;							//Set flag that ball is being kicked from the drain
		kickPulse = 0;							//Make sure PWM timer is reset
		kickTimer = 8000;						//WAS 10,000 //Wait 10k cycles, then kick hold for 10k cycles
	}
	
	if (Switch(22)) {				//Ball in Basement Scoop?
		Coil(ScoopKick, scoopPower);
		//Serial.println("Ball BASEMENT SCOOP");
	}
	
	if (Switch(23)) {				//Ball behind door?
		Coil(LeftVUK, vukPower);
		//Serial.println("Ball LEFT VUK");
	}

	if (Switch(57)) {				//Ball in shooter lane?
		//Serial.println("Ball Search KICK");
		Coil(Plunger, plungerStrength);			//Kick it out!
		//Serial.println("Ball SHOOTER LANE");
	}		

}

void ballSearchDebounce(char onOff) {

	if (onOff) {
		swRampDBTime[22] = trapSwitchSlow;
		swRampDBTime[23] = trapSwitchSlow;
		//swRampDBTime[57] = trapSwitchSlow;
	}
	else {
		swRampDBTime[22] = trapSwitchNormal;
		swRampDBTime[23] = trapSwitchNormal;
		//swRampDBTime[57] = trapSwitchNormal;	
	}

}

void ballClear() {								//Like ball search, clears out locked balls

	if (Switch(22)) {				//Ball in Basement Scoop?
		Coil(ScoopKick, scoopPower);
	}
	
	if (Switch(23)) {				//Ball behind door?
		Coil(LeftVUK, vukPower);
	}

	if (Switch(57)) {				//Ball in shooter lane?
		Coil(Plunger, plungerStrength);			//Kick it out!
	}	

}


//Functions for Bar Ghost Mode 4........................
void BarAdvance(unsigned char howMany) {								//X number of pops advances bar

	AddScore(popScore);
	areaProgress[player] += 1;					    //Total mode progress	
	barProgress[player] += howMany;					//Increment Bar Progress

	flashCab(0, 255, 0, 10);					      //Flash the GHOST BOSS color
	
	if (barProgress[player] > 0 and barProgress[player] < 26) { // and centerTimer == 0) 	//If we haven't filled it yet, show the progress
  
    if (comboVideoFlag and middleWarBar) {                    //If a combo, and using middle to advance, don't flush the bar graphs at start
      video('B', 'A', 'A', allowBar | allowSmall | preventRestart | noEntryFlush, 0, 250);     
    }
    else {
      video('B', 'A', 'A', allowBar | allowSmall | preventRestart, 0, 250);      
    }

		showProgressBar(4, 3, 12, 26, barProgress[player] * 4, 4);
		showProgressBar(5, 10, 12, 27, barProgress[player] * 4, 2);				
	}
		
	if (barProgress[player] == 8) {
		playSFX(0, 'B', '1', random(4) + 65, 250); //Advance sound 1					
		return;
	}				

	if (barProgress[player] == 16) {
		playSFX(0, 'B', '2', random(4) + 65, 250); //Advance sound 2					
		return;
	}

	if (barProgress[player] >= 26) {			//Did we fill the bar?	
		killQ();
		stopVideo(0);
		video('B', '4', '0', 0, 0, 255);		//Prompt for Bar Ghost Lit (can override Center Shot)
		playSFX(0, 'B', '3', random(4) + 65, 250); //Advance sound 3	
		//centerTimer = 25000;					//Prevents pop bumper jackpot from overiding prompt video		
		barProgress[player] = 50;				//50 indicates Mode is ready to start.			
		popLogic(3);							//Pops won't do anything else until you start the mode
		spiritGuideEnable(0);	
		showScoopLights();						//Update the Scoop Lights
		return;
	}

	popToggle();	
	stereoSFX(1, 'B', 'Z', random(3) + 65, 100, leftVolume, rightVolume);
	
}				

void BarStart() {								//What happens when we shoot the scoop to start Bar Mode 3

	light(45, 0);								//Turn off the mode start light in player bank
	
	restartKill(3, 1);							//In case we got the Restart	
	
	comboKill();								//So combo lights don't appear after the mode	
	storeLamp(player);							//Store the state of the Player's lamps
	allLamp(0);									//Turn off the lamps

	spiritGuideEnable(0);						//No spirit guide during Bar
		
	modeTotal = 0;								//Reset mode points	
	AddScore(startScore / 2);
	minionEnd(0);								//Disable Minion mode, even if it's in progress

	setGhostModeRGB(0, 0, 255);					//Blue mode color
	setCabModeFade(0, 63, 0, 200);				//Set mode color to DIM GREEN, fade to that color

	popLogic(3);								//Set pops to EVP
	Mode[player] = 3;							//Ghost whore mode start!
	Advance_Enable = 0;							//Mode has started, others can't
	DoorSet(DoorOpen, 100);

	light(45, 7);								//Turn BAR start light SOLID
	blink(60);									//Blink the Mode Light during battle.

	blink(17);									//Blink the targets for the Ghost Whore
	blink(18);
	blink(19);
	light(16, 0);

	barProgress[player] = 60;					//Set flag, ghost waiting to be touched!

	jackpotMultiplier = 1;						//Reset this just in case
	
	videoModeCheck();
			
	loopCatch = catchBall;						//Flag that we want to catch the ball in the loop
	
	//Serial.println("GHOST START");
	
	//VOICE CALL, GHOST APPEARS
	TargetTimerSet(50000, TargetDown, 100);		//Put targets down slowly so we notice.
	video('B', '4', 'A', B00000001, 0, 255);	//Show the Ghost!
	playSFX(0, 'B', '4', random(3) + 65, 255);	//Mode start dialog. Come resist my charms!	
	killQ();									//Disable any Enqueued videos
	playMusic('B', '1');						//Boss battle music!
	
	customScore('B', '1', 'A', allowAll | loopVideo);		//Shoot the Ghost custom score prompt
	numbers(8, numberScore | 2, 0, 0, player);	//Show player's score in upper left corner
	numbers(10, 9, 88, 0, 0);					//Ball # upper right	
		
	ScoopTime = 80000;							//Flag to kick the ball back out
	hellEnable(0);								//We can lock balls during this mode, but not until we trap the ball
	showProgress(1, player);					//Show the progress, Active Mode style

	dirtyPoolMode(0);							//Allow balls to be trapped
	
	skip = 30;									//Set skip mode to Bar Ghost
	
}

void BarLogic() {								//What happens during Ghost Battle Mode

	if (barProgress[player] > 69 and barProgress[player] < 80) {
		modeTimer += 1;
		if (modeTimer == 80000) {						//Random ghost taunt?						
			playSFX(0, 'B', '8', 'A' + random(8), 255);	//Will not override advance dialog
			video('B', '8', 'A', allowSmall, 0, 254);			//Will not override video		
			//MagnetSet(200);
		}
		if (modeTimer > 160000) {						//Kaminski prompt?
			modeTimer = 0;								//Reset timer
			playSFX(0, 'B', '7', 'A' + random(8), 255);	//Will not override advance dialog
			video('B', '7', 'A', allowSmall, 0, 254);			//Will not override video					
			//MagnetSet(200);		
		}		
	}

	if (barProgress[player] > 79 and barProgress[player] < 100) {						//Battling Ghost whore multiball!
		modeTimer += 1;
		if (modeTimer == 70000) {
			lightningStart(1);			//Do some lightning!		
			int x = random(2);
			if (x) {
				playSFX(0, 'B', 'B', '0' + random(10), 255);	//Team Leader commanding ghost to leave and stuff
			}
			else {
				playSFX(1, 'L', 'G', '0' + random(8), 255);	//Random lightning		
			}				
		}		
		if (modeTimer > 100000) {
			modeTimer = 0;									//Reset timer
		}			
	}	
	
}

void BarTrap() {								//What happens when you shoot the ghost and she captures your teammate

	if (restartTimer) {
		
		restartKill(3, 1);

		comboKill();								//So combo lights don't appear after the mode	
		storeLamp(player);							//Store the state of the Player's lamps
		allLamp(0);									//Turn off the lamps
		showProgress(1, player);					//Show the Main Progress lights
		spiritGuideEnable(0);						//No spirit guide during Bar			
		modeTotal = 0;								//Reset mode points	
		minionEnd(0);								//Disable Minion mode, even if it's in progress

		setGhostModeRGB(0, 0, 255);						//Blue mode color
		
		popLogic(3);								//Set pops to EVP
		Mode[player] = 3;							//Ghost whore mode start!
		Advance_Enable = 0;							//Mode has started, others can't
		DoorSet(DoorOpen, 100);

		tourReset(B00111010);						//Reset the Tour bits			
		playMusic('B', '1');						//Boss battle music!
		
	}

	setCabModeFade(0, 255, 0, 200);				//Turn lighting GREEN (with envy)
		
	AddScore(startScore / 2);					//Points for getting trapped
	barProgress[player] = 70;					//Advance the mode.
	dirtyPoolMode(0);							//Disable dirty pool check (since we DO want to trap the ball)
	trapTargets = 1;							//A ball is trapped!
	modeTimer = 0;								//Reset mode timer
	activeBalls -= 1;							//Remove an active ball
	
	video('B', '6', 'A', B00000001, 0, 255);	//Kaminski trapped!
	killQ();									//Disable any Enqueued videos
	playSFX(1, 'B', '6', random(4) + 65, 255);	//You're mine now sugar!
	pulse(17);									//Now pulse the lights
				
	pulse(18);
	pulse(19);
	hellEnable(1);								//We can lock balls during this mode, but not until we trap the ball
	
	customScore('B', '1', 'B', allowAll | loopVideo);		//Clear Targets for Multiball custom message
	numbers(8, numberScore | 2, 0, 0, player);	//We re-send these in case a quick restart occurred
	numbers(10, 9, 88, 0, 0);					//Ball # upper right	
	
	tourReset(B00111010);						//Tour: Left orbit, door, up middle, right orbit.
												//Hotel path: Can lock balls
												//Scoop: Steals kegs		
	ghostAction = 140000;
	AutoPlunge(70000);												//Set flag to launch second ball	
	
	skip = 35;
	
}

void BarTarget(unsigned char whichTarget) {		//Logic for determining which targets in Bar Ghost mode have been cleared

	ghostAction = 20000;							//Set WHACK routine.

	MagnetSet(100);
	ghostFlash(100);
	
	if (gTargets[whichTarget] == 1) {				//Already hit that one?
		playSFX(0, 'B', '7', 'S' + random(8), 255);	//Will not override advance dialog
		video('B', '8', 'D', allowSmall, 0, 255);				//"Clear Flashing Targets to start Multiball"	
		AddScore(25000);							//Some points		
	}
	else {
		targetsHit += 1;							//Increase how many targets we've hit
		
		if (targetsHit == 2) {						//Almost ready?
			customScore('B', '1', 'C', allowAll | loopVideo);		//Clear Targets MULTIBALL READY!!!
		}
		
		gTargets[whichTarget] = 1;					//Set the flag that we hit this
		light(17 + whichTarget, 7);					//Make light SOLID
		AddScore(250000);
		modeTimer = 0;								//Reset timer to avoid overlap
		if (gTargets[0] == 1 and gTargets[1] == 1 and gTargets[2] == 1) {				//Cleared them all?
			BarMultiball();							//Begin multiball
		}
		else {
			playSFX(0, 'B', '5', 'X' + random(3), 255);	//Ghost yelp!
			video('B', '8', 'E', allowSmall, 0,255);				//Ghost whacked! (or maybe life bar?)
			videoQ('B', '8', 'A' + targetsHit, allowSmall, 0, 200);			//How many hits are left			
		}
	}

}

void BarMultiball() {							//When you free your teammate and multiball to bash the ghost

	spiritGuideEnable(0);

	ghostAction = 0;
	kegsStolen = 0;								//Shooting the scoops lets you steal up to 10 kegs of beer for bonus points
	
	whoreJackpot = 0;							//Reset this per instance
	
	AddScore(winScore);							//Points for beating ghost
	winMusicPlay();
	
	modeTimer = 0;								//Reset timer for exorcist quotes
	
	ModeWon[player] |= 1 << 3;					//Set BAR WON bit for this player.	

	if (countGhosts() == 6) {										//This the final Ghost Boss? Light BOSSES solid!
		light(48, 7);
	}
	
	swDebounce[24] = 50000;						//Temporarily set Ghost Hit debounce really high so ball release won't trigger a Jackpot
	
	barProgress[player] = 80;					//Set flag for Ghost Whore Multiball
	light(60, 7);								//Bar mode light solid because A Winner Is You!

	pulse(16);									//Pulse "Make Contact"
	strobe(17, 3);
	pulse(47);									//Pulse Scoop Camera for beer stealing
	
	TargetTimerSet(10, TargetDown, 50);		//Put targets down fairly quickly
	trapTargets = 0;							//Ball is no longer trapped
	activeBalls += 1;
	killQ();									//Disable any Enqueued videos	
	playSFX(0, 'B', '9', 65 + random(4), 255);	//I'm Free! Let's get her dialog
	video('B', '9', 'A', B00000001, 0, 255); 	//Play Mad Ghost video
	//videoQ('B', '9', 'B', 2, 0, 255); 		//Jackpot Prompt

	manualScore(0, EVP_Jackpot[player] + 75000);					//Set what next Jackpot is worth, boss value + (Whore Hits * 75k)	
	
	customScore('B', '1', 'D', allowAll | loopVideo);				//Custom Score: Hit ghost for JACKPOTS!
	numbers(8, numberScore | 2, 0, 0, player);						//Put player score upper left
	numbers(9, numberScore | 2, 72, 27, 0);							//Use Score #0 to display the Jackpot Value bottom off to right
	numbers(10, 9, 88, 0, 0);										//Ball # upper right
			
	dirtyPoolMode(1);
	
	multipleBalls = 1;												//When MB starts, you get ballSave amount of time to loose balls and get them back
	ballSave();														//That is, Ball Save only times out, it isn't disabled via the first ball lost		
			
}

void BarWin() {									//When down to last ball, mode 3 is won

	if (multiBall) {							//Was a MB stacked?
		multiBallEnd(1);						//End it, with flag that it's ending along with a mode
	}

	multipleBalls = 0;
	tourClear();								//Clear the tour lights / values
	
	loadLamp(player);
	comboKill();
	
	spiritGuideEnable(1);

	ghostModeRGB[0] = 0;							//Fade out ghost
	ghostModeRGB[1] = 0;
	ghostModeRGB[2] = 0;
	ghostFadeTimer = 200;
	ghostFadeAmount = 200;
	lightningKill();
	setCabModeFade(defaultR, defaultG, defaultB, 100);		//Reset to default color

	if (countGhosts() == 5) {						//Is this the last Boss Ghost to beat?
		blink(48);									//Blink that progress light
	}
	
	light(16, 0);									//Turn off "Make Contact"
	light(17, 0);
	light(18, 0);	
	light(19, 0);
	light(60, 7);									//Turn Bar Mode solid because we won!
	light(45, 0);									//Make sure BAR START is off
	
	Mode[player] = 0;								//Set mode active to None
	barProgress[player] = 100;						//Flag that reminds us this mode has been won

	playSFX(0, 'B', '9', 'Y' + random(2), 255);		//I'm Free! Let's get her dialog
	playMusic('M', '2');							//Normal music
	
	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();
	
	killQ();													//Disable any Enqueued videos	
	video('B', '0', 'Z', noExitFlush, 0, 255); 					//Play Death Video
	numbersPriority(0, numberFlash | 1, 255, 11, modeTotal, 233);			//Load Mode Total Points
	modeTotal = 0;									//Reset mode points		
	videoQ('B', '0', 'V', noEntryFlush | B00000011, 0, 233);	//Mode Total:	
		
	ModeWon[player] |= 1 << 3;						//Set BAR WON bit for this player.	
	ghostsDefeated[player] += 1;					//For bonuses
	Advance_Enable = 1;

	if (countGhosts() == 2 or countGhosts() == 5) {	//Defeating 2 or 5 ghosts lights EXTRA BALL
	
		extraBallLight(2);							//Light extra ball, no prompt we'll do there
		//videoSFX('S', 'A', 'A', allowSmall, 0, 255, 0, 'A', 'X', 'A' + random(2), 255);	//"Extra Ball is Lit!"			
	
	}	
	
	demonQualify();									//See if Demon Mode is ready
	
	checkModePost();
	hellEnable(1);
	
	for (int x = 0 ; x < 6 ; x++) {					//Make sure the MB lights are off
		light(26 + x, 0);
	}
	
	showProgress(0, player);						//Show the progress, Active Mode style
	comboEnable = 1;												//OK combo all you want
	
}

int BarFail() {									//Returns a 1 if we can try again, 0 if not

	multipleBalls = 0;
	tourClear();								//Clear the tour lights / values
	
	loadLamp(player);

	spiritGuideEnable(1);

	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();	
	
	ghostModeRGB[0] = 0;
	ghostModeRGB[1] = 0;
	ghostModeRGB[2] = 0;
	ghostFadeTimer = 100;
	ghostFadeAmount = 100;
	lightningKill();
	setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset to default color
	
	if (ModeWon[player] & barBit) {									//Did we win this mode before?
		light(60, 7);												//Make Hospital Mode light solid, since it HAS been won
	}
	else {
		light(60, 0);												//Haven't won it yet, turn it off
	}

	light(16, 0);					//Turn off "Make Contact"
	light(17, 0);
	light(18, 0);	
	light(19, 0);

	ghostLook = 1;							//Ghost will now look around again.
	ghostAction = 0;
	
	Mode[player] = 0;												//Set mode active to None	
	Advance_Enable = 1;	
	hellEnable(1);	
	TargetSet(TargetDown);											//Release the ball and let it drain, or be caught by player!	
	trapTargets = 0;
	
	//BROKEN
	if (barProgress[player] == 60) {									//Didn't even hit the ghost to start?
		//dirtyPoolMode(1);												//Don't want to trap balls anymore
		loopCatch = 0;													//No longer want to trap ball
		checkModePost();												//In this condition, you lose your ball
		if (modeRestart[player] & (1 << 3)) {							//Able to restart Bar?
			modeRestart[player] &= ~(1 << 3);							//Clear the restart bit	
			barProgress[player] = 50;
			pulse(45);													//Pulse BAR GHOST start light
			popLogic(3);												//Set pops to EVP
		}
		else {
			barProgress[player] = 0;									//Gotta start over!
			if (fortProgress[player] < 50) {							//Haven't completed the Fort yet?
				popLogic(1);											//Set pops to advance Fort
			}
			else {
				popLogic(2);											//Else, have them re-advance Bar Ghost until we get it
			}		
			light(45, 0);												//Turn off BAR GHOST start light
		}
		
		return 0;														//In this condition, you lose your ball
	}

	//Else, you must have started the Bar Fight!
	
	if ((modeRestart[player] & barBit) and tiltFlag == 0) {			//Able to restart Bar?
		modeRestart[player] &= ~barBit;							              //Clear the restart bit	
		restartBegin(3, 11, 25000);									              //Enable a restart!		
		barProgress[player] = 60;									                //Waiting for Ghostly Embrace!
		loopCatch = catchBall;										                //Flag that we want to catch the ball in the loop	
		dirtyPoolMode(0);											                    //Disable dirty pool, like Ghost Start does
		doorLogic();												                      //Since we opened the door, see what we're supposed to do with it if mode ends
		blink(17);
		blink(18);
		blink(19);
		activeBalls += 1;											                    //Count the ball we just released		
		playMusic('H', '2');										                  //Hurry Up Music!		
		video('B', '0', 'Y', B00000001, 0, 255); 					        //Mode fail! Shoot door to restart!
		killQ();													                        //Disable any Enqueued videos	
		playSFX(0, 'B', 'R', 'A' + random(6), 255);					      //You've got 5 seconds to come back honey!	
		return 1;													                        //Flag to prevent a drain!
	}
	else {															                        //End mode, and let the ball drain
		barProgress[player] = 0;									                //Gotta start over				
		if (fortProgress[player] < 50) {							            //Haven't completed the Fort yet?
			popLogic(1);											                      //Set pops to advance Fort
		}		
		dirtyPoolMode(1);											//Don't want to trap balls anymore
		
		checkModePost();
		TargetSet(TargetDown);										//Release the ball...
		TargetTimerSet(20000, TargetUp, 10);						//and put targets back up after a bit				
		
		showProgress(0, player);
		return 0;													//Let the ball drain
	}

	for (int x = 0 ; x < 6 ; x++) {					//Make sure the MB lights are off
		light(26 + x, 0);
	}
		
	showProgress(0, player);					//Show the progress, Active Mode style
	comboEnable = 1;												//OK combo all you want

}
//Functions for Bar Ghost Mode 4........................

void bumpsStart() {
  
	videoModeCheck();
	lightSpeed = 1;								//Fast light speed	
	restartKill(0, 0);	
	AddScore(500000);

	subWon[player] = subWizStarted;      //Set flag so it won't re-trigger during the mode
  
	comboKill();
	storeLamp(player);							//Store the state of the Player's lamps
	allLamp(0);									    //Turn off the lamps

	spiritGuideEnable(0);						//No spirit guide during Photo Hunt
	minionEnd(0);								    //Disable Minion mode, even if it's in progress

	modeTotal = 0;

	setGhostModeRGB(20, 20, 20);				         //Set Ghost to dim. If you hit the loop enough times it will light where the next ghost is GHOST RADAR!
	TargetTimerSet(10, TargetUp, 150);		      //Put targets UP, hit them for Ghost Radar
  
	GIpf(B10000000);                            //Only the nearest GI on to start  
	setCabModeFade(30, 30, 30, 300);				    //Dark lighting on purpose (maybe the game is broken?)

	comboEnable = 0;

	//playSFX(0, 'F', '2', 62 + photosToGo, 255);	//Mode start dialog, based off photos needed
	video('J', '0', '0', 0, 0, 255);
	playSFX(0, 'J', 'A', '1' + random(3), 255);			//Mode start prompt
	killQ();									                  //Disable any Enqueued videos
 
	bumpGhosts = 3;                                     //How many ghosts to find
	bumpHits = 10;                                       //How many hits to go (10 means haven't found a ghost yet)
	bumpType = 9;                                        //Set this high so first random ghost can be 0-3 (instead of 1-3)

	customScore('J', '0', '1', allowAll | loopVideo);		//Shoot the Ghost custom score prompt
	numbers(8, numberScore | 2, 0, 27, player);	        //Show player's score lower left 
	numbers(9, 2, 86, 21, bumpGhosts);	                //Show # of ghosts left to beat  
	numbers(10, 9, 88, 27, 0);					                  //Ball # lower right	

	Mode[player] = 8;							              //Bumps in the Night mode!
	Advance_Enable = 0;							            //Can't advancd until we win or lose (or drain)

	DoorSet(DoorOpen, 5);						//Open the Spooky Door, if it isn't already

	hellEnable(0);								//Can't lock balls

	showProgress(1, player);					        //Show the Main Progress lights	(do this first so the BLINK PROGRESS will work)

	blink(50);									              //Blink the 3 mode lights
	blink(49);
	blink(2);

	pulse(17);                      //Pulse the GHOST targets (hit to do GHOST RADAR)
	pulse(18);
	pulse(19);

	bumpWhich = random(5);          //Select a starting spot 0-4

	playMusic('U', 'A');						//Bumps search beat

	ScoopTime = 55000;							//Kick out the ball	(change this once we get VOICE)

	modeTimer = ScoopTime + cycleSecond4;  //Don't start counting down until we've found a ghost
 
}

void bumpCheck(unsigned char whichShot) {

  if (bumpWhich == whichShot) {     //The right spot?
  
    if (bumpHits == 10) {           					  //First time we've hit this one? Found the ghost!

      AddScore(1000000);                                //One million for finding him...
      setCabMode(0, 255, 0);				                    //Set to green...
      GIpf(B11100000);                                  //GI back on
      lightningStart(5998);							                //Lightning FX	
      
      blink(photoLights[bumpWhich]);                      //Found it? Blink the light (uses same array as Photo Hunt)
      
      int x = bumpType;
      
      while (x == bumpType) {                           //Pick a new ghost design but make sure it's not the same one twice          
        bumpType = random(4);            
      }
      
      bumpType = random(4);                               //Choose from ghost 0-3      
      video('J', '0' + bumpType, 'A', 0, 0, 255);         //White fade in to ghost
      killQ();									                          //Disable any Enqueued videos
      playSFX(0, 'J', 'D', '1' + random(8), 255); 		  //Ghost sound + what to do primpt
	  
      bumpHits = 3;                                       //How many hits to beat this ghost
      bumpValue = 5000000;                                //Starts at 5 million
      modeTimer = cycleSecond3;                           //A bit of time for the ball to come back 
      
      customScore('J', '0' + bumpType, 'B', allowAll | loopVideo);	          //Ghost dancing score display	        
      numbers(8, numberScore | 2, 0, 27, player);	                            //Show player's score lower left 
      numbers(9, 2, 52, 18, bumpHits);	                                      //Show # of hits left  
      
      playMusic('U', 'B');								 //Ghost Found Music 1
	  
      if (bumpValue > 9999999) {              			//Position different if 7 or 8 digits
        numbers(10, 2, 12, 7, bumpValue);					         //Current value                  
      }
      else {
        numbers(10, 2, 14, 7, bumpValue);					         //Current value       
      }
    }
    else {
      
      bumpHits -= 1;
      lightSpeed += 1;                                      //Blink lights faster!
      lightningStart(5998);							                            //No lightning if last hit
      
      if (bumpHits) {                                       //Not dead yet?     
        video('J', '0' + bumpType, 'C', noExitFlush, 0, 255);         //Ghost whacked!
        AddScore(bumpValue);
        numbersPriority(0, numberFlash | 1, 255, 6, bumpValue, 254);	//Set this to what we just scored
        videoQ('J', '0', '5', noEntryFlush | allowLarge, 0, 254);		  //Score value animated frame        
        numbers(9, 2, 52, 18, bumpHits);	                            //Show # of ghosts left to beat
        playMusic('U', 'A' + lightSpeed);						                  //Increase the music pitch each time we hit the ghost (use lightspeed as it's going in the right direction unlike BumpHits)	  
        playSFX(0, 'J', 'G', '1' + random(6), 255);			              //Ghost wail!
        playSFX(1, 'J', 'H', '0' + bumpHits, 255);			              //Team leader says how many hits are left	(and will stop Timer Beep if active)	
        modeTimer = cycleSecond3;                           //A bit of time for the ball to come back before timer starts going down again
      }
      else {                                                //Dead!
        //volumeSFX(3, musicVolume[0], musicVolume[1]);       
        bumpHits = 10;                                      //Reset this so we're once again looking for ghosts         
        light(photoLights[bumpWhich], 0);                   //Turn off the blinking light
     
        modeTimer = 70000;                                   //Reset for Giving Player Shit
     
        int x = bumpWhich;
        
        while (x == bumpWhich) {                              //Pick a new location but make sure it's not the same one twice          
          bumpWhich = random(5);            
        }
        
        bumpGhosts -= 1;                                      //Decrement how many are left
        lightSpeed = 1;								                        //Reset light speed	 
        
        if (bumpGhosts) {                                     //If still ghosts left, show what we need to do
        
          setCabModeFade(10, 10, 10, 300);				    //Dark lighting on purpose (maybe the game is broken?) 
          GIpf(B00000000);
          
          playMusic('U', 'A');						                    //Go back to Bumps search beat
          killQ();
          video('J', '0' + bumpType, 'D', noExitFlush, 0, 255);         //Ghost killed!
          AddScore(bumpValue);

          playSFX(0, 'J', 'J', '1' + random(6), 255);			//Ghost dies!
          playSFX(1, 'J', 'K', '0' + bumpGhosts, 255);		//Team leader says how many GHOSTS are left			  

          numbersPriority(0, numberFlash | 1, 255, 6, bumpValue, 254);	//Set this to what we just scored
          videoQ('J', '0', '5', noEntryFlush | allowLarge, 0, 254);		  //Score value animated frame     
          customScore('J', '0', '1', allowAll | loopVideo);		//MAKE SHOTS FIND GHOSTS prompt
          numbers(8, numberScore | 2, 0, 27, player);	        //Show player's score lower left 
          numbers(9, 2, 86, 21, bumpGhosts);	                //Show # of ghosts left to beat  
          numbers(10, 9, 88, 27, 0);					                //Ball # lower right	     
        }
        else {
          bumpWin(); 												//All ghosts dead, WIN condition!                      
        }
      }    
    }      
  }
  else {
  
    if (bumpHits == 10) {                           //A wrong shot, and we haven't found ghost yet?
      modeTimer = 75000;                            //A bit of time before giving player shit again...
      //playSFX(1, 'J', 'C', '0', 255);	
      playSFX(0, 'J', 'C', '1' + random(8), 255);	  //Team leader tells you to look elsewhere      
      video('J', '0', '2', 0, 0, 255);              //No ghost found here!        
    }
    else {                          //Else, we know where the ghost is, and the player missed it!   
      //playSFX(2, 'J', 'Z', '0', 255);               //Avoid channel 1 so if the timer beep is going we still here it	
      playSFX(0, 'J', 'Z', '1' + random(8), 255); 	//Heather gives you shit for missing         
      video('J', '0', '3', 0, 0, 255);      //You missed!      
    }       
  }  
  
}

void bumpWin() {

	subWon[player] = subWizWon;                //You did it!

	lightSpeed = 1;									          //Normal light speed

	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();	

	setCabModeFade(defaultR, defaultG, defaultB, 100);				    //Reset cabinet color
  //volumeSFX(3, musicVolume[0], musicVolume[1]);                 //Reset music volume 
	playMusic('M', '2');							                            //Normal music

	AddScore(bumpValue);                                          //Add this manually so we see the total score at the end
	killQ();
	video('J', '0' + bumpType, 'D', noExitFlush, 0, 255);         //Ghost killed!
	
	playSFX(0, 'J', 'J', '1' + random(6), 255);			//Ghost dies!
	playSFX(1, 'J', 'L', '1' + random(4), 255);		//We fuckin' did it!	

	numbersPriority(0, numberFlash | 1, 255, 11, modeTotal, 254);	//Load Mode Total Points
	videoQ('J', 'Z', 'Z', noEntryFlush | allowLarge, 0, 254);		  //Mode Total:	  

	Mode[player] = 0;						                                  //Set mode to ZERO
	Advance_Enable = 1;						                                //Can advance	
	modeTotal = 0;								                                //Reset mode points	
  
	GIpf(B11100000);
	
	checkModePost();	
	hellEnable(1);
	spiritGuideEnable(1);						                              //Re-enable spirit guide

	showProgress(0, player);					                            //Show the Main Progress lights

}

void bumpFail() {                    //End the mode properly should player drain during it (it can't time out)
  
 	multipleBalls = 0;
  
  volumeSFX(3, musicVolume[0], musicVolume[1]);                 //Reset music volume 
  
	lightSpeed = 1;									//Normal light speed
	tourClear();								//Clear the tour lights / values	
	
	loadLamp(player);								//Load the original lamp state back in
	comboKill();

	spiritGuideEnable(1);

	ghostModeRGB[0] = 0;
	ghostModeRGB[1] = 0;
	ghostModeRGB[2] = 0;
	ghostFadeTimer = 100;
	ghostFadeAmount = 100;
	setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color
	GIpf(B11100000);
  
	ghostLook = 1;													//Ghost will now look around again.
	ghostAction = 0;
	
	killNumbers();
	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();	
	
	light(7, 0);	//Turn off all CAMERA LIGHTS
	light(14, 0);
	light(23, 0);
	light(39, 0);
	light(47, 0);
	
	light(16, 0);													//Turn off Ghost Lights
	light(17, 0);
	light(18, 0);
	light(19, 0);

	ElevatorSet(hellDown, 100); 									//Make sure Hellavator is down
	light(25, 7);													//Current state is SOLID
	blink(24);														//Other state BLINKS
	light(30, 0);													//Lock is NOT lit
	modeTotal = 0;													//Reset mode points
	
	Mode[player] = 0;												//Set mode active to None	
	Advance_Enable = 1;												//Other modes can start now
	
	showProgress(0, player);					//Show the Main Progress lights	

	checkModePost();
	hellEnable(1); 
  
}

void burstLoad() {
  
  if (burstReady == 0) {            //Not lit yet? (possible double enable in MB condition)
    burstLane = 0;                  //Clear this
    laneChange();                   //Update lanes
    burstReady = 1;
    video('O', 'Z', '0' + ghostBurst, allowAll, 0, 250);					//Ghost Burst Loaded x2-x9
    playSFX(2, 'O', 'B', 'A', 255);				//Sound
  }
  
}

void callButtonLogic() {						//What to do when player hits Call Elevator button. Mostly, when you CAN'T control it for MB

	if (hellLock[player] == 0) {
		AddScore(10000);
		playSFX(2, 'H', '0', '0', 100);				//Door clunking sound
		return;
	}

	if (Mode[player] == 1 and patientStage) {						//In hospital, trying to poison ghosts?
		AddScore(10000);	
		playSFX(2, 'H', '0', '0', 100);				//Door clunking sound
		return;														//Can't move it
	}

	if (Mode[player] == 7) {					//Hotel mode uses elevator too much, so no MB with it
		AddScore(10000);	
		playSFX(2, 'H', '0', '0', 100);				//Door clunking sound
		return;
	}
	
	if (theProgress[player] > 3 and theProgress[player] < 100) {	//Doing Theater mode?
		AddScore(10000);
		playSFX(2, 'H', '0', '0', 100);				//Door clunking sound
		return;
	}

	if (hotProgress[player] > 2 and hotProgress[player] < 100) {	//Doing or about to start Hotel mode?
		AddScore(10000);	
		playSFX(2, 'H', '0', '0', 100);				//Door clunking sound
		return;
	}	
	
	if (deProgress[player] > 0 and deProgress[player] < 100) {		//In wizard mode?
		AddScore(10000);	
		playSFX(2, 'H', '0', '0', 100);				//Door clunking sound
		return;
	}
	
	//If none of those, then you can control it

	if (HellLocation == hellDown) {									//If Hell was DOWN, move it UP	
	
		AddScore(25000);
		
		if (multiBall & multiballHell) {							//Hellavator multiball mode active?
			video('Q', 'J', 'A', B00000001, 0, 200);				//Jackpot ready!
			//playSFX(2, 'Q', 'J', 'A', 200);
			playSFX(2, 'Q', 'E', 'A' + random(6), 200);				//Sound + Jackpot Ready!
			blink(41);												//Hell flasher
      
			blink(26);                        //Jackpot light we blink all the lights (for grow, we strobe them)
			blink(27);
			blink(28);
			blink(29);
			//strobe(26, 4);											//Strobe the first 4 lights
			blink(30);												//Blink LOCK. Sort of makes sense.
			
			light(24, 0);											//In MB, once up, Hellavator can't be moved
			light(25, 0);											//So turn off both lights		
			
			if (hellMB) {
				customScore('Q', 'B', 'B', allowAll | loopVideo);	//Custom Score: JACKPOT READY!
			}
			
		}
		else {
		
			light(24, 7);											//Current state is SOLID
			blink(25);												//Other state BLINKS		
		
			video('Q', 'A', 'B', B00000001, 0, 200);				//Hellavator Lock is Lit!
			playSFX(2, 'Q', 'A', 'B', 210);
			
			pulse(30);												//Elevator UP, Lock is lit! (and so am I!)

			blink(41);												//Flash Hellavator flasher
			light(26, 0);											//Clear hotel progress lights
			light(27, 0);
			light(28, 0);
																	//Show multiball progress
			if (lockCount[player] == 0) {							//No balls locked?
				blink(26);											//Blink "1"
			}																	
																	
			if (lockCount[player] == 1) {							//One ball locked already?
				light(26, 7);										//1 solid, blink 2
				blink(27);
			}
			if (lockCount[player] == 2) {							//Two balls locked?
				light(26, 7);										//1 and 2 solid, blink 3
				light(27, 7);
				blink(28);
			}
		}
		
		ElevatorSet(hellUp, 100); 	//Send Hellavator to 2nd Floor.
		
	}
	
	if (HellLocation == hellUp) {									//If Hell was UP, move it DOWN (unless Hell MB active awaiting Jackpot)
	
		AddScore(25000);
	
		if (multiBall & multiballHell) {							//Hellavator multiball mode active? Don't let button do ANYTHING (keep hellavator UP)
			video('Q', 'A', '6', B00000001, 0, 200);				//Right Ramp Builds value!
			playSFX(2, 'H', '0', '0', 100);							//CLUNK!
			strobe(26, 5);											//Strobe first 5 lights	
		}
		else {
			light(25, 7);											//Current state is SOLID
			blink(24);												//Other state BLINKS					
			ElevatorSet(hellDown, 100); 							//Send Hellavator to 1st Floor.		
			light(26, 0);											//Turn off lights. We'll rebuild them for Hotel progress
			light(27, 0);
			light(28, 0);	
			light(29, 0);
			light(30, 0);											//Turn off LOCK
				
			light(41, 0);											//Turn off Hell Flasher
		
			playSFX(2, 'Q', 'A', 'A', 210);							//Sound no matter what!
		
			if (Advance_Enable) {									//Modes can be advanced, and Hotel hasn't been won yet?
				if (hotProgress[player] < 100) {					//Able to advance hotel?
					if (hotProgress[player] == 0) {
						pulse(26);
						light(27, 0);
						light(28, 0);
						light(29, 0);		
					}
					if (hotProgress[player] == 1) {
						light(26, 7);
						pulse(27);
						light(28, 0);
						light(29, 0);		
					}
					if (hotProgress[player] == 2) {
						light(26, 7);
						light(27, 7);
						pulse(28);
						light(29, 0);		
					}		
					if (hotProgress[player] == 3) {
						light(26, 7);
						light(27, 7);
						light(28, 7);
						pulse(29);		
					}	
					video('Q', 'A', 'A', B00000001, 0, 200);				//Advance Hotel Open!
				}
				else {														//Hotel already complete!
					light(26, 0);
					light(27, 0);
					light(28, 0);
					light(29, 0);
					video('Q', 'A', 'C', B00000001, 0, 200);				//Path Open!
				}					

			}
			else {
				video('Q', 'A', 'C', B00000001, 0, 200);					//Path Open!				
			}	
		}
	}
	
}

void centerPathCheck() {						//When a ball is shot up the middle, and hasn't fallen from the jump ramp

	animatePF(210, 10, 0);
  
  if (Mode[player] == 8) {              //Bumps in the night?
    bumpCheck(2);                       //Check that function and return out
    return;
  }
  
	if (hellMB and minion[player] < 100) {
		tourGuide(1, 8, 2, 50000, 1);						//Check for GHOST CATCH
		return;
	}	

	if (Mode[player] == 6) {					//Prison?
		tourGuide(2, 6, 2, 25000, 1);			//Check that part of the tour!
		return;
	}			

	if (hotProgress[player] > 29 and hotProgress[player] < 40) {	//Fighting the Hotel Ghost? (can't do tour during the Control Box search)
		tourGuide(2, 5, 2, 25000, 1);			//Check that part of the tour!	
		return;
	}			

	if (Mode[player] == 4) {					//War fort?
		int x = random(8);
		playSFX(0, 'W', '5', 'A' + x, 210);						//Random Army Ghost lines
		if (tourGuide(2, 4, 2, 25000, 0) == 0) {
			video('W', '5', 'A' + x, allowSmall, 0, 250);		//Synced taunt video
		}														//Check that part of the tour (no WHOOSH sound needed)		
		return;
	}			
	
	if (barProgress[player] > 69 and barProgress[player] < 100) {					//Haunted Bar?
		tourGuide(1, 3, 2, 25000, 1);			//Check that part of the tour!
		return;
	}
	
	if (Mode[player] == 1) {					//Hospital?
		tourGuide(2, 1, 2, 25000, 1);			//Check that part of the tour!
		return;
	}

	if (deProgress[player] > 9 and deProgress[player] < 100) {				//Trying to weaken demon
		DemonCheck(2);
		return;
	}
	
	if (hotProgress[player] == 20)	{			//Searching for the Control Box?
		BoxCheck(2);							//Check / flag box for this location
		return;
	}

	if (Mode[player] == 7) {					//Are we in Ghost Photo Hunt?
		photoCheck(2);
		return;
	}

	if (theProgress[player] > 9 and theProgress[player] < 100) {		//Theater Ghost?		
		TheaterPlay(0);							//Incorrect shot, ghost will bitch!
		return;
	}

  if (Advance_Enable and middleWarBar) { //Is no mode active? And is center shot set to advance pops?
  
    if (popMode[player] == 1) {					//Advancing Fort?		
      if (fortProgress[player] < 50) {			
        WarAdvance(middleWarBar);
      }											
    }	
    if (popMode[player] == 2) {					//Advancing Bar?
      if (barProgress[player] < 50) {			
        BarAdvance(middleWarBar);
      }		
    }				
    
    return;                         //Don't do normal scoring in this case
    
  }
  
	AddScore(50000);									//50k points up the center to make shot satisfying!
	playSFX(2, 'E', 'Z', '1' + random(3), 225);		//Default Thunder sound!	
	lightningStart(5998);							//Lightning FX	
	
}

void checkRoll(unsigned char glirHit) {								//Check GLIR rollovers for completion

	//Set GLIR lights to what they should be
	
	laneChange();

	if (Mode[player] == 7) {										//Are we IN a photo hunt?
		
		if (rollOvers[player] == B11111111) {
      if (glirHit == 1) {                     //Were we sent here via a switch hit, and not just a random update?
        suppressBurst = 1;                    //Make sure this doesn't Ghost Burst         
      }      
			AddScore(100000);										    //100k points for spelling it during Photo Hunt!
			rollOvers[player] = 0;									//Clear rollovers
			blink(52);												      //Blink GLIR for a bit
			blink(53);
			blink(54);
			blink(55);
			displayTimerCheck(89999);								//Check if anything was running, set new value
			playSFX(2, 'F', '1', 'N', 201);					//Modified version of the "X More to Light Photo Hunt" sound
     
      photoAdd[player] += 100000;             //Add to this value  
      video('F', 'I', 'I', allowAll, 0, 255);						      //Increase Photo Value   
			numbers(7, numberFlash | 1, 255, 11, photoAdd[player]);	//The added value         
		}
		
		return;														//OK, don't get to do anything else!
	}

  if (glirHit == 1) {                     //Were we sent here via a switch hit, and not just a random update?
    suppressBurst = 1;                    //Make sure this doesn't Ghost Burst, since this function will score "something" no matter what         
  }  	
	
	if (GLIR[player] > 0 and rollOvers[player] == B11111111) {		//GLIR spelled, not triggered yet?
	
		if (GLIRlit[player] == 0) {									//Haven't earned a Photo Hunt yet?

			GLIR[player] -= 1;										//Decrease spell counter
					
			if (GLIR[player] == 0) {								//Did we spell GLIR enough times?
      
				if (GLIRneeded[player] < 9) {
					GLIRneeded[player] += 1;							//Increase target #	needed, max is 9		
				}
        
				GLIR[player] = GLIRneeded[player];						//Set counter to new target #
				GLIRlit[player] = 1;									//Flag set - can be started!			
				rollOvers[player] = 0;									//Clear rollovers
				blink(52);												//Blink GLIR for a bit
				blink(53);
				blink(54);
				blink(55);
				displayTimerCheck(89999);								//Check if anything was running, set new value			
				AddScore(20000);        
				//Can it be started, or must we wait?
				if (Mode[player] == 0 and Advance_Enable == 1) {			//Able to start a mode?		
					playSFX(0, 'F', '1', 'A' + random(4), 200);				//"Photo Hunt is Lit!" prompt. Higher priority, will override normal rollover sound
					video('F', '1', 'A', B00000001, 0, 200);				//GLIR, photo hunt is lit!							
					showScoopLights();										//Update scoop lights	
					animatePF(30, 14, 0);									//GLIR whoosh animation	
				}
				else {														//Have to wait until mode is over?
					playSFX(0, 'F', '1', 'E' + random(4), 200);				//Ghost Locating Infrared Ready!					
					video('F', '1', 'B', allowSmall, 0, 200);				//Photo Hunt ready after mode ends					
				}				
			}
			else {															//Reset GLIR lights, prompt how many more spells to light PHOTO HUNT
				playSFX(2, 'F', '1', 'I', 200);								//Need to spell it again sound FX		
				video('F', 'S', '0' + GLIR[player], allowSmall, 0, 200);	//SPELL GLIR X MORE TIMES TO LIGHT PHOTO HUNT 
				AddScore(20000);
				rollOvers[player] = 0;										//Clear rollovers
				blink(52);													//Blink GLIR for a bit
				blink(53);
				blink(54);
				blink(55);
				displayTimerCheck(89999);									//Properly end anything that may already be using the timer	
			}
		}
		else {														          //If we already lit Photo Hunt, just award points & time
      video('F', 'I', 'J', allowAll, 0, 255);						      //More seconds!   
			playSFX(2, 'F', '1', 'M', 200);			                    //Modified version of the "X More to Light Photo Hunt" sound	
			photoSecondsStart[player] += 2;                         //Add some sections      
      AddScore(20000);
			rollOvers[player] = 0;							//Clear rollovers
			blink(52);												  //Blink GLIR for a bit
			blink(53);
			blink(54);
			blink(55);
			displayTimerCheck(89999);						//Properly end anything that may already be using the timer	
		}	
	}
	else {
		video('F', 'X', '@' + (rollOvers[player] & B00001111), allowSmall, 0, 200);		//Show what letters we have earned thus far (whenever a rollover is hit, even if hit already)
    AddScore(5010);
	}
	
}

void checkSubWizard() {           //See if there's enough to light Sub Wizard mode

  //Serial.print("Sub Wizard = ");
  //Serial.println(subWon[player], BIN);

  if (subWon[player] == B00000111) {   //Did we get all 3, and is this the first time we've checked? (MSB is clear?)
  
    subWon[player] |= B10000000;      //OR in the MSB which says we've checked

    pulse(50);                        //PULSE the 3 mode lights to indicate we're ready
    pulse(49);
    pulse(2);
    showScoopLights();
    
    //Serial.println("SUB WIZARD ENABLED");    
    
  }

}                  

void checkModePost() {							//After a mode is over, check to see if we need to do anything

	doorLogic();								//Figure out what to do with the door

	checkRoll(0);								//See if we enabled GLIR Ghost Photo Hunt during that mode

	elevatorLogic();							//Did the mode move the elevator? Re-enable it and lock lights

	targetLogic(1);								//Where the Ghost Targets should be, up or down. In most cases, also see if we should reset Minion

	popLogic(0);								//Figure out what mode the Pops should be in

}

void checkOrb(int videoYes) {					//See if ORB has been completed					

	if ((orb[player] & B00111111) != B00111111) {				//Not all ORB lanes complete?
	
		if (videoYes) {
			playSFX(1, 'O', 'R', random(2) + 65, 100);								//The orb that will repopulate the Earth. Nobody knows how it works. Only that it does.	
			video('O', 'R', 64 + (orb[player] & B00000111), allowSmall, 0, 250); 	//Play video of what IS lit. Lower than skill shot priority
		}
			
		laneChange();

	}
	else {														//All lit? Advance multipler!

		if (bonusMultiplier < 1) {								//9 is the limit
			bonusMultiplier = 1;									//If for some reason it's ZERO, make sure it's at least 1
		}
		
		bonusMultiplier += 1;									//Increase the Bonus Multipler
		
		if (bonusMultiplier > 9) {								//9 is the limit
			bonusMultiplier = 9;
		}
		
		playSFX(1, 'O', 'R', 'C', 110);							//Rollover + WIN sound! (Slightly higher priority)
		video('O', 'R', 48 + bonusMultiplier, allowSmall, 0, 250); 		//Play OR ASCII 48 + multipler (2-9 ASCII)		
		blink(32);												//Blink ORB
		blink(33);
		blink(34);
		displayTimerCheck(44999);								//Properly end anything that may already be using the timer			
		orb[player] = 0;										//Clear player's ORB variable so it can be reset even during the flash
	}


}

void checkOrbAdd() {						          //Add an ORB letter to first empty spot (driven by X sling hits)

	unsigned char orbFill = B00001001;		  //The value to check / fill in

  unsigned char abortLoop = 0;
  
	for (int x = 0 ; x < 3 ; x++) {			    //Checking all 3 bits, starting from LSB

    if (abortLoop == 0) {
      if ((orb[player] & orbFill) == 0) {	//Bit isn't here?			
        orb[player] |= orbFill;			      //Fill it in...			
        abortLoop = 1;							      //and cancel out rest of loop (so we don't add more than just 1)
      }
      else {								              //There IS a bit there already?
        orbFill <<= 1;					          //Bitshift the fill mask to the left and check next bit			
      }      
      
    }

	}
  
	checkOrb(1);						  //See what we got!
	
}

void checkStartButton(unsigned char runType) {

	if (cabSwitch(Coin)) {						//Coin detected?
		
		//coinsIn += 1;
		
    pulses += pulsesPerCoin;        //Add the number of pulses for one coin 
		coinsInserted += 1;						      //Master counter for moolah!
		
    if (pulses >= pulsesPerCredit) {    //Enough for a credit?
      if (credits < 99) {               //Add up to 99 credits!
        credits += 1;
      }	
      pulses -= pulsesPerCredit;        //Subtract the pulses (leave remainder)
      playSFX(0, 'X', 'C', 'Z', 255);		//New THANKS FOR YOUR MONEY SUCKER sound!	      
    }
    else {
      playSFX(0, 'X', 'C', 'Y', 255);		//New single coin sound    
    }
    
    //Serial.print("PULSES: ");
    //Serial.println(pulses, DEC);
    
    /*
		if (coinsIn == coinsPerCredit) {
			coinsIn = 0;
			playSFX(0, 'X', 'C', 'Z', 255);			//New THANKS FOR YOUR MONEY SUCKER sound!	
			credits += 1;
			if (credits > 99) {
				credits = 99;									//Once I would have asked "why would anyone try this?" but now I know better
			}					
		}
		else {
			playSFX(0, 'X', 'C', 'Y', 255);			//New single coin sound           
		}    
    */
    
    if (runType) {                  //A game is running? Don't do anything to the video
      Update(0);										//Updates freeplay and coins.		
    }
    else {
      Update(1);										//Updates freeplay and coins, attract mode to PRESS START! (or INSERT COINS)
      stopVideo(0);                 //Stops whatever is playing, so screen will jump right to PRESS START
    }	    
  
	}

	if (cabSwitch(Start)) {		
		if (runType) {								//Game running already? Have at least started Player 1?
			//if (ball == 1 and numPlayers < 4) {		//Can we add a player?
			if (ball == 1) {						//Can only add players on Ball 1
				if (freePlay == 0) {				//Not on freeplay?
					if (credits) {					//Then we need a credit
						credits -= 1;
						addPlayer();
						Update(0);
					}
				}
				else {								//If on freeplay, go for it!
					addPlayer();					//Add player will handle past 4 players
					Update(0);						//Update credits					
				}										
			}
		}
		else {									//Game wasn't running? Start of the game with Player 1
			if (countBalls() == 4 or (startAnyway == 2 and ballsInGame == 3 and switchDead == 0)) {	//Should have 4 balls to start. Can start with 3 if you try enough times
				if (freePlay == 0) {				//Not on freeplay?
					if (credits) {					//Then we need a credit
						credits -= 1;
						run = 1;					//Set condition to advance game
						Update(0);					//Turn off attract mode		
					}
				}
				else {								//If on freeplay, go for it!
					run = 1;					//Set condition to advance game
					Update(0);					//Turn off attract mode						
				}					
			}
			else {
				ballsInGame = countBalls();
				
				if (switchDead == 0) {						//Only start a search if one isn't running
					video('A', 'B', '0' + (4 - countBalls()), 0, 0, 255);	//LOAD 1-4 MORE BALLS
					playSFX(2, 'H', '0', '0', 255);							//Door clunking sound
								
					startAnyway += 1;
					if (startAnyway == 2) {					//Two failed attempts?
						creditDot = 1;						    //Something must be wrong!
            saveCreditDot();              //Make sure it sticks in EEPROM
					}				
					switchDead = deadTop - 5;				//Do a ball search cycle
					myservo[Targets].write(TargetUp);		//Put targets down
					myservo[HellServo].write(hellUp); 		//Hellavator down
					myservo[DoorServo].write(DoorClosed); 	//Open Door					
				}
			}	
		}
	}
	
}

void comboCheck(int whichShot) {

	comboVideoFlag = 0;												//The default is a standard combo. If we're not in a mode, and that shot advance is complete, it'll do Ghost Catch Combo instead

	if (comboTimer > 0 and comboShot == whichShot) {				//Did we hit the Combo?

		comboVideoFlag = 1;											//Default is a normal combo, but check if it isn't
	
		if (ghostBurst < 9) {    
		  ghostBurst += 1;                       //Increase this! (up to 9x)
		  if (burstLane == 0 and burstReady == 0) {                  //No lane lit yet, and not in the middle of a shot?
        burstLane = 52;                       //Set as leftmost
        laneChange();                        //Make sure it lights right away        
		  }
		}

		if (Advance_Enable) {										//Not in a mode? See if this shot advance has been completed yet
		
			switch (whichShot) {
				case 0:												//Left orbit, and Prison is complete?
					if (ModeWon[player] & prisonBit) {
						comboVideoFlag = 0;
						video('C', 'G', 'A', allowSmall | noEntryFlush | noExitFlush, 0, 255);	//Left net catch					
					}
					break;
				case 1:
					if (ModeWon[player] & hospitalBit) {				//Door VUK, and Hospital is complete?
						comboVideoFlag = 0;
						video('C', 'G', 'A', allowSmall | noEntryFlush | noExitFlush, 0, 255);	//Left net catch					
					}
					break;
				case 2:
						//comboVideoFlag = 0;
						//video('C', 'G', 'A' + random(2), allowSmall, 0, 255);	//Left or right net catch						
					break;
				case 3:
					if (ModeWon[player] & hotelBit) {				//Hotel path, and hotel complete?
						comboVideoFlag = 0;
						video('C', 'G', 'B', allowSmall | noEntryFlush | noExitFlush, 0, 255);	//Right net catch					
					}
					break;
				case 4:
					if (ModeWon[player] & theaterBit) {				//Theater jump, and Theater complete?
						comboVideoFlag = 0;
						video('C', 'G', 'B', allowSmall | noEntryFlush | noExitFlush, 0, 255);	//Right net catch					
					}
					break;
			}
		
		}
	
		if (comboVideoFlag) {											//Default combo?
		
			if (whichShot == 2 and middleWarBar == 0) {	//Combo up middle? Make sure it won't override Pop Graphics and mess up numbers or progress bars
				//The exception being if middle shot is allowed to advance War/Bar, in which case make sure combo flag IS set...
        comboVideoFlag = 0;										    //Allow pops video to override Combo indicator
			}
			
			//videoCombo('C', 'O', 48 + comboCount, allowSmall | noEntryFlush | noExitFlush, 0, 255);	//Combo Video (1x to 5x)
      
			videoCombo('C', 'B', 48 + comboCount, allowSmall | noEntryFlush | noExitFlush, 0, 255);	//Combo Video (1x to 9x)        
			numbersPriority(3, 2, 83, 26, ghostBurst, 255);					//Send numbers with current EVP value, and it will only display on videos matching this priority		
		
			playSFX(1, 'C', 'O', 48 + comboCount, 200);					//Combo sound FX	
			
			if (comboCount == 9) {										//Max combo? Double points, reset # combos
				AddScore((comboCount * comboScore) * 2);
				comboCount = 1;
			}
			else {														//Normal points, increase combos
				AddScore(comboCount * comboScore);
				comboCount += 1;
			}						
		}
		else {
			killQ();			
			videoQ('C', 'G', 48 + comboCount, allowSmall | noEntryFlush | noExitFlush, 0, 255);		//Enqueue Combo X Indicator (1 to 9) to appear after Net Catch
			playSFX(1, 'C', 'C', 65 + random(10), 200);					//Net whoosh + scream Combo sound FX
			
			if (comboCount == 9) {										//Max combo? Double points, reset # combos
				AddScore((comboCount * comboScore) * 2);
				comboCount = 1;
			}
			else {														//Normal points, increase combos
				AddScore(comboCount * comboScore);
				comboCount += 1;
			}		

		}

		light(photoLights[comboShot], 0);							//Turn that light off			

	}

}

void comboKill() {

	if (comboTimer) {
	
		for (int x = 0 ; x < 6 ; x++) {
			light(photoLights[x], 0);				//Turn off the 6 camera positions	
		}
	
		light(photoLights[comboShot], 0);		//Turn off existing light, if any
		comboCount = 1;							//Reset # of combos
		comboVideoFlag = 0;						//Reset video flag
		comboShot = 99;							//Set target shot to out of range	
		comboTimer = 0;
		
	}
	
}

void comboSet(unsigned char whichShot, int howMuchTime) {		//Sets the next combo shot, and how much time you get for it

	if (comboEnable == 0) {
		return;
	}
	
	if (comboTimer) {
		if (tourLights[comboShot] == 0) {		//If the previous Combo Icon isn't flashing for a Tour mode...
			light(photoLights[comboShot], 0);	//Turn off previous Combo Shot Lamp			
		}	
	}
	
	comboTimer = howMuchTime;									//Set timer. Default was 80000 cycles, about 3.5 seconds
	
	comboShot = whichShot;										//Set location of what shot to hit for combo
	
	blink(photoLights[comboShot]);								//Blink that light!

}

int countBalls() {								//Counts the balls in the trough

	int x = 0;									//Balls found
	int xx = B00001000;							//Bit to check

	while (xx != B10000000) {
		if (xx & switches[7]) {					//Is there a ball there?
			x += 1;								//Up the count
		}
		xx <<= 1;								//Bitshift to the left
	}

	return x;									//Return how many balls we found

}

int countGhosts() {								//Returns how many Ghost Bosses have been beaten

	unsigned char howMany = 0;
	unsigned char bitChecker = B01000000;
	
	for (int x = 0 ; x < 6 ; x++) {
		if (ModeWon[player] & bitChecker) {
			howMany += 1;
		}
		bitChecker >>= 1;	
	}
	
	return howMany;

}


//Functions for Demon Battle Wizard Mode 10........................
void DemonLock1() {								//Wizard Mode Started!

  if (demonMultiplier[player] < 1) {    //Just in case something WEIRD happened
    demonMultiplier[player] = 1;
  }
  
  if (demonMultiplier[player] > 4) {
    demonMultiplier[player] = 4;
  }  

	AddScore(advanceScore * demonMultiplier[player]);
	comboKill();
	storeLamp(player);							//Store and clear lamps
	allLamp(0);

	minionEnd(0);
	
	DoorSet(DoorClosed, 500);					//Close the door slowly
	trapDoor = 1;								//Flag that ball should be trapped behind door	
	TargetTimerSet(cycleSecond, TargetDown, 250);		//Put the targets down
	ElevatorSet(hellDown, 100); 				//Send Hellavator to 1st Floor.
	light(41, 0);
	
	updateRollovers();							//Update ORB and GLIR

	if (wiki[player] < 255) {
		pulse(0);
	}
	else {
		light(0, 7);
	}
	if (tech[player] < 255) {
		pulse(1);
	}
	else {
		light(1, 7);
	}	
	if (psychic[player] < 255) {
		pulse(51);
	}
	else {
		if (scoringTimer) {						//Double scoring active so the light blinks	
			blink(51);	
		}
		else {
			light(51, 7);						//Completed, so it's solid			
		}	
	}

	//comboEnable = 0;							//Combos during Control Box search would be confusing, so no	
	deProgress[player] = 2;						//Starting to lock balls
	
	Advance_Enable = 0;							//Mode started, disable advancement until we are done
	minionEnd(0);								//Disable Minion mode, even if it's in progress
	Mode[player] = 10;							//Set DEMON mode ACTIVE for player	
	spiritGuideEnable(0);						//No spirit guide
	hellEnable(0);								//No hellavator
	
	light(24, 0);								//Hellavator Call buttons OFF
	light(25, 0);
	
	light(13, 7);								//Fight Demon light SOLID!	
	blink(17);									//Flash ghost targets
	blink(18);
	blink(19);
	
	blink(63);									//Blink DEMON MODE light!
	
	GIpf(B01100000);
	
	playMusic('D', '1');						//Wind, rusty swing set
	playSFX(0, 'D', 'A', 'A' + random(3), 255);	//Mode start dialog
	killQ();									//Disable any Enqueued videos
	video('D', 'A', 'A', allowSmall, 0, 255);	//Ghost & Swing Set
	//numbers(0, numberScore | 2, 0, 27, player);	//Put player score
	//videoQ('D', 'A', 'B', allowSmall | loopVideo, 0, 255);	//Ghost & Swing Set, looping with Prompt
	
	customScore('D', 'A', '0' + demonMultiplier[player], allowSmall | loopVideo);				//Ghost & Swing Set prompt loop	
	
	//customScore('D', 'A', 'B', allowSmall | loopVideo);				//Ghost & Swing Set prompt loop
	numbers(8, numberScore | 2, 0, 27, player);					//Put player score	
				
	activeBalls -= 1;							//Remove a ball from being "Active"
	AutoPlunge(67500);							//Set flag to launch second ball		
	
	deProgress[player] = 2;						//We've locked the first ball. Now shoot for GHOST

	dirtyPoolMode(0);							//Switching to manual
	
	videoModeCheck();
	
	loopCatch = catchBall;						//Set flag that we want to catch the ball in the loop
	
	setCabModeFade(32, 0, 0, 350);				//Set mode color to DIM RED
	
}

void DemonLock2() {

	AddScore(advanceScore * demonMultiplier[player]);
	
	dirtyPoolMode(0);							//Disable dirty pool check (since we DO want to trap the ball)
	
	comboKill();
	
	//MagnetSet(100);							//Hold the ball	
	//TargetTimerSet(5000, TargetUp, 1);		//Put the targets up quickly
	
	trapTargets = 1;							//A ball is trapped on purpose!
	
	ElevatorSet(hellUp, 300); 					//Send Hellavator UP
	blink(41);
	
	light(16, 0);								//Turn off ghost lights
	light(17, 0);	
	light(18, 0);
	light(19, 0);
	
	GIpf(B00100000);
	
	modeTimer = 55000;							//Set high so timer doesn't decrement much during video
	
	strobe(26, 6);								//Strobe the HELLAVATOR shot
	
	playMusic('D', '2');						//LOUDER Wind, rusty swing set
	playSFX(0, 'D', 'B', 'A' + random(3), 255);	//Mode start dialog
	killQ();									//Disable any Enqueued videos
	video('D', 'B', 'A', allowSmall, 0, 255);	//Ghost & Swing Set
	//videoQ('D', 'B', 'B', allowSmall | loopVideo, 0, 255);	//Loop it!
	
	customScore('D', 'B', '0' + demonMultiplier[player], allowSmall | loopVideo);
	
	//customScore('D', 'B', 'B', allowAll | loopVideo);				//Ghost & Swing Set prompt loop
	numbers(8, numberScore | 2, 0, 27, player);					//Put player score
		
	activeBalls -= 1;							//Remove a ball from being "Active"
	AutoPlunge(67500);							//Set flag to launch second ball		
	
	deProgress[player] = 4;						//We've locked the second ball. Now shoot for HELLAVATOR
	
	setCabModeFade(64, 0, 0, 500);				//Set mode color to MEDIUM red
	
}

void DemonLock3() {

	AddScore(advanceScore * demonMultiplier[player]);

	killScoreNumbers();							//Don't leave score onscreen during demon intro

	comboKill();
	comboEnable = 0;							//Combos during Demon Hunt would be confusing
	setGhostModeRGB(255, 0, 00);				//Red demon ghost
		
	HellBall = 10;								//Flag to say elevator is in transit
	ElevatorSet(hellDown, 200);					//Move elevator down
	light(41, 0);
	DoorSet(DoorOpen, 50);						//Close the door

	light(26, 0);								//Turn off strobing Hellavator lights
	light(13, 0);								//Turn off FIGHT DEMON

	GIpf(B00000000);
	
	int x = random(3);							//Make sure audio and video match
	
	killQ();									//Disable any Enqueued videos		
	//playMusic('D', 'E');						//Until we get final music ready
	playSFX(0, 'D', 'C', 'A' + x, 255);			//Demon start dialog
	video('D', 'C', 'A' + x, allowSmall, 0, 255);

	customScore('D', 'D', 'L' + random(1), allowSmall | loopVideo);			//Ghost & Swing Set prompt loop
	numbers(8, numberScore | 2, 0, 0, player);					//Put player score	
	numbers(9, 9, 88, 0, 0);									//Ball # upper right
	
	activeBalls -= 1;							//Remove a ball from being "Active"
	
	deProgress[player] = 8;						//Waits for tunnel ball to hit scoop. Then, IT'S ON!

}

void DemonStart() {

	comboKill();

	modeTotal = 0;								//Reset mode points

	int x = 0;
	
	for (x = 57 ; x < 63 ; x++) {				//Pulse the MODE LIGHTS to serve as Demon Health Bar
		pulse(x);
	}

	
	if (countBalls() > 0) {
		AutoPlunge(90000);							//Set flag to launch 4th ball			
	}
	
	LeftTimer = 85000;							//Kick out the left VUK ball
	ScoopTime = 80000;							//Kick out right scoop ball
	TargetTimerSet(80000, TargetDown, 1);		//Put the targets down to release ball
	trapTargets = 0;							//No balls are trapped
	trapDoor = 0;
	dirtyPoolMode(1);							//In case a ball gets up there somehow

	for (x = 0 ; x < 6 ; x++) {
		photoLocation[x] = 0;							//Clear Control Box locations	
		light(photoLights[x], 0);						//Turn off the 6 camera positions
		light(photoLights[x] - photoStrobe[x], 0);		//Turn off the Strobe
	}

	photoCurrent = random(5);							//Random location, but NOT the scoop to start							
	photoLocation[photoCurrent] = 255;																//Set which one has the DEMON SHOT
	//pulse(photoLights[photoCurrent]);
	strobe(photoLights[photoCurrent] - photoStrobe[photoCurrent], photoStrobe[photoCurrent] + 1);		//Strobe as many under it as we can
		
	demonLife = 6;								//How many hits are left to go. Win when this reaches 0
	
	modeTimer = 95000;							//At the start, this times how long until Target bank goes back up (about one second after they go down)
	
	DoctorTimer = 80000;						//How much time you've got before the shot moves. They move faster the more you collect
	
	activeBalls	+= 3;							//Add the balls we've just released. The one being autolaunched will make it 4
	
	multipleBalls = 1;							//Brief ball saver
	saveTimer = 180000;							//Manually set this high as we wait for balls
	spookCheck();								//Check what to do with Spook Light
	//blink(56);								//Blink the SPOOK AGAIN light
		
	deProgress[player] = 9;						//DEMON BATTLE has begun! This will also cause the Left VUK ball to be kicked out (once leftTimer reaches 0)

	setCabModeFade(255, 0, 0, 200);				//Red lightning
		
}

void DemonState() {		//What sort of looping video the demon should be doing

	if (deProgress[player] == 20) {				//Jackpots FTW?			
	
		if (activeBalls == 1) {
			customScore('D', 'Z', 'Y', allowSmall | loopVideo);					//Demon almost dead, Hit to Win!			
		}
		else {
			customScore('D', 'J', '5' + random(1), allowSmall | loopVideo);		//Weak demon defense, left or right, Hit for JACKPOTS!
		}
	}
	else {
		customScore('D', 'D', 'L' + random(1), allowSmall | loopVideo);			//Normal Demon Defense, left or right, plus Prompt
	}
	
	//numbers(0, numberScore | 2, 0, 0, player);				//Show small player's score in upper left corner of screen

}

void DemonMove() {										//Change the demon's position

	int x = 0;

	for (x = 0 ; x < 6 ; x++) {
		photoLocation[x] = 0;							//Clear Control Box locations	
		light(photoLights[x], 0);						//Turn off the 6 camera positions
		light(photoLights[x] - photoStrobe[x], 0);		//Turn off the Strobe
	}

	x = photoCurrent;									//Set x to current location, so WHILE LOOP will execute at least once
	
	while (x == photoCurrent) {							//Don't select same location twice - so it always MOVES
		x = random(5);									//Don't select scoop			
	}
	
	photoCurrent = x;									//Update current location		
	photoLocation[photoCurrent] = 255;								//Set which one has the DEMON SHOT
	//pulse(photoLights[photoCurrent]);
	strobe(photoLights[photoCurrent] - photoStrobe[photoCurrent], photoStrobe[photoCurrent] + 1);	//Strobe the shot!
	
}

void DemonCheck(unsigned char whichSpot) {

	killQ();											//A lot of queued videos going on, so clear it each time
		
	if (deProgress[player] == 20) {
		AddScore(50000 * demonMultiplier[player]);								//Some points
		if (activeBalls == 1) {							//Only score jackpots with 2 or more balls
			video('D', 'Z', 'X', allowSmall | loopVideo, 0, 255);	//Hit Demon To Win!
			numbers(0, numberScore | 2, 0, 0, player);				//Show small player's score in upper left corner of screen			
		}
		else {
			video('D', 'J', '0', 0, 0, 230);	//Hit Demon for Jackpots! (lower priority than Jackpot Advance display)
			DemonState();			
		}
		playSFX(2, 'A', 'Z', 'Z', 255);					//Whoosh!
		return;											//Don't do this other stuff	
	}
		
	if (photoLocation[whichSpot] == 255) {				//Did we hit the demon?

		ghostFlash(50);
		flashCab(255, 255, 255, 10);			//Flash from black to Default Mode Color	
		AddScore((activeBalls * 1000000)  * demonMultiplier[player]);				//The more balls, the more points

		light(demonLife + 56, 0);						//Turn OFF the current light
		demonLife -= 1;									//Decrement
		if (demonLife == 0) {							//Did we beat him?
			lightSpeed = 1;								//Back to normal
			DemonDefeated();
		}
		else {											//Normal whacking dialog
			playSFX(0, 'D', '0' + demonLife, 'A' + random(3), 255);		//Random dialog, 3 for each of the hits (5-1)
			if (whichSpot < 3) {
				video('D', 'D', 'J', noExitFlush, 0, 255);	//Looks left
			}
			else {
				video('D', 'D', 'K', noExitFlush, 0, 255);	//Looks right
			}
			videoQ('D', 'D', '0' + demonLife, noExitFlush | noEntryFlush, 0, 255);
			DemonState();
			DemonMove();												//Change camera location
			DoctorTimer -= 7000;										//Targets move faster as you collect them
			modeTimer = DoctorTimer;									//Reset timer before next move
			lightSpeed += 1;											//Increase!
		}		
	}
	else {																//Miss!
		playSFX(0, 'G', 'T', 'A' + random(18), 255);					//Taunt player
		video('D', 'D', 'E' + random(1), allowSmall | noExitFlush, 0, 255);			//Demon taunt (left or right)
		DemonState();
		AddScore(2500 * demonMultiplier[player]);													//A few points
		flashCab(16, 0, 0, 75);										//Darker red flash
	}

}

void DemonJackpot() {

	killQ();
	ghostFlash(50);
	jackpotMultiplier = activeBalls;
	AddScore((EVP_Jackpot[player] * jackpotMultiplier) * demonMultiplier[player]);				//The 'mo balls the 'mo betta!
	playSFX(0, 'D', 'J', 'A' + random(7), 255);					//Jackpot sounds!
	video('D', 'J', '0' + activeBalls, noExitFlush, 0, 255);	//Bonus based off how many balls we have
	
	showValue((EVP_Jackpot[player] * jackpotMultiplier) * demonMultiplier[player], 40, 1);		//Show what jackpot value was
	DemonState();	
	ghostAction = 20000;										//Set WHACK routine.	
	lightningStart(100000);										//Demon lightning!
	
}

void DemonDefeated() {							//After you hit the 6 strobing shots, Defenses are down and it's JACKPOT time!

	TargetTimerSet(10, TargetDown, 1);			//Put the targets down to release ball	
	
	for (int x = 0 ; x < 6 ; x++) {
		photoLocation[x] = 0;							//Clear Control Box locations	
		light(photoLights[x], 0);						//Turn off the 6 camera positions
		light(photoLights[x] - photoStrobe[x], 0);		//Turn off the Strobe
	}
	
	deProgress[player] = 20;					//Now we're in BASH MODE!	
	strobe(17, 3);								//Strobe targets and pulse JACKPOT
	pulse(16);
		
	light(63, 7);								//DEMON BATTLE solid

	GIpf(B11100000);								//Lights back on!
	
	killQ();
	playSFX(0, 'D', '0', 'A' + random(3), 255);		//Defeat Dialog!
	video('D', 'D', '0', noExitFlush, 0, 255);		//Demon sad
	
	if (activeBalls == 1) {
		//videoQ('D', 'Z', 'X', allowSmall | loopVideo | noEntryFlush, 0, 255);	//Demon almost dead, Hit to Win!	
		//numbers(0, numberScore | 2, 0, 0, player);								//Show small player's score in upper left corner of screen	
		customScore('D', 'Z', 'X', allowSmall | loopVideo);					//Hit demon to WIN, then Demon on Ropes
		//DemonState();
		loopCatch = catchBall;													//Set that we're ready to catch the final ball
		multipleBalls = 0;
	}
	else {
		//videoQ('D', 'J', '0', noEntryFlush | noExitFlush, 0, 255);				//Hit Demon for Jackpots!	
		DemonState();
		multipleBalls = 1;												//When MB starts, you get ballSave amount of time to loose balls and get them back
	}	
		
	dirtyPoolMode(0);							//Disable dirty pool check (since we DO want to trap the ball)		
	winMusicPlay();						//One more time!
		
	ballSave();														//That is, Ball Save only times out, it isn't disabled via the first ball lost	
	
}

void DemonWin() {

	killQ();
	videoPriority(0);
	ghostFlash(50);
	lightningStart(1);
	AddScore((EVP_Jackpot[player] * (ballsPerGame - ball))  * demonMultiplier[player]);		//Extra points if you complete this on balls 1 or 2

	if (scoringTimer) {										    //Done?
		scoreMultiplier = 1;										//Multiplier done
		scoringTimer = 0;											  //Reset timer
		animatePF(0, 0, 0);											//Kill animations
		light(51, 7);												    //Light Psychic solid (done)
	}		
		
	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();		
	
	video('D', '0', '1', 0, 0, 255);							//Demon Death + End Credits	

	allLamp(0);
	light(63, 7);												//All lights off but DEMON BATTLE solid
	
	ghostAction = 20000;										//Set WHACK routine.	

	//musicVolume[0] = 80;										//Temp volume increase
	//musicVolume[1] = 80;
	//volumeSFX(3, musicVolume[0], musicVolume[1]);	
	
	setCabModeFade(defaultR, defaultG, defaultB, 2000);			//Reset to default color	
	
	playMusic('T', 'E');										//Until we get final music ready		
	TargetSet(TargetUp);										//Trap ball using targets
	
	deProgress[player] = 50;									//Flag that mode is won!

	animatePF(179, 10, 1);						//Center explode!	
	
	modeTimer = 300000;

}

void DemonFailLock() {							//What happens if you fail while trying to lock the 3 balls

	loopCatch = 0;								//Not trying to catch the ball
	killTimer(0);
	Coil(LeftVUK, vukPower);												//Kick out Ball 1
	TargetSet(TargetDown);											//Release Ball 2
	trapTargets = 0;							//No balls are supposed to be trapped now
	trapDoor = 0;
	
	DemonFail();	
		
}

void DemonFailBattle() {											//What happens if you fail while trying to clear the shots and get to demon

	multipleBalls = 0;
	TargetSet(TargetDown);											//Make sure balls don't get trapped
	lightningKill();
	
	DemonFail();	
	
}

void DemonFail() {													//General fail conditions for Demon Mode

	modeTimer = 0;
	lightSpeed = 1;													//Set this back to normal
	killNumbers();
	setGhostModeRGB(0, 0, 0);										//Turn off the Red Ghost
	setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color
	comboEnable = 1;												//Allow combos

	loadLamp(player);
	spiritGuideEnable(1);						//Allow Spirit Guide again
	
	light(16, 0);													//Turn off Ghost lights
	light(17, 0);
	light(18, 0);
	light(19, 0);
	
	light(26, 0);													//Turn off the strobing Hellavator lights
	light(63, 0);													//Haven't won it yet, turn it off
	
	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();	
	
	ghostMove(90, 10);												//Turn ghost back to center
	
	ghostLook = 1;													//Ghost will now look around again.
	ghostAction = 0;

	deProgress[player] = 1;											//You can restart this mode as many times as you want
	blink(13);														//Blink the light to restart
	Mode[player] = 0;												//Set mode active to None
	Advance_Enable = 1;												//Allow other modes to be started
	
	doorLogic();								//Figure out what to do with the door
	checkRoll(0);								//See if we enabled GLIR Ghost Photo Hunt during that mode
	elevatorLogic();							//Did the mode move the elevator? Re-enable it and lock lights
	popLogic(0);								//Figure out what mode the Pops should be in	

}
//END DEMON BATTLE FUNCTIONS

void demonQualify() {							//Check this after every mode, to see if we are ready to light WIZARD MODE DEMON BATTLE

	//All bosses beaten, MB started once, 3 minions defeated, and Photo Hunt completed once?
	
	//if (hitsToLight[player] > 1 and minionsBeat[player] > minionMB1) {
	
	if (ModeWon[player] == B01111110 and photosNeeded[player] > 3 and hitsToLight[player] > 1 and minionsBeat[player] > minionMB1) {

		deProgress[player] = 1;						//TEST DEMON MODE READY TO START
		blink(13);									//BLINK LIGHT
		doorLogic();
		videoSFX('D', '0', '0', allowSmall, 0, 255, 0, 'A', 'Z', 'Z' + random(2), 255);
		
	}
	
}

void doGhostActions() {


	if (ghostAction < 10001) {				//Guarding door?
		ghostAction -= 1;
		if (ghostAction == 5000) {
			ghostMove(5, 50);
		}
		if (ghostAction == 1) {
			ghostMove(15, 50);
			ghostAction = 10000;			
		}
		return;
	}
	
	if (ghostAction > 10000 and ghostAction < 20001) {				//Hit condition?
		ghostAction -= 1;

		if (ghostAction == 19999) {
			ghostMove(130, 5);
		}
		if (ghostAction == 18000) {
			ghostMove(110, 5);
		}
		if (ghostAction == 17000) {
			ghostMove(120, 5);
		}
		if (ghostAction == 16000) {
			ghostMove(80, 5);
		}
		if (ghostAction == 15000) {
			ghostMove(70, 5);
		}
		if (ghostAction == 14000) {
			ghostMove(80, 5);
		}
		if (ghostAction == 12000) {
			ghostMove(75, 5);
		}
		if (ghostAction == 10001) {
			ghostMove(90, 5);
			ghostAction = 0;
		}
		return;
	}

	if (ghostAction > 39999 and ghostAction < 100001) {				//War Fort Ball Hold?
		ghostAction -= 1;

		if (ghostAction == 99999) {
			ghostMove(110, 5);
		}
		if (ghostAction == 97999) {
			ghostMove(70, 5);
		}
		if (ghostAction == 95999) {
			ghostMove(110, 5);
		}
		if (ghostAction == 93999) {
			ghostMove(90, 5);
		}		
		if (ghostAction == 78000) {
			ghostMove(170, 20);
		}		
		if (ghostAction == 69000) {
			ghostMove(60, 2);
		}
		if (ghostAction == 66000) {
			ghostMove(70, 2);
		}    
 		if (ghostAction == 65000) {
			ghostMove(60, 2);
		}
		if (ghostAction == 64000) {
			ghostMove(70, 2);
		}   
		if (ghostAction == 63000) {
			ghostMove(60, 2);
		}       
		if (ghostAction == 56000) {
			ghostMove(90, 100);
			ghostLook = 1;						//Allow ghost to look around again	
			
			if (goldHits > 9 and goldHits < 100) {					//Still collecting gold?
				ghostAction = 209999;
			}
			else {
				ghostAction = 319999;								//Else, normal pose			
			}
			
		}		
	
	}

	if (ghostAction > 100000 and ghostAction < 150001) {			//Holding Ball?
		ghostAction -= 1;
		if (ghostAction == 125000) {
			ghostMove(65, 300);
		}
		if (ghostAction == 100010) {
			ghostMove(115, 300);
			ghostAction = 150000;			
		}
		return;
	}	

	if (ghostAction > 150000 and ghostAction < 200000) {			//Sexy Dance?
		ghostAction -= 1;
		if (ghostAction == 199990) {
			ghostMove(75, 100);
		}
		if (ghostAction == 180000) {
			ghostMove(105, 50);		
		}
		if (ghostAction == 160001) {
			ghostMove(90, 100);	
			ghostAction = 0;
		}		
		return;
	}	

	if (ghostAction > 210000 and ghostAction < 230000) {			//Ghost hit, leading into Guarding Door?
		ghostAction -= 1;

		switch (ghostAction) {						//Turn off the lights when we hit them
			case 229900:
				ghostMove(140, 2);
				break;
			case 220000:
				ghostMove(125, 50);	
				break;
			case 218000:
				ghostMove(120, 50);
				break;
			case 214000:
				ghostMove(115, 50);
				break;
			case 213000:
				ghostMove(125, 50);
				break;
			case 211000:											//This will lead into ghost turning back towards door
				ghostMove(115, 50);
				break;		
		}		
		return;
	}	
	
	if (ghostAction > 199999 and ghostAction < 210001) {			//Guarding door?
		ghostAction -= 1;
		if (ghostAction == 205000) {
			ghostMove(5, 50);
		}
		if (ghostAction == 200001) {
			ghostMove(15, 50);
			ghostAction = 209999;			
		}
		return;
	}
	
	if (ghostAction > 300000 and ghostAction < 320001) {			//Guarding Front?
		ghostAction -= 1;
		if (ghostAction == 310000) {
			ghostMove(80, 50);
		}
		if (ghostAction == 300001) {
			ghostMove(100, 50);
			ghostAction = 319999;			
		}
		return;
	}	

	if (ghostAction > 320000 and ghostAction < 340000) {			//Ghost hit, leading into Guarding Front?
		ghostAction -= 1;

		switch (ghostAction) {						//Turn off the lights when we hit them
			case 339990:
				ghostMove(160, 2);
				break;
			case 334000:
				ghostMove(150, 50);	
				break;
			case 330000:
				ghostMove(135, 50);
				break;
			case 328000:
				ghostMove(126, 50);
				break;
			case 326000:
				ghostMove(134, 50);
				break;
			case 324000:											//This will lead into ghost guarding the front
				ghostMove(127, 50);
				break;		
			case 322000:											//This will lead into ghost guarding the front
				ghostMove(133, 50);
				break;						
		}		
		return;
	}		

	if (ghostAction > 399999 and ghostAction < 499999) {			//Minion animations?
		ghostAction -= 1;
		switch (ghostAction) {						//Turn off the lights when we hit them
			case 468000:
				ghostMove(120, 2);
				break;
			case 466000:
				ghostMove(60, 2);	
				break;
			case 464000:
				ghostMove(110, 5);
				break;
			case 462000:
				ghostMove(70, 5);
				break;
			case 460000:
				ghostMove(90, 5);					//Centers
				if (minion[player] != 10 and minion[player] != 100) {	//Minion over? End motion
					ghostAction = 0;
				}			
				break;				
			case 450000:							//This will lead into ghost guarding the front
				ghostMove(60, 150);
				break;	
			case 425000:											
				ghostMove(120, 150);
				break;		
			case 400000:											
				ghostAction = 450005;
				break;					
		}		
		return;	
	}

	if (ghostAction > 499999 and ghostAction < 510000) {
		ghostAction -= 1;
		switch (ghostAction) {						//Turn off the lights when we hit them
			case 509990:
				ghostMove(70 + (random(2) * 40), 5);	//Either goto 70 or 110
				break;
			case 500000:
				ghostMove(90, 150);
				ghostAction = 0;				//Cancel motion
				break;				
		}		
		return;			
	
	}
	
	
}

void doorDo() {									//When ball goes past Door Opto

	ghostLooking(15);

  if (DoorLocation == DoorOpen) {    //If door is open, do the PF animation (was on the VUK but it felt slow)    
    animatePF(200, 10, 0);
  }
  
	if (extraLit[player]) {						//Extra ball available?
		return;									//Door should be open, let the ball past
	}											//Other door opto functions won't work until EB is collected (such as Advance Hospital or Confederate Gold)
	
	if (Mode[player] == 6 and convictState == 1) {																	//Fighting warden ghost and the door is closed?

		video('P', '8', 'Y', allowSmall, 0, 255);			//Door opens, Prompt for next shot
		playSFX(0, 'P', 'Y', 'A' + random(4), 255);	

		AddScore(50000);							//50k for hitting the door
		convictState = 2;							//Advance state
		DoorSet(DoorOpen, 5);						//Open door quickly!
		light(14, 0);								//Turn off Camera blink
		strobe(8, 7);								//Strobe the entire shot
		modeTimer = 0;								//Reset this so prompt won't happen for a bit
		return;										//Abort out so default doesn't occur
	}

	if ((hotProgress[player] > 29 and hotProgress[player] < 40) and convictState == 1) {							//Evicting ghosts from the Hotel? Uses same variables as Prison Free Ghost
		video('L', 'E', '1', allowSmall, 0, 255);	//Door opens, Prompt for next shot
		playSFX(0, 'L', 'E', '1' + random(4), 255);	//Knocking sound, random prompt
		
		AddScore(50000);							//50k for hitting the door
		convictState = 2;							//Advance state
		DoorSet(DoorOpen, 200);						//Open door slowly
		light(14, 0);								//Turn off Camera blink
		strobe(8, 7);								//Strobe the entire shot
		return;										//Abort out so default doesn't occur
	}
	
	if (fortProgress[player] > 59 and fortProgress[player] < 100) {													//Fighting the War Fort?
		if (goldHits < 10) {	//Not already collecting gold (10) or disabled (100)?
			WarGoldStart();	
		}
		if (goldHits == 100) {	//Already beat it?
			killQ();									//Disable any Enqueued videos		
			video('W', 'G', 'I', allowSmall, 0, 255);			//No more gold!
			playSFX(0, 'W', 'G', '0' + random(4), 255);	//Ghost lamenting the lack of gold			
			DoorLocation = DoorClosed - 10;				//Put it to be slightly opened
			myservo[DoorServo].write(DoorLocation);		//Send that value to the servo
			DoorSet(DoorClosed, 1000);					//Then make it go back closed			
		}
		
		return;
	}
	
	if (Advance_Enable == 1 and hosProgress[player] == 0) { // and deProgress[player] == 0) {								//Are we elible to advance modes?
		
		if (theProgress[player] < 3 or theProgress[player] == 100) {	//Theater isn't lit, or has been won already? 
			HospitalAdvance();								//Advance Hospital
			return;
		}
	}
		
	if (hosProgress[player] > 5 and hosProgress[player] < 9 and hosTrapCheck == 0) {								//Are we trying to bash open the door, and there wasn't a ball search error?
		if (DoctorState == 0) {							//Evil doctor ghost NOT distracted?
			DoorSet(DoorClosed - 5, 5);					//Open door slighty
			modeTimer = 8000;							//Set timer to close it back up
			AddScore(10000);							//A few points
			video('H', '5', 'A', allowSmall, 0, 200);	//Same video for every clip
			int x = random(1);							//50/50 chance it plays CLUNK or CLUNK + Voice Prompt
			if (x) {
				playSFX(0, 'H', '5', 'Z', 255);			//Play taunts H5A-H5D
			}
			else {
				playSFX(0, 'H', '5', random(8) + 65, 255);	//Play taunts H5A-H5D
			}			
		}
		if (DoctorState == 1) {							//Evil doctor ghost IS distracted?			
			AddScore(countSeconds * 50000);
			DoorSet(DoorClosed - 20, 5);				//Open door slighty
			modeTimer = 8000;							//Set timer to close it back up
			killTimer(0);								//Kill the timer
			DoctorState = 0;							//Reset flag
			doctorHits = 0;								//Reset this so there's a prompt next time you hit ghost
			light(8, 0);								//Disable strobe state
			ghostAction = 5500;							//Re-enable ghost jitters
			if (hosProgress[player] == 6) {				//First bash?
				video('H', '6', 'J', allowSmall, 0, 200);		//Ball hits door, ghost blocks, 2 HITS TO GO!
				playSFX(0, 'H', '0' + hosProgress[player], 'J' + random(3), 255);
				customScore('H', '7', 'E', allowAll | loopVideo);	//Shoot Ghost 2 shots to go!
			}
			if (hosProgress[player] == 7) {				//Second bash?
				video('H', '6', 'K', allowSmall, 0, 200);		//Ball hits door, ghost blocks, 1 HIT TO GO!
				playSFX(0, 'H', '0' + hosProgress[player], 'J' + random(3), 255);
				customScore('H', '7', 'F', allowAll | loopVideo);	//Shoot Ghost 2 shots to go!
			}
			hosProgress[player] += 1;					//Advance progress. If Hospital Logic section sees this as a "9", we start Multiball Battle!
			if (hosProgress[player] < 9) {				//Not the winning hit yet?	
				pulse(17);
				pulse(18);
				pulse(19);
				light(hosProgress[player] + 1, 7);		//Use number to indicate progress
			}	
		}
		return;
	}

	//Default Action if no other logic. This actually should never happen, but make a CLUNK sound and slightly move door if it does
	
	if (DoorLocation == DoorClosed) {				//Door closed when we hit it?
		DoorLocation = DoorClosed - 10;				//Put it to be slightly opened
		myservo[DoorServo].write(DoorLocation);		//Send that value to the servo
		DoorSet(DoorClosed, 1000);					//Then make it go back closed
		playSFX(2, 'H', '0', '0', 100);				//Door clunking sound
		AddScore(5000);								//Some points
	}
	
}

void doorLogic() {								//What to do with the door at the end of a mode

	DoorSet(DoorOpen, 5);											//The default is OPEN, but...

	if (deProgress[player] == 1) {									//Eligible to start Demon Battle?
		DoorSet(DoorOpen, 5);
		return;
	}	
	
	if (extraLit[player]) {											//Extra ball available?
		DoorSet(DoorOpen, 5);										//Make sure the door is open
		pulse(15);													//Pulse the light
		return;														//Return out of this, EB always top priority
	}
	else {
		light(15, 0);												//If not lit, turn light off (it may have been collected during a mode, thus old lights)
	}

	if (Mode[player] == 6 or (hotProgress[player] > 29 and hotProgress[player] < 40)) {	//A mode one-two punching the door?
	
		if (convictState == 1) {
			DoorSet(DoorClosed, 5);
		}
		else {
			DoorSet(DoorOpen, 5);
		}
		return;
	
	}
	
	if (hellMB or minionMB) {										//Hell MB isn't in progress?
		DoorSet(DoorOpen, 25);										//Make sure the door is open		
		return;
	}	
	
	if (Mode[player] == 4) {
		if (goldHits == 10) {											//Stealing confederate gold?
			DoorSet(DoorOpen, 5);										//Make sure the door is open	
		}
		
		if (goldHits < 10 or goldHits == 100 or fortProgress[player] == 59) {							//Trying to open door, or Gold already complete, or mode just started?
			DoorSet(DoorClosed, 5);	
		}	
		return;
	}
			
	if (theProgress[player] == 3) {									//Eligible to start Theater?
		DoorSet(DoorOpen, 5);										//Make sure door is open	
		return;
	}
	
	if (deProgress[player] == 2) {									//On second shot of Demon Battle?
		DoorSet(DoorClosed, 5);										//Door should be closed
		return;
	}
			
	if (hosProgress[player] > 5 and hosProgress[player] < 9) {		//Are we trying to save our friend in hospital?

		if (restartTimer) {
			DoorSet(DoorClosed, 5);
		}
		else {
			DoorSet(DoorOpen, 5);	
		}

		return;
	}	
	
	if (hosProgress[player] > 0 and hosProgress[player] < 4) {		//Advancing Hospital mode?	
		DoorSet(DoorOpen, 5);										//Make sure door is open	
		if (hosProgress[player] == 3) {									//Was doctor mode ready?	
			pulse(11);													//Turn off that light for now	
		}				
	}
	
	if (hosProgress[player] == 99) {								//Did we FAIL doctor mode?	
		pulse(11);													//Re-lite it
		DoorSet(DoorOpen, 500);										//Open door SLOWLY		
		hosProgress[player] = 3;									//Set progress to re-enable state
		return;
	}
	
	if (hosProgress[player] == 100 and Advance_Enable == 1) {		//If hospital mode has been won, keep door open for combos (and to reduce wear)
		DoorSet(DoorOpen, 100);	
		return;
	}		
	
	if (hosProgress[player] == 0 and Mode[player] == 0) {			//Gotta start Hospital? Door is closed, unless we're in a mode in which case, don't touch the door don't touch the door!
		DoorSet(DoorClosed, 5);
	}	

}

void DoorSet(unsigned char dTarget, unsigned long dSpeed) {

	if (dSpeed < 1) {														//Error trap
		dSpeed = 100;
	}
	if (dTarget < DoorOpen) {												//Error trap
		dTarget = DoorOpen;
	}
	if (dTarget > DoorClosed) {												//Error trap
		dTarget = DoorClosed;
	}	
	
	DoorSpeed = dSpeed;												//How fast to move
	DoorTarget = dTarget;											//Where to move to.
	DoorTimer = 0;													//Reset cycle timer

}

void dirtyPoolCheck() {								//If a mode ends with a condition where a ball could be stuck under the ghost, call this routine to check and clear it

	if (dirtyPoolChecker == 0) {				//We WANT to trap balls behind targets?
		return;									//Abort!
	}
	//Serial.println("Dirty Pool Check...");
	dirtyPoolTimer = 1;							//Set the timer for Dirty Pool Logic

}

void dirtyPoolMode(unsigned char whatToDo) {	//0 = Ignore balls trapped behind targets (some modes) 1 = Check for them and remove (normal)

	dirtyPoolChecker = whatToDo;

}

void dirtyPoolLogic() {

	dirtyPoolTimer += 1;

	if (dirtyPoolTimer == 10) {					//First event?
		 MagnetSet(75);							//Trigger the Magnet
	}
			
	if (dirtyPoolTimer > 9 and dirtyPoolTimer < 50000) { 	// and barProgress[player] != 65) {	//Wait until 20k mark before checking if Bar Trap
		if (bitRead(cabinet, ghostOpto)) {					//As SOON as something blocks the opto, trigger Dirty Pool
			magFlag = 0;									//Disable the Magnet Hold Pulses
			playSFX(0, 'D', 'P', '0' + random(5), 255);		//Dirty Pool Prompt!
			AddScore(250000);
			TargetSet(TargetDown);							//Put targets down
			TargetTimerSet(15000, TargetUp, 5); 			//Set timer to put them back up after ball rolls out. It'll check again once they're up
			dirtyPoolTimer = 100000;						//Set this to Ball Detected Countdown, so Detected only occurs once		
		}		
	}
	
	if (dirtyPoolTimer == 20000)	{			//Enough time to grab ball?
		dirtyPoolTimer = 0;						//OK to proceed!
	}
	
	if (dirtyPoolTimer == 120000) {				//If a ball was found, wait about a second and make sure it's rolled out
		dirtyPoolTimer = 0;						//Disable it for now, but targets will check again once they're up
	}

}

void displayTimerCheck(unsigned long newTimerValue) {						//Call this before using the Display Timer. If something already running, this ends it properly

	if (newTimerValue) {										//Setting a new value?	

		if (displayTimer > 0 and displayTimer < 45000) {		//Was ORB flashing?
			if (orb[player] & B00100100) {	//O lit?
				light(32, 7);
			}
			else {
				light(32, 0);
			}
			if (orb[player] & B00010010) {	//R lit?
				light(33, 7);
			}
			else {
				light(33, 0);
			}
			if (orb[player] & B00001001) {	//B lit?
				light(34, 7);
			}
			else {
				light(34, 0);
			}
		}

		if (displayTimer > 45000 and displayTimer < 90000) {	//Was GLIR flashing as this started?	
			//Set GLIR lights to what they should be
			if (rollOvers[player] & B10001000) {	//G lit?
				light(52, 7);
			}
			else {
				light(52, 0);
			}
			if (rollOvers[player] & B01000100) {	//L lit?
				light(53, 7);
			}
			else {
				light(53, 0);
			}
			if (rollOvers[player] & B00100010) {	//I lit?
				light(54, 7);
			}
			else {
				light(54, 0);
			}
			if (rollOvers[player] & B00010001) {	//R lit?
				light(55, 7);
			}
			else {
				light(55, 0);
			}

		}	
		
		displayTimer = newTimerValue;			
	}
	else {														//Else, we're just updating both ORB and GLIR
		updateRollovers();
	}


}

void Drain(unsigned char drainType) {						//What happens when you drain. Check for ball save, extra balls, DRAIN if neither

	if (lightningGo) {				//So it won't get stuck on, even during a ball save
		lightningEnd(10);
	}
  
	if (tiltFlag) {					//Were we in a Tilt state when ball drained?
		if (hosProgress[player] > 5 and hosProgress[player] < 90) {					//Doctor MB, but a Tilt?
			HospitalFail();																//Mode FAIL! Gotta start over
		}	
		if (barProgress[player] > 59 and barProgress[player] < 100) {					//Bar MB, but a Tilt?
			BarFail();																	//Mode FAIL! Gotta start over
		}			
	}
	else {													//Normal drain?

		drainSwitch += 1;									//Increment the drain switch #
		//Serial.print("+Drain Switch = ");
		//Serial.println(drainSwitch, DEC);

		if (saveTimer or (scoreBall == 0 and zeroPointBall == 1)) {	//Ball save active, or it was a Zero Point Ball with save enabled?
			activeBalls -= 1;								//Have to subtract one here before AutoPlunge will ADD one.
			AutoPlunge(autoPlungeFast);						//Auto-plunge a freebie ball. Give it a little time in case trough empty
			video('E', 'B', 'Y', allowSmall, 0, 255);		//Keep shooting! (new video)
			
			if (activeBalls == 0) {							//No MB or anything going on?
				playSFX(0, 'Y', 'A', '0' + random(4), 255);	//"Don't Touch that Dial!" (high priority)
			}
			else {
				playSFX(0, 'Y', 'A', '0' + random(4), 150);	//"Don't Touch that Dial!" (medium priority)
			}
						
			if (multiBall == 0 and multipleBalls == 0) {	//In multiball, ball save doesn't reset on a ball loss, rather there's an overall "grace period" like AFM the best game EVAH
				saveTimer = 0;								//No more ball save for you!
				light(56, 0);								//Turn off Spook Again				
			}
			return;											//Leave this function
		}		
		
		activeBalls -= 1;				//Decrement # of balls on the playfield

		if (chaseBall == 1) {			                      //Were we trying to dislodge a stuck ball, and a ball was drained?
			chaseBall = 10;				                        //Advance ChaseBall state. If another ball search happens, assume other ball still stuck + execute drain
      video('A', 'S', 'B', 0, 0, 255);			        //Sending chase ball
			return;
		}
		
		if (chaseBall == 10) {			//Sent back to Drain method via the Ball Search?
			chaseBall = 0;				//Clear the flag
			ballsInGame = countBalls();	//However many are in the trough at this moment are how many we have to work with
		}
		
		if (activeBalls == 1) {			//Down to our last ball?

			//These first 3 modes can stack with normal Hellavator MB. If a Hell MB was active, these win conditions will terminate the multiball
			if (Mode[player] == 1 and hosProgress[player] == 10) {			//Bashing the Doctor Ghost?		
				HospitalWin();												//Mode complete, reset stuff.			
				return;
			}
			
			if (Mode[player] == 1 and hosProgress[player] > 4 and hosProgress[player] < 9 and hosTrapCheck == 1) {			//Bashing the Doctor Ghost?		
				HospitalRestart();											//Allow quick restart!			
				return;
			}			

			if (hotProgress[player] == 30 or hotProgress[player] == 35) {	//Battling Hotel Ghost?		
				HotelWin();													//Mode complete, reset stuff.		
				return;
			}
			
			if (barProgress[player] == 80) {								//Ghost Whore battle?		
				BarWin();													//Mode complete, reset stuff.		
				return;
			}		
			
			//If none of those modes were active (finishing up) then we end Multiball normally
			if (multiBall) {												//If we weren't in a Ghost mode, then end like normal multiball
				multiBallEnd(0);												//We need to check this first because if stacked with other modes, things might not get cleared properly
				return;
			}
				
			if (priProgress[player] > 9 and priProgress[player] < 20) {		//Last ball, and you didn't free all 3?
				PrisonDrainCheck(0);		
				return;
			}		
			
			if (priProgress[player] == 20) {								//Last ball and you released all 3?
				PrisonDrainCheck(1);
				return;
			}
			
			if (deProgress[player] == 20) {									//Down to our last ball? This is the WIN CONDITION!
				killQ();
				video('D', 'Z', 'X', allowSmall | loopVideo, 0, 255);		//Hit Demon To Win!	text, then Demon on Ropes
				numbers(0, numberScore | 2, 0, 0, player);					//Show small player's score in upper left corner of screen
				loopCatch = catchBall;										//Set that we're ready to catch the final ball
			}
			
			playSFX(2, 'Q', 'Z', 'Z', 200);						//Else, negative sound!			
			return;												//Return to main loop

		}

		if (activeBalls > 1) {			//2 or more balls still active?
			if (Mode[player] == 6) {	//Saving our friends?		
				PrisonDrainCheck(1);
				return;
			}
			if (deProgress[player] > 9 and deProgress[player] < 100) {			//Prompt with current multiplier
				killQ();
				video('P', '7', 'C' + activeBalls, noExitFlush, 0, 255);	
				DemonState();				
			}		
			playSFX(2, 'Q', 'Z', 'Z', 200);						//Negative sound!
			return;						//Return to main loop
		}

		if (activeBalls < 1) {			//Don't let it go below zero
			activeBalls = 0;
		}

		//This has to be after the ActiveBalls check else we'll get a false FAIL condition if MB stacked on Ghost Whore and any balls lost
		if (barProgress[player] > 59 and barProgress[player] < 80) {	//Haven't saved our friend from Ghost Whore yet?		
			if (BarFail() == 1) {										//One more chance?
				return;													//Avoid drain!
			} //Else, drain!
			activeBalls = 0;
		}	
			
		if (hosProgress[player] > 4 and hosProgress[player] < 9) {	//Were we trying to save our friend from Ghost Doctor?
			if (HospitalFail() == 1) {										//Able to restart it? (returns a 1)
				if (hosTrapCheck == 1) {									//Were we looking for a ball?
					hosTrapCheck = 0;										//Clear flag, do NOT re-add ball #
				}
				else {
					activeBalls += 1;										//Count the ball we've freed
				}
				return;		
			} //Else, drain!
			activeBalls = 0;
		}			
	}
	
    //myservo[DoorServo].write(DoorOpen); 						//Set servo
	
	//delay(2000);
	
	//DoorSet(DoorOpen, 2);
	
	if (restartTimer) {
		restartKill(0, 0);			//In case one is active
	}

	DrainPre();						//Things to do before we start the drain (mostly end active modes)

	killQ();						//Disable any Enqueued videos	
	killNumbers();					//Disable Numbers display
	comboKill();					//Disable any Combos
	
	AutoEnable = 0;					//Disable flippers
	run = 1;						//Set condition so player can launch the new ball

	callHits = 0;					//How many times you've hit Call this ball (resets per player)	
	//rollOvers[player] = 0;			//Clear rollovers
	light(52, 0);
	light(53, 0);
	light(54, 0);
	light(55, 0);

	ghostMove(90, 10);				//Center ghost
  
	storeLamp(player);											//Store current player's lamps in memory. This is after we've done the Pre-drain stuff, so it's relevant for the next ball
	
	animatePF(149, 30, 0);			//Ball fade animation. Will also cancel out any other animations in progress
	//allLamp(0);													//Turn off all lamps

	scoringTimer = 0;											//Terminate any scoring timers
	scoreMultiplier = 1;										//Reset multipler
		
	skip = 0;
	
	drainTries = 0;
	
	if (tiltFlag == 0) {										//Don't award bonus, or show video / music if tilt
	
		if (countBalls() == 4) {								//All balls accounted for?
			drainTimer = 70005; //160005;						//Timer for Drain events. System keeps running.			
		}
		else {
			drainTimer = 90005; //160005;							//If low on balls, give a bit more time for extra ones to roll into trough		
		}
	
		EOBnumbers(0, areaProgress[player] * 13370);			//Send AREA PROGRESS
		EOBnumbers(1, EVP_Total[player] * 250000);						//Send EVPS COLLECTED
		EOBnumbers(2, photosTaken[player] * 500250);			//Send PHOTOS TAKEN
		EOBnumbers(3, ghostsDefeated[player] * 1000000);		//Send GHOSTS DEFEATED
		bonus = (areaProgress[player] * 13370) + (EVP_Total[player] * 250000) + (photosTaken[player] * 500250) + (ghostsDefeated[player] * 1000000);
		bonus *= bonusMultiplier;								//Multiply it		
		bonusMultiplier = 1;									//Reset multiplier (it's per ball so don't need unique variable per player)		
		//EOBnumbers(4, bonus);									//Send TOTAL BONUS
		AddScore(bonus);										//Before switching players, increase score by bonus	
		playMusic('B', 'F');															//Shorter music	
		video('E', 'B', '@' + ball, noEntryFlush | allowLarge, 0, 255);					//Play EOB video
		EOBnumbers(4, bonus);									//Send TOTAL BONUS	
		GIpf(B11000000);
		setCabColor(64, 64, 64, 200);
	}
	else {
		drainTimer = 25000;										//Faster cycle, and skips the audio callout
		cabColor(255, 0, 0, 255, 0, 0);
		doRGB();												//Set cab immediately to RED!
		
		switchDebounceClear(16, 63);							//Reset debounces manually just in case something is sitting on a switch
		ballSearchDebounce(1);									//Add some lag to balls that go into traps
		drainTries = 0;											//We haven't tried to kick the drain yet
		
		while (countBalls() < ballsInGame) {
      
      //INTRODUCE ARTIFICAL DELAY HERE?
      
      //Servo logic, in case a Ball Search is required
      
      if (HellSpeed) {							//Is the elevator supposed to be moving?
        //Serial.println("Moving hell");
        MoveElevator();			//Do routine.
      }	
      if (TargetSpeed) {							//Is the target supposed to be moving?
        //Serial.println("Moving target");
        MoveTarget();
      }
      if (DoorSpeed) {							//Is the door supposed to be moving?
        //Serial.println("Moving door");
        MoveDoor();				//Do routine.
      }	
 
      if (TargetDelay) {							//Target set to move after a delay?
      
        TargetDelay -= 1;						//Decrement
        
        if (loopCatch == checkBall) {			//Trying to catch the ball?		
          if (TargetDelay == 300) {											//Almost ready to check?
            MagnetSet(100);													//Pulse magnet again
          }
          if (TargetDelay < 1) {												//Timed out? Ball must not be there. Bummer.
            magFlag = 0;													//Clear the pulse flag
            TargetTimerSet(1, TargetDown, 2);								//Keep targets down so you can re-trap
            loopCatch = catchBall;											//Reset state, we still need to catch the ball	
            killQ();														//Disable any Enqueued videos	
            video('D', 'Z', 'A', allowSmall, 0, 255); 						//Speed Demon Bonus!
            showValue(100000, 40, 1);										//It's a combo value * Ghosts defeated because why not?	
            playSFX(2, 'D', 'Z', 'X', 255);									//Vrooom! Just like a Mustang!				
          }			
          if (TargetDelay < 300 and bitRead(cabinet, ghostOpto)) {			//After second pulse, we consider a ball in opto to be a good catch
            MagnetSet(100);													//Pulse it again to make sure it stays there while targets are going up
            TargetDelay = 0;												//Clear this just in case
            TargetSpeed = TargetNewSpeed;									//Allow targets to move up	
            cabDebounce[ghostOpto] = 10000;									//Make sure it doesn't re-trigger opto				
            loopCatch = ballCaught;											//External logic will take it from here. Allow targets to go up
          }			
        }
        else {
          if (TargetDelay < 1) {					//Ready to move targets?
            TargetSpeed = TargetNewSpeed;		//Set Speed flag to start targets moving	
            TargetDelay = 0;					//Clear this just in case
          }			
        }
      }
 
			houseKeeping();										//Enable solenoids and do switch debounce
			ballSearch();										//Find all balls! System halts until it finds them	
	
			if (kickTimer > 0) {								//Ball needs kicked from the drain?
				swDebounce[63] = swDBTime[63];			//Keep the debounce on to prevent a re-trigger until it's gone
				kickTimer -= 1;
				if (kickTimer == 6000) {				//Ready to kick it?
					Coil(drainKick, drainStrength + drainTries);		//Give it a kick!
					//Serial.print("Kick power: ");
					//Serial.println(drainStrength + drainTries);
					drainTries += 2;					//Increase the power. If the ball hits Switch 4, then it loaded and this is clear. If not, it kicks harder with each re-try				
				}
				if (kickTimer < drainPWMstart) {		//After the kick, pulse hold the coil a bit...
					kickPulse += 1;
					if (kickPulse > 75) {				//Wait appx 10 ms
						kickPulse = 0;					//Reset timer
						Coil(drainKick, 1);				//Kick for 1 ms
					}
				}
				if (kickTimer == 0) {					//Then turn off the coil
					digitalWrite(SolPin[drainKick], 0); //Make sure it's off
				}
			}	

			if (Switch(62)) {									//Ball on Ball Switch 4?	
					
				if (kickFlag) {												//Ball got her via a drain kick?
					kickFlag = 0;											//Clear flag, ball kick complete
					drainTries = 0;		
				}
			}

      switchDead += 1;

      if (switchDead > deadTop) {				//No switch has been hit in a while?						
        switchDeadCheck();
      }      
      
		}
		
		drainSwitch = 59 + ballsInGame; //63;					//Set starting drain switch manually, now that we have all the balls
		ballSearchDebounce(0);									//Remove trap switch lag now that we have ALL balls!		
	}	
 
  switchDead = 0; 
  
}

void DrainLogic() {								//DRAIN functions are in-line. This is the logic that executes

	if (Switch(63) and kickTimer == 0) {	//Something in the drain, and we didn't just try to kick it?
		drainClear();						//Unload the drain!		
	}

	if (drainTimer == 69000) { //178500) {
		GIpf(B10000000);
    GIbg(0);                //Turn off GHOST PANEL
		allLamp(0);							//Turn off all lamps after the Fade Animation has a chance to start
		EOBnumbers(4, bonus);				//Send TOTAL BONUS again to make sure EOB numbers are enabled (instead of seeing blank scores)		
	}	
	
	if (drainTimer == 68000) { //177000) {
		GIpf(B00000000);		
	}

	if (drainTimer == 65000) { //177000) {
		playSFX(0, 'U', 'A' + random(4), 'A' + random(20), 150);	//Ball drain quote from 4 Team Members (not super high priority so won't override other dialog)		
		//playSFX(0, 'U', 'D', 'A' + random(20), 150);	//Misty test				
		//playSFX(0, 'Y', 'B' + random(3), '0' + random(10), 150);	//Ball drain quote from 3 Team Members (not super high priority so won't override other dialog)		
	}
	
	if (cabSwitch(RFlip) or cabSwitch(LFlip)) {		//Skipping past?
		if (countBalls() == 4 and drainTimer > 18000 and drainTimer < 69000) {	//All balls accounted for, and eligible part of sequence?
			//If balls missing, you can't skip this so they have time to maybe roll into the drain
				
			video('E', 'C', '@' + ball, 0, 0, 255);		//Play ending flash (will also kill EOB numbers))
			drainTimer = 17000;							//Speed this up	
			playMusic('B', 'G');						//Ending beat

			//video('E', 'C', '@' + ball, 0, 0, 255);		//Play ending flash
				
		}
	}	
	
	if (drainTimer == 10001 and countBalls() < ballsInGame) { //Don't continue until all balls are accounted for
		drainTimer = 10100;
	}
	
	if (drainTimer == 10000) {			//Last thing we do... (sped up a little)

		drainTimer = 0;

		GIpf(B00000000);				//In case we somehow got past it
	
		ballsPlayed += 1;				//Increase counter
	
		videoPriority(0);				//Erase video priority
	
		if (extraBalls) {				//Have more than zero extra balls?
			extraBalls -= 1;			//Subtract one...
			loadLamp(player);			//We basically treat this as a drain, but we don't advance the ball # or player #
			playSFX(0, 'Y', 'A', '5' + random(3), 255); //Same ghost hunter shoots again!
			if (numPlayers == 1) {
				video('S', 'A', 'C', 0, 0, 255);
			}
			else {
				video('S', 'A', 'D', 0, 0, 255);
			}
			
			skillShotNew(0);				//Set up a Skill Shot, but show video AFTER the Shoot Again prompt (0)	
		}
		else {							//No extra balls? Advance balls or player # as normal
			if (numPlayers > 1) {		//More than 1 player?
				player += 1;				//Advance which player is up
				if (player > numPlayers) {  //Past the end?
					player = 1;				//Back to Player 1
					ball += 1;				//Went through all 4 players, increment ball #
				}			
				loadLamp(player);			//Load new player's lamps into memory
			}
			if (numPlayers == 1) {	
				ball += 1;
				loadLamp(player);
			}
			if (ball < ballsPerGame) {				//Game not over yet?
        if (numPlayers > 1) {
          video('K', '9', '9', noExitFlush, 0, 255);	//STATIC transition           
        }
        else {
          video('K', '9', '9', 0, 0, 255);	//STATIC transition    
        }				
				skillShotNew(1);					//Set up a Skill Shot!
			}
		}
			
		tiltFlag = 0;					//Reset this in case we got here from a tilt. We do it here so it won't prevent Match music from playing
		
		if (ball == ballsPerGame) {		//Game over? (man?)
			//stopMusic();				//Eventually we'll let GAME OVER handle this
			return;						//Exit routine, since game is over				
		}
		else {
			Update(0);				//Make sure we're not in Attract Mode.			
			playMusic('L', '1');				
		}
		
		//EVP_Total = 0;				//Reset single-ball bonuses
		popCount = 0;					//Pops per ball (takes 10 to get an EVP)
			
		GIpf(B11100000);
		
		sweetJumpBonus = 0;				//Reset score (hitting it adds value)
		sweetJump = 0;					//Reset video/SFX counter		

		Advance_Enable = 1;
		Mode[player] = 0;
		
		badExit = 0;					//Haven't gone in VUK yet
		tiltCounter = 0;				//Reset to zero		
		comboKill();

		showProgress(0, player);		//Set progress lights		
		
    suppressBurst = 0;  
		minionDamage = 1;				//Default damage
		checkModePost();				//Set things on the playfield for the new current player
		AutoEnable = 255;				//Enable flippers
		ghostLook = 0;
		dirtyPoolMode(1);				//Check for Dirty Pool Balls		
		spiritGuideEnable(1);			//Mode 0, it can always be lit
		hellEnable(1);					//Enable the Hellavator on this ball
		GLIRenable(1);					//In case you tilted with GLIR disabled	
		//orb[player] = 0;				//Clear player's ORB variable so it can be reset

		scoreBall = 0;					//No points scored on this ball as yet
		comboEnable = 1;				//OK combo all you want
		
		//Do this last in case a ball comes loose and rolls into drain during drain sequence
		
		ballsInGame = countBalls();		//Balls may have rolled down into the trough during the drain sequence
		drainSwitch = 59 + ballsInGame; //63;				//Manually set the drain switch number (will goto 62 once new ball loads)
    
		ghostBurst = 1;       //Clear the GhostBurst stuff			
		burstReady = 0;       //If rollover hit, set this flag to 1. Next score will be X ghostBurst!
		burstLane = 0;        //Which lane is lit for GHOST BURST
    
    laneChange();           //In drain we manually cleared GLIR to prevent latent Ghost Burst strobe. Thus we must call this to re-paint already collected GLIR letters
  		
		loadBall();						//Load a new ball	
		flashCab(255, 255, 255, 10);	//Flash from black to Default Mode Color		
	}

}

void DrainPre() {													//Mode-specific things to do at the start of a drain

	if (minion[player]) {											//In a Minion Battle?
		minionEnd(3);												//End it with drain flag, but allow a restart
	}

	if (Mode[player] == 7 or Mode[player] == 99) {					//Were we in GHOST PHOTO HUNT?
		photoFail(1);												//Fail flag 0, meaning failed because of drain
	}

	if (tiltFlag) {
		if (multiBall) {											//We need to do this AFTER photo hunt clear in case they were stacked
			multiBallEnd(0);
		}	
	}
	
	if (hotProgress[player] > 9 and hotProgress[player] < 30) {		//In hotel mode, but not before multiball? OR, if tilt, also kill it
		HotelFail();
	}

	if (hotProgress[player] > 29 and hotProgress[player] < 40 and tiltFlag) {		//Did we tilt out during Multiball?
		HotelFail();
	}
	
  if (Mode[player] == 8) {                                //Were doing Bumps in the Night?   
    bumpFail();
  }
  
	if (fortProgress[player] > 49 and fortProgress[player] < 100) {	//Were we in War Fort mode?
		WarFail();													//End that mode
	}

	if (theProgress[player] > 9 and theProgress[player] < 100) {	//Doing the THEATER PLAY?
		TheaterFail(1);												//End that mode, with no animations (1)
	}

	if (deProgress[player] > 1 and deProgress[player] < 9) {		//Locking balls to start Demon Battle?
		DemonFailLock();											//Do fail condition for that
	}
	
	if (deProgress[player] > 8 and deProgress[player] < 21) {		//Lost all balls before defeating demon?
		DemonFailBattle();											//Do fail condition for that
	}

	if (priProgress[player] > 9 and priProgress[player] < 99) {		//Trying to free friends, or bash the Prison Warden?
		PrisonFail();	
	}	
	
}

void drainClear() {

	kickPulse = 0;							//Make sure PWM timer is reset
	kickTimer = 8000;						//WAS 10,000 //Wait 10k cycles, then kick hold for 10k cycles
	kickFlag = 1;							//Set flag that ball is being kicked from the drain
	
}

void ElevatorSet(unsigned char dTarget, unsigned long dSpeed) {
	
	if (dTarget == hellDown) {
		HellSafe = ((HellLocation - dTarget) * dSpeed) + subwayTime;	//How many cycles it should take for the ball to get to the middle subway switch
	}
		
	HellSpeed = dSpeed;													//How fast to move
	HellTarget = dTarget;												//Where to move to.
	HellTimer = 0;														//Reset cycle timer

}

void elevatorLogic() {

	hellEnable(1);								//Losing a mode re-enables the Hellavator Lock

	if (hotProgress[player] == 3) {				//Able to start Hotel mode?
		ElevatorSet(hellUp, 200);				//Move the elevator into 2nd floor position	
		blink(41);								//HELL FLASHER
		light(26, 7);							//Re-light advance numbers
		light(27, 7);
		light(28, 7);
		pulse(29);								//Pulse Hotel Ghost
		light(24, 0);							//Call button lights off
		light(25, 0);
		return;
	}
	
  //POSSIBILITY FOR HELLAVATOR MULTIBALL START?
  
	//Default state is hellavator down, Lock enabled
	ElevatorSet(hellDown, 100); 				//Send Hellavator to 1st Floor.
	light(41, 0);								//Flasher OFF			
	blink(24);									//Blink the UP button							
	light(25, 7);								//DOWN is solid, since elevator is there
	light(30, 0);								//Turn OFF "Lock" light	

}

void Enable() {										//The kernel calls this every cycle to enable the Watchdog Timer on the solenoids
  
  digitalWrite(solenable, 1);						//Pulse enable line
  digitalWrite(solenable, 0);  
  
}

void evpPops() {

	popCount += 1;								//Increase pop counter

	popToggle();								//Toggle left and right
	
	//Pops will only show video/numbers if we haven't JUST shot up center
	
	if (popCount < 10) {														//Not enough for an EVP, normal pop
		EVP_Jackpot[player] += 2030;
		sendJackpot(0);					//Send jackpot value to score #0
		AddScore(2030 * popCount);

		video('E', 'J', '0' + popCount, allowLarge, 0, 239);					//Jackpot display, with EVP progress bar
		numbersPriority(6, 1, 255, 12, EVP_Jackpot[player], 239);					//Send numbers with current EVP value, and it will only display on videos matching this priority		
						
		stereoSFX(1, 'E', 'V', '1' + random(3), 200, leftVolume, rightVolume);
	}	
	
	if (popCount == 10) {														//Enough for an EVP?
		leftVolume = sfxDefault;														//Center the volume
		rightVolume = sfxDefault;
		AddScore(5000 * popCount);
		popCount = 0;															//Reset pop total
		EVP_Total[player] += 1;													//Increase our EVP's this ball
		EVP_Jackpot[player] += 11110;
		sendJackpot(0);															//Send current jackpot value to score #0
		AddScore(EVP_Total[player] * 11110);									//Ten times the points for an EVP!	

		if (EVP_Total[player] < EVP_EBtarget[player]) {							//haven't gotten enough for an EVP yet?
			video('E', 'V', '3', allowSmall, 0, 241);										//Higher priority so Score doesn't override
			numbersPriority(5, 2, 20, 26, EVP_EBtarget[player] - EVP_Total[player], 241); 	//A small number to show how many EVP's we've gotten in total										
			playSFX(1, 'E', 'V', 'A' + random(8), 201);										//Higher priority so regular pops don't override EVP voice				
		}
		else {																	//Guess we got enough for an Extra Ball!

			switch (allowExtraBalls) {										//Give whatever the settings allow for Extra Ball
				case 1:														//Allow Extra Balls?
					video('S', 'A', 'B', allowSmall, 0, 255);
					playSFX(0, 'A', 'X', 'C' + random(2), 255);				//EXTRA BALL!
					extraBalls += 1;										//Player gets another ball!
					spookCheck();											//See what to do with the Spook Again light
					break;
				case 2:
					video('S', 'A', 'E', allowAll, 0, 255);
					numbers(5, numberFlash | 1, 255, 11, 100000);			//100k
					playSFX(0, 'Q', 'C', 'A' + random(5), 250);				//Sound + Heather compliment
					AddScore(100000);
					break;
				case 3:
					video('S', 'A', 'E', allowAll, 0, 255);
					numbers(5, numberFlash | 1, 255, 11, 500000);			//500k
					playSFX(0, 'Q', 'C', 'A' + random(5), 250);				//Sound + Heather compliment
					AddScore(500000);
					break;
				case 4:
					video('S', 'A', 'E', allowAll, 0, 255);
					numbers(5, numberFlash | 1, 255, 11, 1000000);			//1 mil
					playSFX(0, 'Q', 'C', 'A' + random(5), 250);				//Sound + Heather compliment
					AddScore(1000000);
					break;	
			}
			
			EVP_Total[player] = 0;											//Reset counter
			EVP_EBtarget[player] += EVP_EBsetting;							//Increase # you need for EB
			
			if (EVP_EBtarget[player] > 99) {
				EVP_EBtarget[player] = 99;
			}
		
		}

		/*
		if (EVP_Total[player] == 1) {													//Our first one?
			//killNumbers(); 													//Disable showing value during EVP
			video('E', 'V', '1', allowSmall, 0, 251);							//Video of waveform, no EVP Collected indicator									
			playSFX(2, 'E', 'V', 'A' + random(8), 201);							//Higher priority so regular pops don't override EVP voice
		}
		else {																	//Two or more? Show the total
			video('E', 'V', '2', allowSmall, 0, 241);							//Higher priority so Score doesn't override
			numbersPriority(5, 2, 68, 26, EVP_Total[player], 241); 						//A small number to show how many EVP's we've gotten in total										
			playSFX(2, 'E', 'V', 'A' + random(8), 201);							//Higher priority so regular pops don't override EVP voice
		}	
		*/
		
	}
	
}

void extraBallLight(unsigned char queueYes) {

	if (allowExtraBalls) {
		extraLit[player] += 1;						//Increase available EB collects
		pulse(15);									//Pulse the light
		DoorSet(DoorOpen, 5);						//Open the door

		if (queueYes == 1) {							//Flag that we should prompt EB is lit?
			video('S', 'A', 'A', allowSmall, 0, 255);	//Extra Ball is lit
			playSFX(0, 'A', 'X', 'A' + random(2), 150);	//Low priority voice call "Extra Ball is Lit!"	
		}	
		if (queueYes == 2) {
			videoSFX('S', 'A', 'A', allowSmall, 0, 255, 0, 'A', 'X', 'A' + random(2), 255);	//"Extra Ball is Lit!"				
		}
				
	}
	
}

void extraBallCollect() {

	lightningStart(1);
	extraLit[player] -= 1;						//Subtract ball lit
	
	extraBallGet += 1;							//Increment master counter
	
	switch (allowExtraBalls) {
		case 1:											//Allow Extra Balls?
			video('S', 'A', 'B', allowSmall, 0, 255);
			playSFX(0, 'A', 'X', 'C' + random(2), 255);	//EXTRA BALL!
			extraBalls += 1;							//Player gets another ball!
			spookCheck();								//See what to do with the Spook Again light
			break;
		case 2:
			video('S', 'A', 'E', allowAll, 0, 255);
			numbers(5, numberFlash | 1, 255, 11, 100000);			//100k
			playSFX(0, 'Q', 'C', 'A' + random(5), 250);				//Sound + Heather compliment
			AddScore(100000);
			break;
		case 3:
			video('S', 'A', 'E', allowAll, 0, 255);
			numbers(5, numberFlash | 1, 255, 11, 500000);			//500k
			playSFX(0, 'Q', 'C', 'A' + random(5), 250);				//Sound + Heather compliment
			AddScore(500000);
			break;
		case 4:
			video('S', 'A', 'E', allowAll, 0, 255);
			numbers(5, numberFlash | 1, 255, 11, 1000000);			//1 mil
			playSFX(0, 'Q', 'C', 'A' + random(5), 250);				//Sound + Heather compliment
			AddScore(1000000);
			break;	
	}
	
	if (extraLit[player] < 1) {					//No more collects available?
		light(15, 0);							//Turn off collect light
	}	
	
	doorLogic();								//See what the door state should be now that EB was collected
	
}

void flippers() {								//Control flippers, if enabled, as well as ball launcher

	boolean leftEOS  = bitRead(switches[6], 3);
	boolean rightEOS = bitRead(switches[6], 4);

	unsigned char flipperCheck = 0;									//Count new flipper hits. If pressed, SKIP EVENT. Only counts "new" hits, so holding a flipper while a mode starts won't cause a skip
		
	if (AutoEnable & EnableFlippers) {								//Flippers available? Then allow player to activate them.

		if (bitRead(cabinet, LFlip) == 1 and LFlipTime == -1) {		//Left button pressed?
			leftDebounce += 1;
			if (leftDebounce > flipperDebounce) {
				leftDebounce = flipperDebounce;
				digitalWrite(LFlipHigh, 1);
				LFlipTime = FlipPower;
				rollLeft();
				flipperCheck += 1;
			}
		}

		if (bitRead(cabinet, RFlip) == 1 and RFlipTime == -1) {		//Right button pressed?
			rightDebounce += 1;
			if (rightDebounce > flipperDebounce) {
				rightDebounce = flipperDebounce;
				digitalWrite(RFlipHigh, 1);
				RFlipTime = FlipPower;
				rollRight();
				flipperCheck += 1;
			}
		}
		
		if (skip and flipperCheck) {								//Was either flipper hit during a skippable animation?							
			skippable();											//Check what to skip to!
		}
		
	}

	//Flippers can time out or be released even if not enabled. (which is why Flipper routine should ALWAYS run)

	if (LFlipTime < -1) {	
		LFlipTime += 1;	
	}
	
	if (LFlipTime > 0) {
		LFlipTime -= 1;
		if (LFlipTime == 0 or leftEOS == 1) { //Did timer run out OR EOS hit?
			digitalWrite(LFlipHigh, 0); //Turn off high power
			LholdTime = holdTop + 5;			 //Set PWM timer
			//digitalWrite(LFlipLow, 1); //Switch on hold current
		}
	}

	if (LholdTime) {
	
		if (LholdTime == holdTop) {
			digitalWrite(LFlipLow, 1);	//Switch hold ON.
		}
		if (LholdTime == holdHalf) {
			digitalWrite(LFlipLow, 1);	//Switch hold OFF
		}
		if (LholdTime == 1) {			//Almost done?
			LholdTime = holdTop + 1;		//Reset it
		}
		LholdTime -= 1;
	}

	if (bitRead(cabinet, LFlip) == 1 and LFlipTime == 0 and leftEOS == 0) {		//Hold Coil fail? (maybe a ball came down and hit the tip hard?)
		digitalWrite(LFlipHigh, 1);												//Short burst of high current
		LFlipTime = 5;
	}		
	
	if (bitRead(cabinet, LFlip) == 0) { //Button released? (normal state)
		leftDebounce = 0;
		LFlipTime = -10;				//Make flipper re-triggerable, with debounce
		LholdTime = 0;				//Disable hold timer.
		digitalWrite(LFlipHigh, 0); //Turn off high power
		digitalWrite(LFlipLow, 0);  //Switch off hold current		
	}

	if (RFlipTime < -1) {	
		RFlipTime += 1;	
	}
	
	if (RFlipTime > 0) {
		RFlipTime -= 1;
		if (RFlipTime == 0 or rightEOS == 1) { //Did timer run out OR EOS hit?
			digitalWrite(RFlipHigh, 0); //Turn off high power
			RholdTime = holdTop + 5;			 //Set PWM timer
			//digitalWrite(RFlipLow, 1); //Switch on hold current
		}
	}

	if (RholdTime) {
	
		if (RholdTime == holdTop) {
			digitalWrite(RFlipLow, 1);	//Switch hold ON.
		}
		if (RholdTime == holdHalf) {
			digitalWrite(RFlipLow, 1);	//Switch hold OFF
		}
		if (RholdTime == 1) {			//Almost done?
			RholdTime = holdTop + 1;		//Reset it
		}
		RholdTime -= 1;
	}
	
	if (bitRead(cabinet, RFlip) == 1 and RFlipTime == 0 and rightEOS == 0) {	//Hold Coil fail? (maybe a ball came down and hit the tip hard?)
		digitalWrite(RFlipHigh, 1);												//Short burst of high current
		RFlipTime = 5;
	}		
	
	if (bitRead(cabinet, RFlip) == 0) { //Button released? (normal state)
		rightDebounce = 0;
		RFlipTime = -10;				//Make flipper re-triggerable, with debounce
		RholdTime = 0;				//Disable hold timer
		digitalWrite(RFlipHigh, 0); //Turn off high power
		digitalWrite(RFlipLow, 0);  //Switch off hold current		
	}

}

void GameOver() {

  //pulses = 0;                       //Reset this so no remainders are left for next person. GREEEEEEEEED!

	endingQuote = 10;									  //Default is to play an Team Leader lending quote. Unless we get an Easter Egg score entry

	for (int x = 0 ; x < 8 ; x++) {
		killTimer(x);								//Make sure all timers are dead. You never know.
	}
	
	killScoreNumbers();

	//playSFX(0, 'A', 'A', 'A' + random(19), 255);		//Ending quote (changed from 11 to 19 we weren't using the last 8 for some reason?)

	int abortLoop = 1;									//How the sort loop knows when to move onto the next player

	unsigned char tempSort = 0;
	
	pPos[0] = 1;										//Default values. When done, 0 = player # with highest score, 3 = player # with lowest score
	pPos[1] = 2;
	pPos[2] = 3;
	pPos[3] = 4;
	
	if (numPlayers > 1) {								//If there is more than 1 player...
		player = 0;										//Set NO active player (so all scores appear same size during score entry)	
	}
	else {
		player = 1;
	}
	
	ball = 0;											//Disable BALL # from appearing
	Update(0);											//Update A/V with this info
	
	allLamp(0);											//Turn off all lamps

	while (abortLoop) {									//Bubble sort the scores. It also sorts non-playing scores of 0
	
		abortLoop = 0;
	
		for (int x = 0 ; x < 3 ; x++) {
			
			if (playerScore[pPos[x + 1]] > playerScore[pPos[x + 0]]) {			
				tempSort = pPos[x + 0];
				pPos[x + 0] = pPos[x + 1];
				pPos[x + 1] = tempSort;
				abortLoop = 1;						
			}		
		}		
	}
	
	/*
	for (int x = 0 ; x < 4 ; x++) {
		Serial.print(x);
		Serial.print(" Player #");
		Serial.print(pPos[x], DEC);
		Serial.print(" Score:");
		Serial.println(playerScore[pPos[x]]);		
	}	
	*/
	
  //nameEntry(pPos[0], 1);										//Get initials from player, and show which place they got
  
	for (int x = 0 ; x < numPlayers ; x++) {										//See if any players got a high score!

		abortLoop = 0;																//Flag to abort out of high score loop if match found
		
		for (int y = 0 ; y < 5 ; y++) {												//Check this score against high scores 0 to 4
			if (abortLoop == 0) {													//Only set the score once
				//if (1) {										//TEST		
				if (playerScore[pPos[x]] >= highScores[y]) {						//Did player beat this high score?	Equalling it will also bump it down a place
					playMusic('N', 'E');											//Only play the music if a player got a high score
					for (int z = 4 ; z > y ; z--) {									//Shift scores down one space below new high score
						highScores[z] = highScores[z - 1];							
						topPlayers[(z * 3) + 0] = topPlayers[((z - 1) * 3) + 0];
						topPlayers[(z * 3) + 1] = topPlayers[((z - 1) * 3) + 1];
						topPlayers[(z * 3) + 2] = topPlayers[((z - 1) * 3) + 2];
					}				
					nameEntry(pPos[x], y + 1);										//Get initials from player, and show which place they got					
					highScores[y] = playerScore[pPos[x]];							//Set the score in the space we vacated
					topPlayers[(y * 3) + 0] = initials[0]; 							//Set initials in RAM
					topPlayers[(y * 3) + 1] = initials[1];
					topPlayers[(y * 3) + 2] = initials[2];
					
					for (int zz = 0 ; zz < 5 ; zz++) {								//Send the newly sorted top 5 scores from RAM to EEPROM
						setHighScore(zz, highScores[zz], topPlayers[(zz * 3) + 0], topPlayers[(zz * 3) + 1], topPlayers[(zz * 3) + 2]);					
					}
					
					//setHighScore(y, highScores[y], topPlayers[(y * 3) + 0], topPlayers[(y * 3) + 1], topPlayers[(y * 3) + 2]);
					//delay(20);
					
					abortLoop = 1;													//Don't check any more scores against this player			
				}			
			}
		}
	}

	animatePF(0, 0, 0);								//Turn off PF animations
	
	repeatMusic(0);									//Music will play and then terminate (disable auto looping)	
	
  stopMusic();
	
	if (allowMatch) {

		unsigned char match = random(10);
			
		unsigned char matchFlag = 0;

		for (int x = 1 ; x < (numPlayers + 1) ; x++) {				//Break player's scores down into 2 digit numbers for match

			SetScore(x);							//Send that player's score one more time before we "rip it up" for match math
		
			unsigned long divider = 1000000000;		//Divider starts at 1 billion
		
			for (int xx = 0 ; xx < 8 ; xx++) {		//Seven places will get us the last 2 digits of a 10 digit score		
				if (playerScore[x] >= divider) {
					playerScore[x] %= divider;
				}			
				divider /= 10;						
			}
			
			if (playerScore[x] == (match * 10)) {	//Did we match?	
				matchFlag += 1;						//Count it up!
				matchGet += 1;						//Increase master counter
			}
			
		}

		//numbers(0, 8, 128, 0, 0);					//Send numbers with current EVP value, and it will only display on videos matching this priority				
		video('N', 'A', '0' + match, allowAll, 0, 255);		//Match video of the random number we generated
		numbers(0, 8, 128, 0, 0);								//Show all scores for Match animation

		if (matchFlag) {										//Does one of the player's scores match?
			credits += matchFlag;								//Award a credit for each match!
      playSFX(0, 'K', 'M', '1', 255);
			//playMusic('Z', '1');								//WIN music
		}
		else {
      playSFX(0, 'K', 'M', '0', 255);
			//playMusic('Z', '0');								//LOSE music
		}

    delay(250); 
    
    switch(endingQuote) {
      case 1:
        playSFXQ(0, 'X', 'N', 'C', 255); 
      break;
      case 2:
        playSFXQ(0, 'X', 'N', 'A', 255); 
      break;    
      case 3:
        playSFXQ(0, 'X', 'N', 'B', 255); 
      break;   
      case 4:
        playSFXQ(0, 'X', 'N', 'D', 255);
      break;
      case 10:
        playSFXQ(0, 'A', 'A', 'A' + random(26), 255);
      break;         
    }
		
	}
	else {
		video('N', '9', '9', 0, 0, 255);					//Game Over Screen!
		stopMusic();
    
    switch(endingQuote) {                             //No match sound so play this right away
      case 1:
        playSFX(0, 'X', 'N', 'C', 255); 
      break;
      case 2:
        playSFX(0, 'X', 'N', 'A', 255); 
      break;    
      case 3:
        playSFX(0, 'X', 'N', 'B', 255); 
      break;   
      case 4:
        playSFX(0, 'X', 'N', 'D', 255);
      break;
      case 10:
        playSFX(0, 'A', 'A', 'A' + random(26), 255);
      break;         
    }
  
	}

 	delay(250); 
        
	showScores = 1;									                  //Now that there has been a game, set the flag to show last scores during attract mode
	skillScoreTimer = 0;                              //We use this as flipper sound timer, so make sure it's not negative
	startingAttract = lastGameScores;									//Start Attract mode with last game's scores. When machine reset runs, it will send the data
	run = 0;												                  //Reset run state for when we cycle back around.

}

void GLIRenable(unsigned char enableOrNot) {

	if (enableOrNot) {					//MSB prevents start. So we clear it to allow Photo Hunt
		GLIRlit[player] &= B01111111;	
	}
	else {
		GLIRlit[player] |= B10000000;	//If we want to disable it, set MSB (probably just used for Minion MB)
	}
	
	showScoopLights();
	
}

void ghostColor(unsigned char RedG, unsigned char GreenG, unsigned char BlueG) {

	ghostRGB[0] = RedG;
	ghostRGB[1] = GreenG;
	ghostRGB[2] = BlueG;

	doRGB();
	
}

void ghostFlash(unsigned long whatTime) {

	ghostRGB[0] = 255;
	ghostRGB[1] = 255;
	ghostRGB[2] = 255;
	ghostFadeTimer = whatTime;
	ghostFadeAmount = whatTime;
	
	doRGB();
	
}

void ghostLooking(unsigned char whereTo) {		//Ghost looks at a spot, gets bored, then turns back to center
	
	if (barProgress[player] == 60 and restartTimer == 0) {	//Ghost waiting for your embrace, but we're not trying to jump back in for quick restart?
	
		if (whereTo != 80 and whereTo != 100) {			//Don't put quotes on the sling hits
			playSFX(0, 'B', '5', 'A' + random(8), 255);	//I'm over here baby!
			video('B', '5', 'A', allowSmall, 0, 255);	//Ghost talking video
			AddScore(5230);								//A few points
			ghostAction = 199999;						//Ghost does "sexy, alluring" dance
		}
		return;
	}

	if (ghostLook == 1 or Advance_Enable == 0) {			
		if (ghostAction == 0) {				//No ghost action going on?
			ghostMove(whereTo, 10);						//Ghost looks wherever.
			ghostBored = 15000 + random(15000);			//Set bored timer.
		}
	}
	
}

void ghostLoopCheck() {
	
	switchDead = 0;								//Since it's not a matrix switch, we set this manually	

	animatePF(179, 10, 0);						//Center explode!
	
	if (photosToGo) {
		killQ();									//Disable any Enqueued videos		
		playSFX(2, 'A', 'Z', 'Z', 255);				//Whoosh!
		photoTimer = longSecond * 2;				//Reset timer, with a little padding
		countSeconds += loopSecondsAdd;
		
		photoValue = (countSeconds * 10000) + (100000 * (photosNeeded[player] - 2));	//Re-calculate next photo value	
		numbers(9, 2, 68, 27, photoValue + photoAdd[player]);												//Update display Photo Value			

		ghostAction = 20000;											//Whack routine
		if (countSeconds > 60) {					//At limit?
			countSeconds = 25;						//Reset
			AddScore(500000);						//Give secret bonus
			killQ();
			numbers(1, numberFlash | 1, 255, 11, 500000);	//500k
			video('F', '9', 'V', noEntryFlush | B00000011, 0, 255);
			playSFX(2, 'A', 'Z', 'Z', 255);
		}
		else {
			video('F', '9', 'U', allowSmall, 0, 255);	//Timer add message
			playSFX(2, 'A', 'Z', 'Z', 255);				//Whoosh!
		}
		numbers(0, numberStay | 4, 0, 0, countSeconds - 1);		//Update the Numbers Timer. We do "-1" so it'll display a zero.
		
		flashCab(255, 0, 0, 50);								//Bright red, brief flash
	
		return;												//Jump out so nothing else can happen	
	}
	
	if (deProgress[player] == 20 and activeBalls > 1) {		//Bashing Demon, and not on our last ball?
		DemonJackpot();	
		return;												//Jump out so nothing else can happen		
	}
	
	if (theProgress[player] > 9 and theProgress[player] < 50) {				//Theater Ghost?
		TheaterWin();							//Mode complete!
		return;												//Jump out so nothing else can happen		
	}	

	if (minion[player] == 10) {					//Are we fighting a Minion?		
		minionHitLogic();
		return;												//Jump out so nothing else can happen		
	}

	if (fortProgress[player] > 69 and fortProgress[player] < 100) {			//Are we fighting the War Ghost?
		WarTrap();
		return;												//Jump out so nothing else can happen		
	}

	if (loopCatch == catchBall) {				//Trying to catch the ball?
		loopCatch = checkBall;					//Change state that we're checking to see if ball actually caught
		MagnetSet(255);							//Hold the ball.
		TargetTimerSet(1000, TargetUp, 2);		//Put targets up quickly to catch ball. This is also how much time before we check again if the ball is actually there	
		return;												//Jump out so nothing else can happen		
	}
	
	if (barProgress[player] == 80) {			//Ghost Whore multiball?
		//lightningStart(1);
		lightningStart(5998);							//Lightning FX	
		ghostFlash(50);
		ghostAction = 20000;	//Ghost whacked
		whoreJackpot += 1;													//Increase jackpot number. First hit will make this 1
		modeTimer = 30000;													//Set timer so a quote happens soon after the hit
		if (whoreJackpot < 10) {											//Play the normal-ish ones for first 9 hits
			playSFX(0, 'B', '0', 'A' + random(9), 255);						//Sound depends on jackpot progress
			video('B', '0', 64 + whoreJackpot, allowSmall, 0, 10);			//Gets knocked closer and closer to the well	
			int x = EVP_Jackpot[player] + (whoreJackpot * 75000);			//Calculate Current value of jackpot		
			AddScore(x);													//The more you hit her, the more you score!
			showValue(x, 40, 1);											//Flash the value onscreen
			
			if (whoreJackpot == 9) {										//Is next one a SUPER JACKPOT?
				manualScore(0, EVP_Jackpot[player] + ((whoreJackpot + 1) * 250000));
			}																//Show that value for "Next Jackpot"
			else {															//Else, default value
				manualScore(0, EVP_Jackpot[player] + ((whoreJackpot + 1) * 75000));
			}
			
		}
		else {																//10th is a SUPER but then resets
			if (adultMode) {
				playSFX(0, 'B', '0', 'J' + random(6), 255);						//Hope the kids are in bed!
			}
			else {
				playSFX(0, 'B', '0', 'O', 255);									//More tame Super Jackpot callout
			}
			video('B', '0', 'J', allowSmall, 0, 10);							//At 10+, show SUPER JACPOT
			int x = EVP_Jackpot[player] + (whoreJackpot * 250000);				//Current value				
			AddScore(x);														//The more you hit her, the more you score!
			showValue(x, 40, 1);												//Flash the value onscreen
			whoreJackpot = 0;													//Gotta start over now
			manualScore(0, EVP_Jackpot[player] + ((whoreJackpot + 1) * 75000)); //Show value for reset "Next Jackpot"
		}
		
		return;												//Jump out so nothing else can happen		
	}

	if (hosProgress[player] == 10) {			//Doctor Ghost Multiball?
		lightningStart(1);
		ghostFlash(50);
		AddScore(EVP_Jackpot[player]);
		playSFX(0, 'H', '9', random(8) + 'A', 255);	//Jackpot sounds!
		video('H', '9', random(2) + 'A', allowSmall, 0, 200);	//Left or right ball animations
		ghostAction = 20000;							//Set WHACK routine.
		if (lightningGo == 0) {					//If a lightning FX isn't currently going
			modeTimer = 60000;					//set Mode Timer so we're less likely to override the next one
		}
		
		return;												//Jump out so nothing else can happen				
	}

	if (hotProgress[player] == 35) {			//Eligible for Hotel Jackpots?
		HotelJackpot();
		lightningStart(1);
		
		return;												//Jump out so nothing else can happen				
	}

	if (priProgress[player] == 20) {			//Bashing Prison Ghost?
		lightningStart(1);
		PrisonJackpot();
		
		return;												//Jump out so nothing else can happen				
	}		


}

void ghostSet(unsigned char whereTo) {			//Moves the ghost and sets that as his new position

	//ghostTimer = 0;				
	GhostLocation = whereTo;					//Update location
    myservo[GhostServo].write(GhostLocation); 	//Set servo

}

void ghostMove(unsigned char whereTo, unsigned int whatSpeed) {		//Send the ghost to a location at a certain speed

	//if (ghostAction) {					//Can't do this during a Ghost Action Animation
		//return;

	ghostSpeed = whatSpeed;
	ghostTimer = ghostSpeed;			//Reset timer to speed
	ghostTarget = whereTo;				//Set target location

}

void hellEnable(unsigned char enableType) {		//1 = You can lock balls in the Hellavator and move it 0 = You can't and Hellavator stays down

	if (enableType) {							//Enable the Hellavator?
	
		hellLock[player] = 1;							//Allow locks / stacking Hell MB
												
		if (hotProgress[player] != 3) {					//Only set these lights if Hotel Mode isn't ready to go (also uses hellavator)		
		
			if (HellSpeed)	{								//In motion? Base this off where it's headed, not where it IS
				if (HellTarget == hellDown) {				//Re-enable elevator call button & lights	
					blink(24);								//Blink the UP button							
					light(25, 7);							//DOWN is solid, since elevator is there
					light(30, 0);							//Turn OFF "Lock" light
					light(41, 0);							//Flasher OFF
				}
				if (HellTarget == hellUp) {
					blink(25);								//Blink the DOWN button							
					light(24, 7);							//UP is solid, since elevator is there
					pulse(30);								//LOCK is lit!
					blink(41);								//Turn on HELL FLASHER
				}						
			}
			else {											//Not in motion? Normal check
				if (HellLocation == hellDown) {				//Re-enable elevator call button & lights	
					blink(24);								//Blink the UP button							
					light(25, 7);							//DOWN is solid, since elevator is there
					light(30, 0);							//Turn OFF "Lock" light
					light(41, 0);							//Flasher OFF
				}
				if (HellLocation == hellUp) {
					blink(25);								//Blink the DOWN button							
					light(24, 7);							//UP is solid, since elevator is there
					pulse(30);								//LOCK is lit!
					blink(41);								//Turn on HELL FLASHER
				}			
			}
		}
	}
	else {											//Disable it?
		hellLock[player] = 0;
		ElevatorSet(hellDown, 100); 				//Send Hellavator to 1st Floor.
		light(41, 0);								//Turn off HELL FLASHER
		light(24, 0);								//Turn off both lights
		light(25, 0);
		light(30, 0);								//Lock is NOT lit			
	}

}


//FUNCTIONS FOR HOSPITAL MODE 1.................................
void HospitalAdvance() {						//Logic that runs as we advance Hospital Mode 1

	AddScore(advanceScore);

	flashCab(0, 255, 0, 100);					//Flash the GHOST BOSS color	
	
	if (hosProgress[player] > 3) {									//Has mode already started, or are we waiting for the door to close?
		return;														//I'm not even sure how this would happen with the ball lock, but who knows?	
	}
	
	hosProgress[player] += 1;										//Normal advance		
	areaProgress[player] += 1;
	
	if (hosProgress[player] > 0 and hosProgress[player] < 4) {			//First 3 advances?
		playSFX(0, 'H', 48 + hosProgress[player], random(4) + 65, 255);	//Play hxA-hxD.wav files
		pulse(hosProgress[player] + 8);									//Pulse next one	
		video('H', 48 + hosProgress[player], 'A', allowSmall, 0, 200);			//Play first 3 videos		
	}
	
	if (hosProgress[player] < 4) {									//Always fill lights and set door
		for (int x = 0 ; x < hosProgress[player] ; x++) {			//in case we did a Double Advance
			light(x + 8, 7);										//Completed lights to SOLID
			pulse(x + 9);											//Pulse the next light
		}
		DoorSet(DoorOpen, 300);										//Set door to creak open, 25 cycles per position
	}
	
	if (hosProgress[player] == 4) {									//Mode start?
	
		Mode[player] = 1;											//Set hospital mode ACTIVE for player 1.
		Advance_Enable = 0;											//At this point we can't advance any other modes until Ghost is defeated or we loose.
		DoorSet(DoorClosed, 1);					//DoorSet(DoorClosed, 50);									//Shut door fast!									//Shut door fast!
	}
	
}

void HospitalStart() {							//What happens when we shoot "Doctor Ghost" when lit

	videoModeCheck();
	
	restartKill(1, 1);							//In case we got the Restart
	comboKill();								//So combo lights don't appear after the mode
	storeLamp(player);							//Store the state of the Player's lamps
	allLamp(0);									//Turn off the lamps

	spiritGuideEnable(0);						//No spirit guide during Hospital
	
	modeTotal = 0;								//Reset mode points	
	AddScore(startScore);

	minionEnd(0);								//Disable Minion mode, even if it's in progress
	
	setGhostModeRGB(0, 255, 0);					//Green mode color
	setCabModeFade(0, 255, 0, 200);				//Set mode color to GREEN, fade to that color

	popLogic(3);								//Set pops to EVP

	ghostLook = 0;
	ghostBored = 0;								//Prevents his look action from happening
	LeftTimer = 1;								//Set this so it can't re-trigger

	if (countGhosts() == 5) {						//Is this the last Boss Ghost to beat?
		blink(48);									//Blink that progress light
	}	
	
	pulse(17);
	pulse(18);
	pulse(19);
	
	light(8, 0);
	light(9, 0);
	light(10, 0);
	light(11, 0);								//Turn off advance lights
	
	blink(57);									//Blink the HOSPITAL mode light
	
	tourReset(B00101011);						//Tour: Left orbit, center shot, right orbit, scoop	
	
	hosProgress[player] = 6;					//Set flag so mode only "starts" once
	
	killQ();													//Disable any Enqueued videos	
	int whichClip = random(3) + 65;								//Get the number first so they match ASCII A-C
	video('H', '4', whichClip, allowSmall, 0, 255);				//Play hxA-hxD.wav files
	playSFX(0, 'H', '4', whichClip, 255);						//Play hxA-hxD.wav files

	customScore('H', '7', 'D', allowAll | loopVideo);		//Shoot Ghost custom score prompt
	numbers(8, numberScore | 2, 0, 0, player);	//Show player's score in upper left corner
	numbers(10, 9, 88, 0, 0);					//Ball # upper right
	
	jackpotMultiplier = 1;						//Reset this just in case
	
	ghostAction = 5100;							//Set flag for him to jiggle near door
	// There is a possible race here if a glancing shot starts a minion, then immediately starts Dr. Ghost
	// Using a TargetTimerSet() instead of TargetSet() clears any minion TargetDown that is pending
	//TargetSet(TargetUp);						//Put targets UP!
	TargetTimerSet(1, TargetUp, 1);
		
	patientStage = 0;							//What stage of Ghost Patient you're at
	patientsSaved = 0;							//How many you saved, through Murder!
	
	DoctorState = 0;												//Set ghost to start as Not Distracted
	modeTimer = 0;													//Used to animate the door
	
	//BLINK GHOST LIGHTS SO WE KNOW TO HIT HIM!
	playMusic('B', '1');											//Boss battle music!
	
	activeBalls -= 1;												//Remove a ball from being "Active"
	AutoPlunge(100000);												//Set flag to launch second ball	
	hellEnable(1);
	showProgress(1, player);					//Show the Main Progress lights
	DoorSet(DoorClosed, 1);
	
	trapDoor = 1;								//Flag that ball should be trapped behind door
	hosTrapCheck = 0;
	skip = 10;

	ballSave();												//I'll be nice :)

  
}

void HospitalLogic() {							//Stuff that happens during Doctor Ghost Battle

	if (hosProgress[player] == 4) {				//Mode just started, door closing?
		if (DoorSpeed == 0) {					//Did door stop moving yet? (Is it closed?)
			HospitalStart();					//"Officially" start mode
		}
	}
			
	if (hosProgress[player] > 5 and hosProgress[player] < 9) {		//Are we trying to save our friend?
	
		if (DoctorState == 1 and popsTimer == 0) {				//Ghost distracted?
			DoctorTimer += 1;									//Increment timer

			if (DoctorTimer == (DoctorTarget / 2)) {			//Only used for Seconds counter
				countSeconds -= 1;
				numbers(0, numberStay | 4, 0, 0, countSeconds - 1);				//Update the Numbers Timer.
				
				if (countSeconds > 1 and countSeconds < 7) {
					playSFX(2, 'A', 'M', 47 + countSeconds, 1);					//Hurry-Up beep
				}
				else {
					playSFX(2, 'Y', 'Z', 'Y', 1);				//Beeps
				}
			}
			
			if (DoctorTimer == DoctorTarget) {					//Time to move? Ghost moves every other second
				
				DoctorTimer = 0;								//Reset timer
				ghostMove(GhostLocation - 10, 700);				//Move ghost back towards door...					
				
				countSeconds -= 1;								//Subtract!
				numbers(0, numberStay | 4, 0, 0, countSeconds - 1);				//Update the Numbers Timer.	
				
				
				if (countSeconds > 1 and countSeconds < 7) {
					playSFX(2, 'A', 'M', 47 + countSeconds, 1);					//Hurry-Up beep
				}
				else {
					playSFX(2, 'Y', 'Z', 'Y', 1);				//Beeps
				}				
				
				if (GhostLocation == (GhostDistracted - 10)) {							//Did he move twice?
					playSFX(0, 'H', hosProgress[player] + 48, 'G' + random(3), 255);	//Doctor dictates
					video('H', '6', 'Z', allowSmall, 0, 200);							//Video of dictating
				}
				if (GhostLocation == GhostMiddle) {										//Is ghost halfway back?
					playSFX(0, 'H', hosProgress[player] + 48, random(3) + 'D', 255);	//Kaminski pleas for help!
				}
				if (GhostLocation == GhostAtDoor) {										//Is ghost back to door?
					playSFX(0, 'H', hosProgress[player] + 48, 'G' + random(3), 255);	//Doctor dictates
					video('H', '6', 'Z', allowSmall, 0, 200);							//Video of dictating with PROMPT
					killTimer(0);
					DoctorState = 0;													//Set Doctor Flag to NOT distracted - must hit Ghost again!
					ghostAction = 5500;												//Set flag for him to jiggle near door
					light(8, 0);								//Switch lights back
					light(9, 0);
					light(10, 0);
					light(11, 0);	
					pulse(17);
					pulse(18);
					pulse(19);
					light(hosProgress[player] + 1, 7);			//Use number to indicate progress
				}					
			}
		}
	
	}
	
	if (hosProgress[player] == 9) {								//Did we just bash the door a 3rd time, freeing our friend?

		HospitalMultiball();

	}

	if (hosProgress[player] == 10) {					//During Doctor Ghost multiball!
		modeTimer += 1;
		if (modeTimer == 120000) {
			lightningStart(1);		
			int x = random(10);
			if (x < 5) {
				playSFX(0, 'H', 'C', '0' + random(9), 200);	//Team Leader commanding ghost to leave and stuff
			}
			else {
				playSFX(0, 'L', 'G', '0' + random(8), 200);	//Random lightning		
			}				
		}		
		if (modeTimer == 150000) {
			modeTimer = 0;
		}		
	}	
	
}

void HospitalSwitchCheck() {					//What happens when you hit the Ghost Targets during the battle 

	if (hosProgress[player] < 9) {					//Still trying to distract the ghost?

		video('H', '6', 'A', allowSmall, 0, 200);	//Ghost distracted away from door!
		
		doctorHits += 1;
		
		AddScore(50000 * doctorHits);				//Spam the doctor for more points	
		
		ghostMove(GhostDistracted, 20);				//Move the ghost away from door

		if (doctorHits == 1) {						//First time we've hit him?
			playSFX(0, 'H', hosProgress[player] + 48, random(3) + 'A', 200);	//Play the progress + A B or C clips
		}
		else {
			playSFX(2, 'H', '0', '2' + random(4), 190);//Random ghost wails of agony! Lower priority than Ghost Doctor Rambling
		}

		customScore('H', '7', hosProgress[player] + 65, allowAll | loopVideo);		//Shoot Door custom prompt 3 2 1 to go (files ending G H I)
		
		if (doctorHits == 4) {						//Repeat the loop to remind player what to do (prompt on hit 1)
			doctorHits = 0;
		}
				
													//You can keep distracting the ghost but we DON'T advance until you then hit the door.
		light(16, 0);								//Switch lights back
		light(17, 0);
		light(18, 0);
		light(19, 0);
		strobe(8, 7);
		ghostFlash(100);		
		ghostAction = 0;							//Disable Ghost Jitters
		countSeconds = 21;							//Ghost goes from 120 to 10, 110 degrees, 10 degrees per move, 11 moves, move every other second = 22 seconds
		numbers(0, numberStay | 4, 0, 0, countSeconds - 1);			//Show the Numbers timer
		DoctorState = 1;							//Set flag that ghost is distracted
		DoctorTimer = 0;							//Reset timer
		DoctorTarget = longSecond * 2;					//New target
	}	

}

void HospitalMultiball() {						//Ghost defeated, beat the crap out of him

	AddScore(winScore);												//5 mil for beating him
	sendJackpot(0);													//Send current jackpot value to Score #0
	
	spiritGuideEnable(0);											//No spirit guide during MB
	ghostLook = 1;													//Ghost will now look around again.
	ghostAction = 0;												//Disable this.
	strobe(8, 7);													//Strobe the door for POISON!
	
	light(57, 7);													//HOSPITAL solid = Mode Won!
	blink(16);														//Blink the JACKPOT light
	strobe(17, 3);
	
	killTimer(0);													//Turn off numbers	
	killQ();														//Disable any Enqueued videos	
  
  winMusicPlay();                         //Play user-selected Win Music
  
	playSFX(0, 'H', '8', 'J' + random(3), 255);						//Let's kick his ass quotes
	video('H', '8', 'J', allowSmall, 0, 255);						//"Escape" video
	ghostMove(90, 20);	
	TargetTimerSet(50, TargetDown, 10);
	//TargetSet(TargetDown);										//Allow Ghost bashing!
	DoorSet(DoorOpen, 1);											//Open door fast! We'll close it upon losing second ball

	KickLeft(16000, vukPower);										//Release captured ball!
	trapDoor = 0;													//Flag that ball shouldn't be trapped behind door	
	activeBalls += 1;												//Increase active balls to 2.
	ballSave();														//Ball save on Multiball

	customScore('B', '1', 'D', allowAll | loopVideo);				//Custom Score: Hit ghost for JACKPOTS!
	numbers(8, numberScore | 2, 0, 0, player);						//Put player score upper left
	numbers(9, numberScore | 2, 72, 27, 0);							//Use Score #0 to display the Jackpot Value bottom off to right
	numbers(10, 9, 88, 0, 0);										//Ball # upper right
	
	modeTimer = 0;													//Reset timer for exorcist quotes
	hosProgress[player] = 90;										//Set this so the "End Battle" can start only once. It's at 90 until left VUK kicks, then goes to 10
	ModeWon[player] |= 1 << 1;										//Set HOSPITAL WON bit for this player.	

	if (countGhosts() == 6) {										//This the final Ghost Boss? Light BOSSES solid!
		light(48, 7);
	}	
	
	videoModeCheck();	
	multipleBalls = 1;												//When MB starts, you get ballSave amount of time to loose balls and get them back
	ballSave();														//That is, Ball Save only times out, it isn't disabled via the first ball lost		
	
}

void HospitalWin() {							//We come here when down to 1 ball in multiball

	if (multiBall) {							//Was a MB stacked?
		multiBallEnd(1);						//End it, with flag that it's ending along with a mode
	}	

	multipleBalls = 0;
	tourClear();								//Clear the tour lights / values

	loadLamp(player);
	comboKill();
	
	spiritGuideEnable(1);						//Allow it
	patientStage = 0;
	
	ghostModeRGB[0] = 0;
	ghostModeRGB[1] = 0;
	ghostModeRGB[2] = 0;
	ghostFadeTimer = 200;
	ghostFadeAmount = 200;
	setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color

	light(16, 0);													//Turn off Ghost lights
	light(17, 0);
	light(18, 0);
	light(19, 0);
	
	light(8, 0);													//Turn off Hospital Advance lights
	light(9, 0);
	light(10, 0);
	light(11, 0);
	
	ghostLook = 1;													//Ghost will now look around again.
	ghostAction = 0;
	
	light(16, 0);													//Turn off Make Contact
	light(57, 7);													//Make Hospital Mode light solid, since it HAS been won
	light(31, 0);	
	
	killTimer(0);													//Turn off numbers
	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();
	
	playSFX(0, 'H', '9', 'X' + random(3), 255);						//Mode Complete dialog	

	killQ();														//Disable any Enqueued videos
	video('H', '9', 'X', noExitFlush, 0, 255);						//Mode won, prevent numbers
	numbersPriority(0, numberFlash | 1, 255, 11, modeTotal, 233);	//Load Mode Total Points as Number	
	modeTotal = 0;													//Reset mode points	
	videoQ('H', '9', 'Y', noEntryFlush | B00000011, 0, 233);		//Mode Total Video	

	playMusic('M', '2');											//Normal music
	
	Mode[player] = 0;												//Set mode active to None
	hosProgress[player] = 100;										//Prevents a restart
	ModeWon[player] |= 1 << 1;										//Set HOSPITAL WON bit for this player.	
	ghostsDefeated[player] += 1;									//For bonuses
	Advance_Enable = 1;												//Allow other modes to be started

	if (countGhosts() == 2 or countGhosts() == 5) {	//Defeating 2 or 5 ghosts lights EXTRA BALL
	
		extraBallLight(2);							//Light extra ball, no prompt we'll do there
		//videoSFX('S', 'A', 'A', allowSmall, 0, 255, 0, 'A', 'X', 'A' + random(2), 255);	//"Extra Ball is Lit!"			
	
	}	
	
	demonQualify();									//See if Demon Mode is ready

	checkModePost();

	for (int x = 0 ; x < 6 ; x++) {					//Make sure the MB lights are off
		light(26 + x, 0);
	}
	hellEnable(1);		
	showProgress(0, player);					//Show the Main Progress lights
		
}

int HospitalFail() {							//You fail when you lose your second ball before freeing Friend. But we do logic to see if you get a Do-Over, or a Drain.

	multipleBalls = 0;
	tourClear();								//Clear the tour lights / values

	loadLamp(player);

	spiritGuideEnable(1);						//Allow Spirit Guide again
	patientStage = 0;
	
	ghostModeRGB[0] = 0;
	ghostModeRGB[1] = 0;
	ghostModeRGB[2] = 0;
	ghostFadeTimer = 100;
	ghostFadeAmount = 100;
	setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color

	killTimer(0);
	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();	
	swDebounce[23] = 25000;											

	light(16, 0);													//Turn off Ghost lights
	light(17, 0);
	light(18, 0);
	light(19, 0);
	
	trapDoor = 0;													//Flag that ball shouldn't be trapped behind door
	modeTotal = 0;													//Reset mode points
		
	if (ModeWon[player] & hospitalBit) {								//Did we win this mode before?
		light(57, 7);												//Make Hospital Mode light solid, since it HAS been won
	}
	else {
		light(57, 0);												//Haven't won it yet, turn it off
	}

	ghostMove(90, 20);													//Turn ghost back to center	
	ghostLook = 1;													//Ghost will now look around again.
	ghostAction = 0;
	
	Mode[player] = 0;												//Set mode active to None
	Advance_Enable = 1;												//Allow other modes to be started

	//checkModePost();
	hellEnable(1);
					
	if (modeRestart[player] & (1 << 1) and tiltFlag == 0) {			//Able to restart Hospital?
		//Serial.println("HOS FAIL RESTART");
		modeRestart[player] &= ~(1 << 1);							//Clear the restart bit	
		if (hosTrapCheck == 0) {									//Don't kick the ball if we already did that
			LeftTimer = 16000;										//Manually set the kick out.
			LeftPower = vukPower;			
		}
		modeTimer = 25000;		
		DoorSet(DoorOpen, 2);										//Open door quickly
		ghostMove(10, 255);											//Ghost will slowly turn towards door!
		restartBegin(1, 11, 25000);									//Enable a restart!		
		hosProgress[player] = 3;									//Allows you to re-start the mode
		strobe(8, 3);												//Strobe lights under door		
		light(9, 0);		
		light(10, 0);
		blink(11);													//Blink GHOST DOCTOR
		playMusic('H', '2');										//Hurry Up Music!		
		video('H', '8', 'Y', allowSmall, 0, 255); 					//Mode fail! Shoot door to restart!
		killQ();													//Disable any Enqueued videos	
		playSFX(0, 'H', 'Z', random(6) + 65, 255);						//Mode FAIL dialog		
		showProgress(0, player);									//Show the Main Progress lights
		return 1;													//Flag to prevent a drain!
	}
	else {															//End mode, and let the ball drain
		//Serial.println("HOS FAIL END");
		checkModePost();
		myservo[DoorServo].write(DoorOpen); 						//Set servo
	
		if (tiltFlag == 0) {
			LeftTimer = 1100;										//Manually set the kick out super quick
			LeftPower = vukPower;									//A tilt does a ball search, no need to in that condition
		}
		hosProgress[player] = 0;									//Gotta start over
		light(11, 0);												//Turn off Doctor Ghost light
		showProgress(0, player);
		return 0;													//Let the ball drain
	}

	comboEnable = 1;												//OK combo all you want	
	
	for (int x = 0 ; x < 6 ; x++) {					//Make sure the MB lights are off
		light(26 + x, 0);
	}
	
	showProgress(0, player);
	
}
//END FUNCTIONS HOSPITAL MODE 1..................


void HospitalRestart() {						//Allows a quick restart if a Ball Search fucked up the mode

	multipleBalls = 0;
	tourClear();								//Clear the tour lights / values

	loadLamp(player);

	spiritGuideEnable(1);						//Allow Spirit Guide again
	patientStage = 0;
	
	ghostModeRGB[0] = 0;
	ghostModeRGB[1] = 0;
	ghostModeRGB[2] = 0;
	ghostFadeTimer = 100;
	ghostFadeAmount = 100;
	setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color

	killTimer(0);
	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();	

	light(16, 0);													//Turn off Ghost lights
	light(17, 0);
	light(18, 0);
	light(19, 0);
	
	trapDoor = 0;													//Flag that ball shouldn't be trapped behind door
	hosTrapCheck = 0;												//Clear this!
	modeTotal = 0;													//Reset mode points

	Mode[player] = 0;												//Set mode active to None
	Advance_Enable = 1;												//Allow other modes to be started

	//checkModePost();
	hellEnable(1);
	
	DoorSet(DoorOpen, 2);										//Open door quickly

	ghostMove(90, 20);											//Turn ghost back to center	
	ghostLook = 0;												//Ghost won't look around
	ghostAction = 0;											//Disable its animation
		
	hosProgress[player] = 3;									//Allows you to re-start the mode
	strobe(8, 3);												//Strobe lights under door		
	light(9, 0);		
	light(10, 0);
	blink(11);													//Blink GHOST DOCTOR	
	video('H', '8', 'Y', allowSmall, 0, 255); 					//Mode fail! Shoot door to restart!
	killQ();													//Disable any Enqueued videos	
	playSFX(0, 'H', 'Z', random(6) + 65, 255);					//Mode FAIL dialog		
	showProgress(0, player);									//Show the Main Progress lights
	playMusic('M', '2');										//Normal music
	
}

int hotelPathLogic() {

	animatePF(220, 10, 0);

	ghostLooking(160);
	
	comboCheck(3);													    //Always check for combo shot!

  if (Mode[player] == 8) {                    //Bumps in the night?
    bumpCheck(3);                       //Check that function and return out
    return 1;
  }
  
	if (Mode[player] == 6) {										//Prison?
		tourGuide(1, 6, 3, 25000, 1);								//Check that part of the tour!
		return 1;
	}
	
	if (Mode[player] == 4) {										//War fort?
		
		if (multiBall & multiballHell) {							//If MB stacked, first collect Tour. Once collected, it returns a 0 allows Jackpot increase
			if (tourGuide(1, 4, 3, 0, 0) == 0) {					//Already did this part of tour?
				multiBallJackpotIncrease();
			}		
		}
		else {
			int x = random(8);
			playSFX(0, 'W', '5', 'A' + x, 210);						//Random Army Ghost lines
			if (tourGuide(1, 4, 3, 25000, 0) == 0) {
				video('W', '5', 'A' + x, allowSmall, 0, 250);		//Synced taunt video
			}														//Check that part of the tour (no WHOOSH sound needed)
		}
		return 1;
	}	
	
	if (Mode[player] == 1) {										//Hospital Mode?

		if ((hosProgress[player] > 5 and hosProgress[player] < 9) and (multiBall & multiballHell)) {
			multiBallJackpotIncrease();
			return 1;
		}
	
		if (hosProgress[player] == 10) {			//Hospital, fighting the Ghost Doctor?
			if (patientStage == 0) {									//Haven't got the poison yet, and have a MB? Then this advances Jackpot
				if (multiBall & multiballHell) {						
					multiBallJackpotIncrease();
					return 1;			
				}
				else {
					video('H', '7', 'A', allowSmall, 0, 240);			//Sick ghost in bed		
					playSFX(0, 'I', 'P', 'A' + random(4), 240);			//"Kill.... me...."
					strobe(8, 7);										//Strobe the door for POISON!	
					return 1;				
				}			
			}
			else {
				video('H', '7', 'C', allowSmall, 0, 255);				//Ghost freed!
				playSFX(0, 'I', 'P', 'S' + random(8), 255);				//"Die!" "Thank you kind sir!"
        
        if ((achieve[player] & hospitalBit) == 0) {     //First time we've done this?
        
          achieve[player] |= hospitalBit;               //Set the bit
          
          if ((achieve[player] & allWinBit) == allWinBit) {           //Did we get them all? Add the multiplier prompt
            videoQ('R', '7', 'E', 0, 0, 255);           //All sub modes complete!
            demonMultiplier[player] += 1;							  //Add multiplier for demon mode
            playSFXQ(0, 'D', 'Y', 'A' + random(6), 255); //Add Multiplier! 
          }
          
        }
             
				patientsSaved += 1;
				showValue((patientsSaved * 250000) + (patientStage * 10000), 40, 1);				//Flash the points we got
				patientStage = 0;										//Reset patient stage
				strobe(8, 7);											//Strobe the door for POISON!
				hellEnable(1);											//Until you make the Poison shot, you can go for multiball. Re-enable MB here
				if (multiBall & multiballHell) {
					strobe(26, 5);										//If MB active, re-strobe Ramp for Jackpot Increase
				}
				else {
					light(26, 0);											//Turn off RAMP STROBE			
				}
				return 1;		
			}		
		}
		
	}		
					
	if (deProgress[player] > 9 and deProgress[player] < 100) {		//Trying to weaken demon
		DemonCheck(3);
		return 1;
	}		
	
	if (Advance_Enable and hotProgress[player] < 3) {				//Able to advance modes, and Hotel not started yet?
		HotelAdvance();	
		return 1;
	}

	if (Mode[player] == 7) {										//Are we in Ghost Photo Hunt?
		photoCheck(3);
		return 1;
	}

	if (Mode[player] == 5) {										//Hotel ghost?

		if (hotProgress[player] == 20) {							//Hotel shot isn't used during control box search	
			AddScore(10000);										//Some points			
			EVP_Jackpot[player] += 25000;							//Moar points plz!			
			numbers(3, numberFlash | 1, 255, 11, EVP_Jackpot[player]);	//Load Jackpot value Points as a number
			video('Q', 'J', 'C', noEntryFlush | B00000011, 0, 255);		//Show new Jackpot value
			playSFX(2, 'A', 'Z', 'Z', 255);								//Generic shot WHOOSH sound
			strobe(26, 5);												//Strobe first 5 lights	to indicate Hotel Path still does something (builds jackpot)			
			//video('L', '5', 'E', allowSmall, 0, 255);				//Prompt to shoot flashing camera icons
			return 1;
		}	

		if (hotProgress[player] == 35) {								//When fighting ghost, only time you can shoot through Hotel shot is if you've hit Hellavator to light Jackpot	
			AddScore(100000);											//Some points
			playSFX(0, 'L', '8', 'I' + random(8), 255);					//Hit the ghost for Jackpot!
			video('L', 'G', '0' + jackpotMultiplier, allowSmall, 0, 250);	//Show Multiplier
			return 1;
		}	
		
	}

	if (theProgress[player] > 9 and theProgress[player] < 100) {	//Theater Ghost?		
		TheaterPlay(0);												//Incorrect shot, ghost will bitch!
		return 1;
	}

	if (multiBall & multiballHell) {								//If stacked with Ghost Euthanasia, don't advance value if we need to euthanize ghost							
		multiBallJackpotIncrease();
		return 1;
	}	
	
	comboVideoFlag = 0;												//Nothing active? Reset video combo flag
	AddScore(5000);													//Some points
	video('C', 'G', 'D', allowSmall, 0, 250);						//Regular Combo to the Left <-
	playSFX(2, 'A', 'Z', 'Z', 255);									//Whoosh!
	
	return 1;														//Can combo

}

//FUNCTIONS FOR HOTEL MODE 5.................................
void HotelAdvance() {							//What happens when we shoot up right ramp and advance Hotel

	AddScore(advanceScore);
	flashCab(0, 255, 0, 100);					//Flash the GHOST BOSS color

	hotProgress[player] += 1;											//Advance progress (will be at least 1)
	areaProgress[player] += 1;
	
	if (hotProgress[player] < 4) {										//First 3 advances?
		playSFX(0, 'L', 48 + hotProgress[player], random(4) + 65, 255);	//First 3 sets of Hotel advance sounds.
		video('L', 48 + hotProgress[player], 'A', allowSmall, 0, 255);			//Adance videos
		pulse(26);												//Have 1 pulsing at minimum
		if (hotProgress[player] < 4) {							//First 3 advances?
			for (int x = 0 ; x < hotProgress[player] ; x++) {	//Fill the lights!
				light(x + 26, 7);								//Completed lights to SOLID
				pulse(x + 27);									//Pulse the next light
			}		
		}	
	}
	
	if (hotProgress[player] == 3) {								//Did we go here the 3rd time?
		ElevatorSet(hellUp, 200);								//Move the elevator into 2nd floor position
		light(24, 0);							//Turn off CALL ELEVATOR lights
		light(25, 0);
		blink(41);								//Blink HELL FLASHER
	}

}

void HotelStart1() {							//Ball goes into Hellavator, heading down...

	videoModeCheck();

	comboKill();
	storeLamp(player);							//Store the state of the Player's lamps
	allLamp(0);									//Turn off the lamps

	spiritGuideEnable(0);						//No spirit guide

	Advance_Enable = 0;							//Mode has started, others can't
	Mode[player] = 5;							//Mode has begun, enable its logic	
	minionEnd(0);								//Disable Minion mode, even if it's in progress
	
	modeTotal = 0;								//Reset mode points	
	AddScore(startScore);
	
	setFadeRGB(200, 140, 0, 1000);				//Fade into a kind of brown colored ghost
	setCabModeFade(0, 255, 0, 600);				//Turn lighting GREEN (with envy)
			
	popLogic(3);								//Set pops to EVP

	light(29, 7);								//Bellboy ghost SOLID, we found him	
	blink(61);									//Blink Hotel Mode light
	hotProgress[player] = 10;					//Set flag to "Elevator Dropping"
	playSFX(0, 'L', '4', 'A' + random(4), 255);	//Play l5A-l5D.wav files
	video('L', '4', 'A', allowSmall, 0, 255);	//Video of button pushed
	killQ();									//Disable any Enqueued videos
	hellLock[player] = 0;						//Since we use the Hellavator for Jackpots, can't stack a MB	
	HellBall = 10;								//Set flag so it won't retrigger
	ElevatorSet(hellStuck, 600);				//Send elevator to Stuck position slowly
	showProgress(1, player);					//Show the Main Progress lights

	skip = 50;									//Set skip event for Elevator move
		
}

void HotelStart2() {							//Ball gets stuck, gotta find control box!

	hotProgress[player] = 15;											//Set flag to "Ball Rolling Towards Scoop"
	playSFX(0, 'L', '4', 'E' + random(4), 255);							//Play l5A-l5D.wav files
	video('L', '4', 'B', allowSmall, 0, 255);							//Video of button pushed
	ElevatorSet(hellDown, 300);											//Send elevator to basement to release the ball

	customScore('L', 'P', 'A', allowAll | loopVideo);					//Shoot Camera Icons! custom score prompt
	numbers(8, numberScore | 2, 0, 0, player);							//Show player's score in upper left corner
	numbers(10, 9, 88, 0, 0);											//Ball # upper right	
	
	light(41, 0);														//Turn off HELL FLASHER
	
	for (int x = 0 ; x < 5 ; x++) {
		ControlBox[x] = 0;												//Clear Control Box locations	
	}
		
	if (tournament == 0) {												//Unless we're in tourney mode where 3rd shot always wins...
		ControlBox[random(5)] = 255;									//Randomly select ONE location to have the control box. (255 flag)
	}
	
	DoorSet(DoorOpen, 5);												//Open the Spooky Door, if it isn't already

	if (countGhosts() == 5) {						//Is this the last Boss Ghost to beat?
		blink(48);									//Blink that progress light
	}
	
	pulse(7);															//Pulse all the Camera Lights, sans Hotel one
	pulse(14);
	pulse(23);
	pulse(39);
	pulse(47);

	//Set STROBING lights to indicate shots. Can't do this until we write the LIGHT SAVE STATE CODE

	strobe(26, 5);												//Strobe first 5 lights	to indicate Hotel Path still does something (builds jackpot)	
	
	modeTimer = 0;								//Reset mode timer for prompts

	photoWhich = 0;								//We use this to count the shots. In tourney mode, 3rd shot always finds control box.
	
	TargetTimerSet(5000, TargetUp, 100);
	playMusic('B', '1');						//Boss battle music!
	
	hellLock[player] = 0;						//Disable lock manually
	comboEnable = 0;							//Combos during Control Box search would be confusing, so no
	
	skip = 0;									//Reset skip ability
	
}

void HotelLogic() {								//Logic during control box search / ghost battle

	if (hotProgress[player] == 10) {										//Waiting for the elevator to get stuck?

		if (HellLocation == hellStuck) {								//Did the Hellavator make it to the Stuck position?
			HotelStart2();											//Time for Battle! Find control box and banish ghost!
		}
		
	}

	if (hotProgress[player] == 20) {								//Looking for control box?
		modeTimer += 1;
		if (modeTimer == 150000) {									//Random ghost taunt?
			modeTimer = 0;											//Reset timer
			playSFX(0, 'L', '5', 'A' + random(22), 200);				//Will not override advance dialog
			video('L', '5', 'A', allowSmall, 0, 100);						//Will not override video
		
		}
	}

}

void HotelMultiball() {							//What happens when you find the control box

	jackpotMultiplier = 1;						//Starts at 1			

	AddScore(winScore);												//You won, so Point Get

	light(7, 0);													//Turn off all CAMERA LIGHTS
	light(14, 0);
	light(23, 0);
	light(39, 0);
	light(47, 0);

	ghostLook = 1;													//Ghost will now look around again.
	
	light(61, 7);													//HOTEL solid = Mode Won!
	
	blink(17);														//Blink ADVANCE JACKPOT
	blink(18);
	blink(19);
	light(16, 0);													//Make sure JACKPOT is off
	
	strobe(26, 6);													//Strobe the Hotel Lights

	pulse(14);														//Pulse the door for Ghost Eviction

	tourReset(B00101011);			//Tour: Left orbit, up center, right orbit, scoop	  OLD Tour: Left orbit, spooky VUK, up center, balcony
	
	targetReset();													//Reset the target
	
	winMusicPlay();											//Play annoying Ghost Squad theme!		
	playSFX(0, 'L', '7', 'A' + random(3), 255);						//Yeah! We fuckin' did it!
	killQ();														//Disable any Enqueued videos

	video('L', '7', 'A', allowSmall, 0, 255);						//Pull lever video
	videoQ('L', '8', 'D', allowSmall, 0, 200);						//"Ramp lights Jackpot"	
	
	sendJackpot(0);													//Send jackpot value to score #0
	
	customScore('L', 'P', 'B', allowAll | loopVideo);				//Prompt for Ramp and Target Multiplier
	numbers(8, numberScore | 2, 0, 0, player);						//Put player score upper left
	numbers(9, numberScore | 2, 72, 27, 0);							//Use Score #0 to display the Jackpot Value bottom off to right
	numbers(10, 9, 88, 0, 0);										//Ball # upper right
		
	ghostMove(90, 15);	
	
	if (extraLit[player] == 0) {									//An EB could be lit, and not collected during Control Box search.
		DoorSet(DoorClosed, 200);									//Else, closes the door for GHOST EVICTION!		
	}
	

	TargetTimerSet(10, TargetUp, 10);								//Put targets UP
	ElevatorSet(hellUp, 100);										//Move elevator UP so you can shoot it to Light Jackpot
	blink(41);														//HELL FLASHER!
	
	hotProgress[player] = 30;										//Set this so the "End Battle" can start only once.
	ModeWon[player] |= 1 << 5;										//Set HOTEL WON bit for this player.	

	if (countGhosts() == 6) {										//This the final Ghost Boss? Light BOSSES solid!
		light(48, 7);
	}
	
	convictState = 1;												//Use same variable as Prison Free Ghost for GHOST EVICTION!
	convictsSaved = 0;												//Reset How many you've evicted
	
	AutoPlunge(autoPlungeFast);												//Set flag to launch second ball

	multipleBalls = 1;												//When MB starts, you get ballSave amount of time to loose balls and get them back
	ballSave();														//That is, Ball Save only times out, it isn't disabled via the first ball lost														
	
	comboEnable = 1;												//OK combo all you want
	
}

void HotelLightJackpot() {

	hotProgress[player] = 35;								//Set JACKPOT READY!
	playSFX(0, 'L', '8', 'I' + random(8), 255);				//Hit the ghost for Jackpot!
	killQ();
	
	//CHANGE VIDEO TO DISPLAY WHAT JACKPOT IS LIT
	video('L', 'G', '0' + jackpotMultiplier, allowSmall, 0, 250);		//Show Multiplier
	//videoQ('L', '8', 'B', allowSmall, 0, 240);						//Ghost cowers!

	customScore('B', '1', 'D', allowAll | loopVideo);		//Custom Score: Hit ghost for JACKPOT!
	sendJackpot(0);											//Send updated jackpot value to score #0
	
	light(17, 0);		//First turn them all off
	light(18, 0);
	light(19, 0);
	
	//Blink the Ghost Targets that we hit already
	if (gTargets[0] == 1) {
		blink(17);
	}
	if (gTargets[1] == 1) {
		blink(18);
	}
	if (gTargets[2] == 1) {
		blink(19);
	}
	
	pulse(16);												//Pulse MAKE CONTACT

	light(26, 0);											//Turn OFF Hotel Stobe
	TargetSet(TargetDown);									//Put targets down

}

void HotelJackpot() {

	blink(17);						//Blink ADVANCE JACKPOT
	blink(18);
	blink(19);
	light(16, 0);					//Make sure JACKPOT is off
	
	strobe(26, 6);													//Strobe the Hotel Lights
	targetReset();													//Reset the target values so we can re-multiply Jackpot
	ElevatorSet(hellUp, 100);										//Move elevator down
	blink(41);
	killQ();
	ghostFlash(50);
	playSFX(0, 'L', '8', 'Q' + random(4), 255);						//Jackpot sounds!
	video('L', 'J', '0' + jackpotMultiplier, allowSmall, 0, 255);	//Jackpot animation
	showValue(EVP_Jackpot[player] * jackpotMultiplier, 40, 1);		//Show what jackpot value was

	customScore('L', 'P', 'B', allowAll | loopVideo);				//Prompt for Ramp and Target Multiplier	
	
	hotProgress[player] = 30;										//Reset flag, we need to re-enable Jackpot
	TargetTimerSet(8000, TargetUp, 5);								//Put targets back up

	ghostAction = 20000;											//Whack routine
	
	jackpotMultiplier = 1;
	sendJackpot(0);													//Send updated jackpot value (no multiplier now) to score #0

}

void HotelWin() {								//When down to 1 ball, mode is won!

	multipleBalls = 0;

	tourClear();								//Clear the tour lights / values	
	
	loadLamp(player);								//Load the original lamp state back in
	comboKill();

	light(61, 7);													//HOTEL solid = Mode Won!
	AddScore(5000000);							//5 mil for beating him

	convictState = 0;
	
	ghostModeRGB[0] = 0;
	ghostModeRGB[1] = 0;
	ghostModeRGB[2] = 0;
	setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color
	ghostFadeTimer = 200;
	ghostFadeAmount = 200;

	killNumbers();
	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();	
	
	light(16, 0);													//Turn off Ghost Lights
	light(17, 0);
	light(18, 0);
	light(19, 0);
	
	light(26, 0);													//Turn off Advance Lights
	light(27, 0);
	light(28, 0);
	light(29, 0);

	ghostLook = 1;													//Ghost will now look around again.
	ghostAction = 0;	
	
	if (videoMode[player] == 0) {
		TargetTimerSet(5000, TargetUp, 100);							//Put targets back up, but not so fast ball is caught
	}
	
	playSFX(0, 'L', '9', 'A' + random(4), 255);						//Mode Complete dialog	

	killQ();														//Disable any Enqueued videos	
	video('L', '9', 'A', noExitFlush, 0, 255); 						//Play Death Video
	numbersPriority(0, numberFlash | 1, 255, 11, modeTotal, 233);	//Load Mode Total Points
	modeTotal = 0;													//Reset mode points		
	videoQ('L', '9', 'B', noEntryFlush | B00000011, 0, 233);		//Mode Total:	
	
	playMusic('M', '2');											//Normal music
	
	Mode[player] = 0;												//Set mode active to None
	hotProgress[player] = 100;										//Can't be restarted
	ModeWon[player] |= 1 << 5;										//Set HOTEL WON bit for this player.	
	ghostsDefeated[player] += 1;									//For bonuses
	
	Advance_Enable = 1;												//Other modes can start now
	
	if (countGhosts() == 2 or countGhosts() == 5) {	//Defeating 2 or 5 ghosts lights EXTRA BALL
	
		extraBallLight(2);							//Light extra ball, no prompt we'll do there
		//videoSFX('S', 'A', 'A', allowSmall, 0, 255, 0, 'A', 'X', 'A' + random(2), 255);	//"Extra Ball is Lit!"			
	
	}	
	
	demonQualify();									//See if Demon Mode is ready
			
	checkModePost();
	hellEnable(1);

	showProgress(0, player);					//Show the Main Progress lights
	
	spiritGuideEnable(1);
	
}

void HotelFail() {

	multipleBalls = 0;

	tourClear();								//Clear the tour lights / values	
	
	loadLamp(player);								//Load the original lamp state back in
	comboKill();
	
	convictState = 0;
	
	spiritGuideEnable(1);

	ghostModeRGB[0] = 0;
	ghostModeRGB[1] = 0;
	ghostModeRGB[2] = 0;
	ghostFadeTimer = 100;
	ghostFadeAmount = 100;
	setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color

	ghostLook = 1;													//Ghost will now look around again.
	ghostAction = 0;
	
	killNumbers();
	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();	
	
	light(7, 0);	//Turn off all CAMERA LIGHTS
	light(14, 0);
	light(23, 0);
	light(39, 0);
	light(47, 0);
	
	light(16, 0);													//Turn off Ghost Lights
	light(17, 0);
	light(18, 0);
	light(19, 0);

	if (ModeWon[player] & hotelBit) {								//Did we win this mode before?
		light(61, 7);												//Make Hospital Mode light solid, since it HAS been won
	}
	else {
		light(61, 0);												//Haven't won it yet, turn it off
	}

	ElevatorSet(hellDown, 100); 									//Make sure Hellavator is down
	light(25, 7);													//Current state is SOLID
	blink(24);														//Other state BLINKS
	light(30, 0);													//Lock is NOT lit
	modeTotal = 0;													//Reset mode points
	
	Mode[player] = 0;												//Set mode active to None	
	Advance_Enable = 1;												//Other modes can start now

	if (modeRestart[player] & hotelBit) {							//Able to restart Hotel?
		modeRestart[player] &= ~hotelBit;							//Clear the restart bit	
		hotProgress[player] = 3;										//Reset this to 2. Shoot the right ramp again will raise elevator and let you try again.
	}
	else {
		hotProgress[player] = 0;										//Reset this to 2. Shoot the right ramp again will raise elevator and let you try again.
	}
	
	showProgress(0, player);					//Show the Main Progress lights	

	checkModePost();
	hellEnable(1);

	
}
//END HOTEL MODE 5.................................

void BoxCheck(unsigned int whichSpot) {			//Code for looking for control box. Maybe update using Photo Hunt code? (it's much better)

	if (ControlBox[whichSpot] == 255) {				//Control box found? (this will never actually occur in Tournament mode)
		ControlBox[whichSpot] = 1;					//Set "Checked Here" flag
		HotelMultiball();
		return;										//Don't do other checks (prevents "miss" dialog when you actually get it)
	}
	if (ControlBox[whichSpot] == 1) {				//Did we already check here?
		playSFX(0, 'L', '6', 'U' + random(5), 255);	//"You already looked there!"
		video('L', '6', 'U' + random(6), allowSmall, 0, 200);		//Video of search		
		//videoQ('L', '5', 'E', allowSmall, 0, 100);			//Prompt to find Camera shot
	}	
	if (ControlBox[whichSpot] == 0) {				//First time we've checked here?
		photoWhich += 1;
		ControlBox[whichSpot] = 1;					//Set "Checked Here" flag
		//videoQ('L', '5', 'E', allowSmall, 0, 100);			//Prompt to find Camera shot

		switch (whichSpot) {						//Turn off the lights when we hit them
			case 0:
				light(7, 0);
				break;
			case 1:
				light(14, 0);
				break;
			case 2:
				light(23, 0);
				break;
			case 3:
				light(39, 0);
				break;
			case 4:
				light(47, 0);
				break;
		}
		if (tournament and photoWhich == 3) {	//In tournament mode, the 3rd unique Camera Shot you hit always = mode win
			HotelMultiball();
		}
		else {
			playSFX(0, 'L', '6', 'A' + random(13), 255);				//Play the "Its not here" sound l6A - l6E
			video('L', '6', 'A' + random(14), allowSmall, 0, 200);		//Video of search
		}	
	}		

}


void KickLeft(unsigned int kickTime, unsigned char lStrength) {

	if (hosProgress[player] > 3 and hosProgress[player] < 9) {		//Helps prevent ball ejects...
		return;														//Dring Doctor battle
	}

	badExit = 1;													//Prevents re-triggering. If ball doesn't go down left habitrail, this flag will kick ball if it ends up back in scoop
	LeftTimer = kickTime;
	LeftPower = lStrength;

}

void laneChange() {								//Changes lighted lanes when flippers pressed

	if (rollOvers[player] & B10001000) {	//G lit?
		light(52, 7);
	}
	else {
		light(52, 0);
	}
	if (rollOvers[player] & B01000100) {	//L lit?
		light(53, 7);
	}
	else {
		light(53, 0);
	}
	if (rollOvers[player] & B00100010) {	//I lit?
		light(54, 7);
	}
	else {
		light(54, 0);
	}
	if (rollOvers[player] & B00010001) {	//R lit?
		light(55, 7);
	}
	else {
		light(55, 0);
	}
		
	if (orb[player] & B00100100) {	//O lit?
		light(32, 7);
	}
	else {
		light(32, 0);
	}
	if (orb[player] & B00010010) {	//R lit?
		light(33, 7);
	}
	else {
		light(33, 0);
	}
	if (orb[player] & B00001001) {	//B lit?
		light(34, 7);
	}
	else {
		light(34, 0);
	}		
	
  if (burstLane) {                //If enabled, pulse the lane
    pulse(burstLane);   
  }

}

void leftOrbitLogic() {

	animatePF(190, 10, 0);

  if (Mode[player] == 8) {              //Bumps in the night?
    bumpCheck(0);                       //Check that function and return out
    return;
  }
  
	if (hellMB and minion[player] < 100) {
		tourGuide(3, 8, 0, 50000, 1);								//Check for GHOST CATCH, and give default 50k if we've already hit that spot
		return;
	}	
	
	if (Mode[player] == 4) {										//War fort active?

		int x = random(8);
		playSFX(0, 'W', '5', 'A' + x, 210);						//Random Army Ghost lines
		if (tourGuide(3, 4, 0, 25000, 0) == 0) {
			video('W', '5', 'A' + x, allowSmall, 0, 250);		//Synced taunt video
		}														//Check that part of the tour (no WHOOSH sound needed)		

		return;
	}
	
	if (barProgress[player] > 69 and barProgress[player] < 100) {	//Haunted Bar active?
		tourGuide(3, 3, 0, 25000, 1);								//Check that part of the tour!
		return;
	}
	
	if (Mode[player] == 1) {										//Hospital active?
		tourGuide(3, 1, 0, 25000, 1);								//Check that part of the tour!
		return;
	}
	
	if (hotProgress[player] > 29 and hotProgress[player] < 40) {	//Fighting the Hotel Ghost? (can't do tour during the Control Box search)
		tourGuide(3, 5, 0, 25000, 1);								//Check that part of the tour!
		return;
	}
	
	if (Mode[player] == 6) {										//Prison mode active?
		tourGuide(3, 6, 0, 25000, 1);								//Check that part of the tour!
		return;
	}
	
	if (Advance_Enable and priProgress[player] < 4) {				//Advancing Prison 1 2 3, or making 4th orbit shot to start?
		PrisonAdvance();											//Advance Prison (backstory))
		return;
	}
	
	if (hotProgress[player] == 20)	{								//Searching for the Control Box?
		BoxCheck(0);												//Check / flag box for this location
		return;
	}
	
	if (Mode[player] == 7) {										//Are we in Ghost Photo Hunt?
		photoCheck(0);
		return;
	}
	
	if (theProgress[player] > 9 and theProgress[player] < 100) {	//Theater Ghost?
		TheaterPlay(0);												//Incorrect shot, ghost will bitch!
		return;
	}
	
	if (deProgress[player] > 9 and deProgress[player] < 100) {		//Fighting the Demon?
		DemonCheck(0);
		return;
	}		
	
	if (minionMB > 9) {												//Minion MB Jackpot Increase?
		minionJackpotIncrease();
		MagnetSet(100);
		lightningStart(50000);
		return;
	}

	comboVideoFlag = 0;												//Nothing active? Reset video combo flag
	AddScore(5000);													//Some points
	video('C', 'G', 'E', allowSmall, 0, 250);						//Regular Combo to the Right ->	
	playSFX(2, 'A', 'Z', 'Z', 255);									//Whoosh!
	
	return;
	
}

int leftVUKlogic() {

	//animatePF(200, 10, 0);

	//Check if ball is supposed to be held behind door. If so, don't execute combos

	//BALL HOLD GOES HERE IF WE END UP MAKING THAT
	
	if (hosProgress[player] > 5 and hosProgress[player] < 9) {		//Should ball stay locked?
		return 0;														//Do nothing
	}

	if (deProgress[player] > 1 and deProgress[player] < 9) {
		return 0;														//Prevents ball from being kicked out
	}
		
	//OK, normal shot, continue:

	if (badExit) {													//Did ball not successfully exit the VUK and roll down the habitrail?	
		KickLeft(7000, vukPower);									//The default
		return 0;													//Return no combo
	}
	
	comboCheck(1);

  if (Mode[player] == 8) {              //Bumps in the night?
    bumpCheck(1);                       //Check that function and return out
		KickLeft(8000, vukPower);					  //Kick it out!    
    return 0;                           //No combos in this mode
  }  
  
	if (extraLit[player])	{										//Extra ball lit?
		extraBallCollect();											//Award it!
		KickLeft(31000, vukPower);									//Kick it out!
		return 1;
	}

	if (Advance_Enable and theProgress[player] == 3) {				  //Ready to start Theater mode?
		TheaterStart();												//If THEATER and DOCTOR are both lit, THEATER starts first.
		return 0;														//If THEATER is WON, DOCTOR can be started			
	}																//If THEATER fails (time out or drain) THEATER RE-LITES and will start if you shoot there again

	if (Mode[player] == 1 and hosProgress[player] == 10) {			//Hospital battle?
		AddScore(100000);											//Poison Points!
		video('H', '7', 'B', allowSmall, 0, 255);					//Poison Grab!		
		playSFX(0, 'I', 'P', 'E' + random(8), 255);
		if (patientStage < 5) {
			patientStage += 1;										//You can get up to 5 extra poisons for extra points. Not sure why. Who cares?
		}
		hellEnable(0);												//Disable Hell Lock (also puts Elevator to DOWN). Can't enable MB until you make right ramp shot to euthanize ghost patient
		light(8, 0);												//Turn OFF door strobe
		strobe(26, 5);												//Turn ON hotel path strobe
		KickLeft(7000, vukPower);									//The default
		return 1;
	}	

	if (Mode[player] == 6 and convictState == 2) {					    //We opened the door, now time to free a ghost?

		video('P', '8', 'Z', allowSmall, 0, 255);					//Ghost freed!
		playSFX(0, 'P', 'Z', 'A' + random(4), 255);
    
    if ((achieve[player] & prisonBit) == 0) {            //First time we've done this?
    
      achieve[player] |= prisonBit;                      //Set the bit
      
      if ((achieve[player] & allWinBit) == allWinBit) {             //Did we get them all? Add the multiplier prompt
        videoQ('R', '7', 'E', 0, 0, 255);             //All sub modes complete!
        demonMultiplier[player] += 1;							    //Add multiplier for demon mode
        playSFXQ(0, 'D', 'Y', 'A' + random(6), 255);  //Add Multiplier! 
      }
      
    }       
    
		convictsSaved += 1;
		showValue(convictsSaved * 100000, 40, 1);					//Flash what you scored for saving this convict
		
		convictState = 1;											//Go back to Door Closed state
		DoorSet(DoorClosed, 5);										//Open door quickly!
		light(8, 0);												//Turn off strobing
		pulse(14);													//Blink Camera shot
		modeTimer = 0;												//Reset this so prompt won't happen for a bit
		KickLeft(7000, vukPower);									//The default		
		return 1;
	}

	if ((hotProgress[player] > 29 and hotProgress[player] < 40) and convictState == 2) {	//Fighting the Hotel Ghost? (can't do tour during the Control Box search)
		//Ghost Eviction!
		convictsSaved += 1;
		video('L', 'E', '2', allowSmall, 0, 255);						//Ghost Evicted!
		playSFX(0, 'L', 'E', 'A' + random(9), 255);						//Random boot + ghost sound FX	
		
		if (convictsSaved < 10) {										//Haven't evicted them all yet?
    
      if ((achieve[player] & hotelBit) == 0) {            //First time we've done this?
      
        achieve[player] |= hotelBit;                      //Set the bit
        
        if ((achieve[player] & allWinBit) == allWinBit) {             //Did we get them all? Add the multiplier prompt
          videoQ('R', '7', 'E', 0, 0, 255);             //All sub modes complete!
          demonMultiplier[player] += 1;							    //Add multiplier for demon mode
          playSFXQ(0, 'D', 'Y', 'A' + random(6), 255);  //Add Multiplier! 
        }
        
      }      
    
			showValue(convictsSaved * 100000, 40, 1);					//Flash what you scored for saving this convict		
			convictState = 1;											//Go back to Door Closed state
			DoorSet(DoorClosed, 5);										//Close door
			light(8, 0);												//Turn off strobing
			pulse(14);													//Pulse Camera shot			
		}
		else {															//Kick out 10 to win?
			videoQ('L', 'E', '9', 2, 0, 255);							//All ghosts evicted!
			showValue(convictsSaved * 250000, 40, 1);					//Flash what you scored for evicting this ghost	
			convictState = 255;											//Set this state to avoid further triggers
			DoorSet(DoorClosed, 5);										//Close door
			light(8, 0);												//Turn off strobing
			light(14, 0);												//Turn off camera light		
		}
		KickLeft(7000, vukPower);										//The default
		return 1;
	}

	if (barProgress[player] > 69 and barProgress[player] < 100) {										//Haunted Bar?
		tourGuide(2, 3, 1, 25000, 1); 								//Check that part of the tour!
		KickLeft(7000, vukPower);										//The default
		return 1;
	}

	if (hellMB and minion[player] < 100) {
		tourGuide(2, 8, 1, 50000, 1);								//Check for GHOST CATCH, and give default 50k if we've already hit that spot
		KickLeft(7000, vukPower);										//The default
		return 1;
	}	
	
	if (goldHits == 10) {											                //Collecting gold?
		
		video('W', 'G', 'F', allowSmall, 0, 255);			//Got some gold!
		killQ();									//Disable any Enqueued videos
		playSFX(0, 'W', 'G', 'M' + random(8), 255);	//Ka-ching, Kaminski happy, Ghost mad!
    
    if ((achieve[player] & warBit) == 0) {            //First time we've done this?
    
      achieve[player] |= warBit;                      //Set the bit
      
      if ((achieve[player] & allWinBit) == allWinBit) {             //Did we get them all? Add the multiplier prompt
        videoQ('R', '7', 'E', 0, 0, 255);             //All sub modes complete!
        demonMultiplier[player] += 1;							    //Add multiplier for demon mode
        playSFXQ(0, 'D', 'Y', 'A' + random(6), 255);  //Add Multiplier! 
      }
      
    }    
    
		AddScore(500000);							//One meeeeleon points!
		goldTotal += 500000;//Keep track of how much gold we got X multiplier
		KickLeft(7000, vukPower);					//Kick it out fairly quickly
		return 1;	
	}

	if (deProgress[player] == 1 and Advance_Enable) {					//Ready to start Demon Battle, and can start a mode?
		DemonLock1();
		return 1;														//Don't want the ball to be kicked out (like Doctor Ghost mode)
	}

	if (deProgress[player] > 9 and deProgress[player] < 100) {			//Trying to weaken demon
		DemonCheck(1);
		if (activeBalls > 1) {
			KickLeft(7000 + ((activeBalls - 1) * 6300), vukPower);		//Give player a slight break... the more balls active the longer it is			
		}
		else {
			KickLeft(7000, vukPower);									//The default			
		}
		return 1;
	}
	
	if (Advance_Enable and (hosProgress[player] > 0 and hosProgress[player] < 4)) {	//IS this this 2nd or 3rd time we've hit this?
		HospitalAdvance();											//Advance Hospital
		KickLeft(7000, vukPower);									//If both DOCTOR and THEATER are lit, DOCTOR GHOST MODE starts first.			
		return 1;
	}
		
	if (hotProgress[player] == 20)	{								//Searching for the Control Box?
		BoxCheck(1);												//Check / flag box for this location
		KickLeft(11000, vukPower);									//Roll the ball back down
		return 1;
	}
	
	if (hotProgress[player] == 30 or hotProgress[player] == 35) {	//Hotel ghost battle?
		KickLeft(11000, vukPower);									//Kick it out
		return 1;
	}

	if (Mode[player] == 7) {										//Are we in Ghost Photo Hunt?
		photoCheck(1);
		KickLeft(11000, vukPower);
		return 1;
	}
	
	if (theProgress[player] > 9 and theProgress[player] < 100) {	//Theater Ghost?
		if (theProgress[player] == 11) {	//Waiting for Shot 2, in which case this shot is CORRECT?
			TheaterPlay(1);					//Advance the play!
			return 0;						//No combo
		}
		else {			
			TheaterPlay(0);					//Incorrect shot, ghost will bitch!
			KickLeft(7000, vukPower);		//Kick it out quick
			return 1;
		}
	}

	comboVideoFlag = 0;												//Nothing active? Reset video combo flag	
	AddScore(5000);													//Some points
	KickLeft(7000, vukPower);										//The default	
	//Nothing going on default prompt
	video('C', 'G', 'E', allowSmall, 0, 250);					//Regular Combo to the Right ->	
	playSFX(2, 'A', 'Z', 'Z', 255);								//Whoosh!
	
	return 1;	//Can combo
	
}

void lightningFX(int lightStage) {

	lightningGo = 1;

//Creates a lightning effect using a number from 0-10000
//Send it a lobbed off modeTimer value to add lightning to speech calls

	if (lightStage < 27000) {

		switch (lightStage) {
			case 100:
				if (random(10) < 5) {
					cabLeft(0, 0, 0);				
				}
				else {	
					cabRight(0, 0, 0);	
				}				
				doRGB();			
			break;	
			case 3000:
				GIpf(B11000000);		
			break;	
			case 3500:
				lightningPWM = 0;
				cabLeft(0, 0, 0);
				cabRight(0, 0, 0);
				doRGB();		
			break;	
			case 4000:
				GIpf(B10000000);		
			break;	
			case 5000:
				GIpf(B00000000);		
			break;	
			case 18999:
        if (Mode[player] == 8) {        //If BUMPS mode, skip this dark stuff (dark enough already)
          lightningTimer = 25500;         
        }      
      break;
			case 19000:
				cabLeft(0, 0, 20);
				cabRight(0, 0, 0);
				doRGB();	
				GIpf(B11100000);
        GIbg(B10000000);
				light(40, 1);
				light(41, 1);
				light(42, 1);		
			break;	
			case 21000:
				cabLeft(0, 0, 20);
				cabRight(0, 0, 0);
				doRGB();
				GIpf(B01100000);
        GIbg(B01000000);
				light(40, 1);
				light(41, 1);
				light(42, 0);	
			break;	
			case 22000:
				cabLeft(0, 0, 0);
				cabRight(0, 0, 10);
				doRGB();	
				GIpf(B00100000);
        GIbg(B10000000);
				light(40, 1);
				light(41, 0);
				light(42, 0);	
			break;	
			case 24000:
				cabLeft(0, 0, 10);
				cabRight(0, 0, 0);
				doRGB();	
				GIpf(B00000000);
        GIbg(B00000000);
				light(40, 0);
				light(41, 0);
				light(42, 0);			
			break;	
			case 25000:
				cabLeft(0, 0, 0);
				cabRight(0, 0, 5);
				doRGB();	
			break;	
			case 25200:
				cabLeft(0, 0, 5);
				cabRight(0, 0, 0);
				doRGB();	
			break;	
			case 26000:
				lightningEnd(50);
			break;				
		}		

		if (lightStage > 6000 and lightStage < 18990) {					//Turn off both RGB's and flash the inserts all BRIGHT
			lightningPWM += 1;

			if (lightningPWM == 500) {	
				cabLeft(200, 200, 255);
				cabRight(0, 0, 0);
				doRGB();			
				GIpf(B10100000);
        GIbg(B01101010);
				light(40, 0);
				//light(41, 1);
				light(42, 0);
			}
						
			if (lightningPWM > 1000) {	
				lightningPWM = 0;
				cabLeft(0, 0, 0);
				cabRight(200, 200, 255);
				doRGB();			
				GIpf(B01000000);
        GIbg(B10010101);        
				light(40, 1);
				//light(41, 0);
				light(42, 1);							
			}
		   
		}

	}

	if (lightStage > 49999 and lightStage < 99999) {
		
		switch (lightStage) {
			case 50005:
				cabColor(0, 0, 0, 0, 0, 0);
				GIpf(B11100000);
        GIbg(B10100000);            //NEW BACKBOARD
				doRGB();						
			break;
			case 50500:
				cabColor(0, 0, 64, 0, 0, 64);
				GIpf(B00000000);
        GIbg(B00000001);            //NEW BACKBOARD
				doRGB();						
			break;			
			case 51000:
				cabColor(0, 0, 128, 0, 0, 128);
				GIpf(B11100000);
        GIbg(B10010000);            //NEW BACKBOARD
				doRGB();						
			break;	
			case 51500:
				cabColor(0, 0, 0, 0, 0, 0);
				GIpf(B00000000);
        GIbg(B00000010);            //NEW BACKBOARD
				doRGB();						
			break;	
			case 52000:
				cabColor(0, 0, 64, 0, 0, 64);
				GIpf(B11100000);
        GIbg(B10001000);            //NEW BACKBOARD
				doRGB();						
			break;	
			case 52500:
				cabColor(0, 0, 128, 0, 0, 128);
				GIpf(B00000000);
        GIbg(B00000100);            //NEW BACKBOARD
				doRGB();						
			break;	
			case 53000:
				cabColor(0, 0, 0, 0, 0, 0);
				GIpf(B11100000);
        GIbg(B10000000);            //NEW BACKBOARD
				doRGB();						
			break;	
			case 53500:
				cabColor(0, 0, 64, 0, 0, 64);
				GIpf(B00000000);
        GIbg(B00111111);            //NEW BACKBOARD
				doRGB();						
			break;	
			case 55000:
				cabColor(255, 255, 255, 255, 255, 255);
				setCabColor(0, 0, 0, 20);				
			break;	
			case 57000:
				lightningEnd(10);						
			break;							
		}		
	}
	
	if (lightStage > 99999 and lightStage < 120000) {

		lightningPWM += 1;

		if (lightningPWM == 300) {	
			cabLeft(255, 0, 0);
			cabRight(0, 0, 0);
			doRGB();			
			GIpf(B10100000);
		}
					
		if (lightningPWM > 600) {	
			lightningPWM = 0;
			cabLeft(0, 0, 0);
			cabRight(255, 0, 0);
			doRGB();			
			GIpf(B01000000);									
		}
		if (lightStage == 119999) {					//Fade to black complete? Fade back up to mode color
			lightningEnd(25);			
		}			
	}

  if (lightStage > 149999 and lightStage < 160000) {

    if (lightStage & 0x100) {
      GIword &= ~(1 << 7);    //Turn off near PF GI        
    }
    else {
      GIword |= (1 << 7);    //Turn on near PF GI      
    }

    if (lightStage == 152000) {     
      lightningTimer = 0;								//Finish cycle
      GIword |= (1 << 7);    //Turn on near PF GI 
      lightningGo = 0;								//Effect is done!            
    }

  }

  if (lightStage > 160000 and lightStage < 180000) {

    switch ((lightStage >> 8) & 0x07) {
 			case 0:
				GIbg(B01000100);
        GIpf(B11100000);
				cabLeft(0, 0, 255);
				cabRight(0, 0, 0);
				doRGB();	        
			break;     
			case 1:
				GIbg(B10001100);	
			break;	
			case 2:
				GIbg(B01001110);
        GIpf(B00000000);         
			break;    
			case 3:
				GIbg(B00000000);      
			break; 
			case 4:
				GIbg(B10011110);
        GIpf(B11100000);    
				cabLeft(0, 0, 0);
				cabRight(0, 0, 255);  
				doRGB();	        
			break;   
			case 5:
				GIbg(B01011111);        
			break;  
			case 6:
				GIbg(B10111111);
        GIpf(B00000000);
	        
			break;  
			case 7:
				GIbg(B00000000);		
			break;       
    }

    if (lightStage == 179999) {
      lightningEnd(50);
    }
  
  }
 
  if (lightStage > 179999 and lightStage < 199999) {
    
    if (lightStage == 180000) {                                            //First one always the same place
      GIbgSet(0, 1);
      GIbgSet(1, 0);
    }
    if (lightStage == 180000 + orbitDelta) {
      GIbgSet(0, 0);
      GIbgSet(1, 1);
      GIbgSet(2, 0);     
    }    
    if (lightStage == 180000 + (orbitDelta * 2)) {
      GIbgSet(1, 0);
      GIbgSet(2, 1);     
      GIbgSet(3, 0);
    } 
    if (lightStage == 180000 + (orbitDelta * 3)) {
      GIbgSet(2, 0);     
      GIbgSet(3, 1);
      GIbgSet(4, 0);  
    }
    if (lightStage == 180000 + (orbitDelta * 4)) {    
      GIbgSet(3, 0);
      GIbgSet(4, 1);
      GIbgSet(5, 0);   
    }
    if (lightStage == 180000 + (orbitDelta * 5)) {
      GIbgSet(4, 0);
      GIbgSet(5, 1);     
    }
    if (lightStage == 180000 + (orbitDelta * 6)) {
      GIbgSet(5, 0);     
    }    
    if (lightStage == 180000 + (orbitDelta * 7)) {                      //Make sure the slowest possible light can't run away this variable
      lightningEnd(50);
    }
    
  }

  if (lightStage > 199999 and lightStage < 220000) {      //Skill Shot Get!
  
    if (lightStage < 209000) {      
      if ((lightStage >> 8) & 1) {                        //Flash GI
        GIword = 0xFF00;  
      }
      else {
        GIword = 0x00FF;
      }     
    }

		switch (lightStage) {
			case 201000:
				cabLeft(0, 255, 255);
				cabRight(0, 0, 0);
				doRGB();				
			break;	
			case 202000:
				cabLeft(0, 0, 0);
				cabRight(0, 255, 255);
				doRGB();				
			break;	
			case 203000:
				cabLeft(255, 0, 255);
				cabRight(0, 0, 0);
				doRGB();				
			break;	
			case 204000:
				cabLeft(0, 0, 0);
				cabRight(255, 0, 255);
				doRGB();				
			break;	 
			case 205000:
				cabLeft(255, 255, 0);
				cabRight(0, 0, 0);
				doRGB();				
			break;	
			case 206000:
				cabLeft(0, 0, 0);
				cabRight(255, 255, 0);
				doRGB();				
			break;	
			case 207000:
				cabLeft(255, 255, 255);
				cabRight(0, 0, 0);
				doRGB();				
			break;	
			case 208000:
				cabLeft(0, 0, 0);
				cabRight(255, 255, 255);
				doRGB();				
			break;
			case 209000:
				cabLeft(200, 200, 200);
				cabRight(0, 0, 0);
				doRGB();				
			break;	 
			case 210000:
				cabLeft(0, 0, 0);
				cabRight(200, 200, 200);
				doRGB();				
			break;	
			case 211000:
				cabLeft(100, 100, 100);
				cabRight(0, 0, 0);
				doRGB();				
			break;	
			case 212000:
				cabLeft(0, 0, 0);
				cabRight(100, 100, 100);
				doRGB();				
			break;	
			case 213000:
				cabLeft(50, 50, 50);
				cabRight(0, 0, 0);
				doRGB();				
			break;
			case 214000:
				cabLeft(0, 0, 0);
				cabRight(50, 50, 50);
				doRGB();
			case 215000:
				cabLeft(0, 0, 0);
				cabRight(25, 25, 25);
				doRGB();
			case 216000:
				cabLeft(25, 25, 25);
				cabRight(0, 0, 0);
				doRGB();	 
			case 217000:
				cabLeft(0, 0, 0);
				cabRight(0, 0, 0);
				doRGB();	        
			case 219999:
				lightningEnd(50);
			break;				
		}		    
   
  }
  
  
  
}

void lightningEnd(unsigned char resumeSpeed) {

	lightningTimer = 0;								//Finish cycle
	lightningGo = 0;								//Effect is done!
	
	flashCab(0, 0, 0, resumeSpeed);					//Fade back into normal color from Black	
  GIpf(B11100000);                                //Default is to turn back on the GI 
  GIbg(B00000000);                      //Turn backboard lights off and re-paint them
  
  showScoopLights();                    //This will re-paint the Crystal Ball BG light, if needed
  
	if (ModeWon[player] & hospitalBit) {		//Hospital?
    GIbgSet(1, 1);
	}
	if (ModeWon[player] & theaterBit) {		//Theater?
    GIbgSet(5, 1);
	}
	if (ModeWon[player] & barBit) {		//Haunted bar?
    GIbgSet(2, 1);
	}
	if (ModeWon[player] & warBit) {		//War fort?
    GIbgSet(3, 1);
	}
	if (ModeWon[player] & hotelBit) {		//Hotel?
    GIbgSet(4, 1);
	}
	if (ModeWon[player] & prisonBit) {		//Prison?
    GIbgSet(0, 1);
	}	  
  
  //LIGHTNING FX AND CRYSTAL BALL HERE
  
  if (Mode[player] == 8 and bumpHits == 10) {     //If in BUMPS mode, and looking for a ghost, only nearest GI should be on    
    GIpf(B10000000);  
  }

}

void lightningStart(unsigned long theValue) {

	if (lightningTimer == 0) {          //Only start new lightning if a previous effect has finished (allows lighting to end "cleanly" and not leave things un-set)
		lightningTimer = theValue;
	}

}

void lightningKill() {

	lightningTimer = 0;								//Finish cycle
	lightningGo = 0;								//Effect is done!

	GIpf(B11100000);
	
}

void loadBall() {

	launchCounter = 0;

	if (bitRead(switches[7], 1) == 0) { 		//No ball in shooter lane?
		AutoPlunge(25005);
	}
	else {
		//Serial.print("BALL ALREADY LOADED: ");
		plungeTimer = 24000;					//Manually set plunge timer to skip ball loading part
	}

}

void logic() {									//This doesn't run if we're in a Ball Drain.

  if (Mode[player] == 8) {

    modeTimer -= 1;             //Always going down.
 
    if (modeTimer == 0) {     
      
      if (bumpHits == 10) {     //Are we looking for a ghost?
        
        if (modeTimer == 0) {
          modeTimer = 80000;
          playSFX(1, 'J', 'B', '1' + random(9), 255); 		  //Heather gives you shit for not finding anything 
        }
      
      }
      else {                                    //Else, we use this as the Score Decrement Timer

        setCabMode(0, 255, 0);                //Set back to GREEN in case it was changed during Time Freeze                   

        if (bumpValue > 500000) {
          bumpValue -= 12500;       
        }
        if (bumpValue > 9999999) {              //Position different if 7 or 8 digits
          numbers(10, 2, 12, 7, bumpValue);					         //Current value                  
        }
        else {
          numbers(10, 2, 14, 7, bumpValue);					         //Current value       
        }

        modeTimer = 2000;        
        
      }
 
    }
     
  }

	if (loopCatch == ballCaught) {				//Trying to catch a ball under ghost? Check these conditions:

		if (barProgress[player] == 60) {		//Ball caught by ghost?
			loopCatch = 0;						//Clear this
			BarTrap();							//Proceed
		}
	
		if (deProgress[player] == 2) {			//Second ball caught?
			loopCatch = 0;						//Clear this
			DemonLock2();						//Proceed
		}	
	
		if (minionMB == 20) {													//Minion Multiball, ready to catch ball?
			loopCatch = 0;
			minionMBtrap();	
		}
		
		if (deProgress[player] == 20) {											//Final shot to demon, and ball was caught?
			loopCatch = 0;
			DemonWin();															//You won the game!
		}

		if (videoMode[player] == 1) {	
			if (barProgress[player] != 60 and Advance_Enable == 1 and minion[player] != 10) {
				loopCatch = 0;
				runVideoMode();			
			}
		}	
	}

	if (minion[player] == 100 and modeTimer > 99999 and popsTimer == 0) {		//Minion MB, and a player has trapped a ball? (not the one trapped on mode start)
	
		modeTimer += 1;
		
		if (modeTimer > (100000 + longSecond)) {

			modeTimer = 100000;
			countSeconds -= 1;												//Subtract!
			numbers(0, numberStay | 4, 0, 0, countSeconds - 1);				//Update the Numbers Timer.	
				
			if (countSeconds > 1 and countSeconds < 7) {
				playSFX(2, 'A', 'M', 47 + countSeconds, 1);					//Hurry-Up countdown
			}
			else {
				playSFX(2, 'Y', 'Z', 'Z', 1);								//Beeps
			}

			if (countSeconds == 0) {										//Time's up! Kill timer number, release ball (no jackpot)
				minionMBjackpot(1);
			}
		
		}
	
	}

	if (hellMB and modeTimer < 80000) {						//Modetimer stays under 99999 in case Minion is stacked with Hell MB
	
		modeTimer += 1;
		
		if (modeTimer > 69999) {							//A large range, to ensure the lights get activated properly

			modeTimer = 80000;								//Should stop it from progressing
			lightSpeed = 1;
			flashCab(0, 0, 0, 25);
		
			if (Mode[player] == 0) {						//Not in a mode?
				showProgress(1, player);					//Show the progress, Active Mode style
			}

			minionLights();	
			popLogic(0);									//Figure out what the pops should be doing		
		
			//BLINK THE MINION LIGHTS
					
			tourReset(B00111010);							//Tour: Left orbit, door VUK, up middle, right orbit (excludes Hotel and Scoop)
			
			blink(24);										//Call button light status		
			light(25, 7);									//Current state is HIT TO GO UP	
			
			blink(41);										//Blink the hellavator flasher
			strobe(26, 5);									//Strobe all lights on that shot except Camera (since it's used for combos)
			blink(49);										//Blink the Multiball Progress light				
	
		}
		else {
			switch (modeTimer) {
				case 8840:
					cabColor(35, 0, 35, 35, 0, 35);
					setCabColor(0, 0, 0, 50);
					allLamp(2);
					break;
				case 10840:
					allLamp(0);
					GIpf(B01100000);
					break;
				case 23870:
					cabColor(70, 0, 70, 70, 0, 70);
					setCabColor(0, 0, 0, 50);
					allLamp(3);
					break;
				case 25870:
					allLamp(0);
					GIpf(B0100000);
					modeTimer = 28000;
					break;
				case 38700:
					cabColor(105, 0, 105, 105, 0, 105);
					setCabColor(0, 0, 0, 50);
					allLamp(4);
					break;
				case 40700:
					allLamp(0);
					GIpf(B00000000);
					modeTimer = 43000;
					break;
				case 46400:
					cabColor(140, 0, 140, 140, 0, 140);
					setCabColor(0, 0, 0, 50);
					allLamp(5);
					break;
				case 48400:
					allLamp(0);
					GIpf(B00000000);					
					break;				
				case 53780:
					cabColor(175, 0, 175, 175, 0, 175);
					setCabColor(0, 0, 0, 50);
					allLamp(7);
					break;
				case 55780:
					allLamp(0);
					GIpf(B00000000);					
					break;				
				case 57420:
					cabColor(210, 0, 210, 210, 0, 210);
					setCabColor(0, 0, 0, 50);
					allLamp(5);				
					break;			
				case 59420:
					cabColor(255, 0, 255, 255, 0, 255);
					doRGB();
					lightSpeed = 5;
					strobe(3, 5);				//Strobe EVERYTHING!
					strobe(8, 7);
					strobe(20, 4);
					strobe(26, 6);
					strobe(36, 4);
					strobe(43, 5);
					strobe(56, 8);				
					break;		
				case 60000:
					cabColor(0, 0, 0, 0, 0, 0);
					doRGB();
					GIpf(B10000000);					
					break;
				case 60500:
					cabColor(255, 0, 255, 0, 0, 0);
					doRGB();
					GIpf(B01000000);					
					break;
				case 61000:
					cabColor(0, 0, 0, 0, 0, 0);	
					doRGB();
					GIpf(B00100000);					
					break;		
				case 61500:
					cabColor(0, 0, 0, 255, 0, 255);
					doRGB();	
					GIpf(B10000000);					
					break;		
				case 62000:
					cabColor(0, 0, 0, 0, 0, 0);
					doRGB();
					GIpf(B01000000);					
					break;
				case 62500:
					cabColor(255, 0, 255, 255, 0, 255);
					doRGB();
					GIpf(B00100000);					
					lightSpeed = 10;
					break;
				case 63000:
					cabColor(0, 0, 0, 0, 0, 0);
					doRGB();	
					GIpf(B10000000);					
					break;
				case 64500:
					cabColor(255, 0, 255, 255, 0, 255);
					doRGB();
					GIpf(B01000000);					
					break;	
				case 65000:
					cabColor(0, 0, 0, 0, 0, 0);
					doRGB();	
					GIpf(B00100000);					
					break;
				case 65500:
					cabColor(255, 0, 255, 255, 0, 255);
					doRGB();
					GIpf(B10000000);					
					break;
				case 66000:
					cabColor(0, 0, 0, 0, 0, 0);
					doRGB();	
					GIpf(B11000000);					
					break;
				case 66500:
					cabColor(255, 0, 255, 255, 0, 255);
					doRGB();
					GIpf(B11100000);
					allLamp(0);				
					break;											
			}			
		}	
	}

	if (Mode[player] == 7 or Mode[player] == 99) {			//In GHOST PHOTO HUNT, or FINAL FLASH?
		photoLogic();	
	}

	if (multiBall & multiballLoading) {						//Multiball ready, loading balls onto play?
	
		multiTimer -= 1;		
		
		if (multiTimer == 1) {					//Just about done?
			AutoPlunge(autoPlungeFast);			//Auto launch a ball.
			//ballSave();							//Enable ball save
			multiTimer = autoPlungeFast + 1000; //Spit out another ball pretty quickly
	
			multiCount -= 1;			//Decrement count
			
			if (multiCount == 0) {		//Did we kick out all balls requested?
				multiBall &= ~multiballLoading;	//Clearing loading bit
				multiBall |= multiballLoaded;	//Change multiball condition to "All Balls Ejected"
				multiTimer = 0;					//Cancel timer
			}
		}
	}

	if (wiki[player] == 255 and tech[player] == 255 and psychic[player] == 255) {			//All 3 team members SPELLED?	
		pulse(0);				//Pulse lights again
		pulse(1);
		pulse(51);
		wiki[player] = 0;
		tech[player] = 0;
		psychic[player] = 0;
		
		if (videoModeEnable) {
			if (Advance_Enable and minion[player] < 10) {						//Modes can be advanced, and a Minion isn't active?
				videoQ('S', 'V', 'A', allowSmall, 0, 250);						//Video Mode Ready!
				videoMode[player] = 1;											//Ready to collect
				loopCatch = catchBall;											//Flag that we want to catch the ball in the loop	
				TargetTimerSet(10, TargetDown, 50);								//Put targets down
				blink(17);
				blink(18);
				blink(19);
			}
			else {
				videoQ('S', 'V', 'B', allowSmall, 0, 250);						//Video Mode Ready After Mode Ends
				videoMode[player] = 10;
			}		
		}
		else {
			AddScore(500000);													//If no VM, just give points
		}
		
	}
	
	if (Mode[player] == 1) {					//Hospital Mode active?
		HospitalLogic();
    logicBlink();		
	}

	if (Mode[player] == 2)	{					//Theater ghost active?
    logicBlink();	    
	}  
  
	if (Mode[player] == 3 or barProgress[player] == 60)	{					//Bar mode active?
		BarLogic();
    logicBlink();	    
	}

	if (Mode[player] == 4) {					//Fighting the War Fort ghost?
		WarLogic();
    logicBlink();	    
	}
	
	if (Mode[player] == 5) {					//Hotel Mode active?
		HotelLogic();
    logicBlink();			
	}
	
	if (Mode[player] == 6) {					//Prison Mode active?
		PrisonLogic();
    logicBlink();
	}
	
	if (ghostAction and ghostBored == 0) {		//Flag to have the ghost be doing something?
		
		doGhostActions();

	}

	if (ghostBored and ghostTimer == 0) {		//Ghost turns back to center, unless there's a Ghost Move Timer going on
		ghostBored -= 1;
		if (ghostBored == 10000) {					//Time up?
			ghostMove(GhostLocation + 10, 5);			//Ghost turns to the front.
		}
		if (ghostBored == 7000) {					//Time up?
			ghostMove(GhostLocation - 10, 5);			//Ghost turns to the front.
		}
		if (ghostBored == 3000) {					//Time up?
			ghostMove(GhostLocation + 10, 5);			//Ghost turns to the front.
		}
		if (ghostBored == 1) {						//Time up?
			ghostMove(90, 100);							//Ghost turns to the front.
			ghostBored = 0;
		}
	}

	if (minion[player] == 12) {					//Waiting for targets?
	
		if (TargetLocation == TargetUp) {		//Did targets make it back up?
			minion[player] = 1;					//NOW allow mode to start again
		}
	
	}

	if (goldHits == 10 and popsTimer == 0) {						//Are we stealing gold during the War Fort mode?
		WarGoldLogic();	
	}

	if (restartTimer) {

		if (hosProgress[player] == 3 and modeTimer and flipperAttract) {			//Giving the ball back? Make sure players know flipper works (if that option is enabled)
			
			modeTimer -= 1;
			
			if (modeTimer > 11000 and modeTimer < 11100) {
				digitalWrite(LFlipHigh, 1);		//Wiggle the flipper!
			}			
			if (modeTimer > 8000 and modeTimer < 8100) {
				digitalWrite(LFlipHigh, 1);		//Wiggle the flipper!
			}
			if (modeTimer > 4000 and modeTimer < 4100) {
				digitalWrite(LFlipHigh, 1);		//Wiggle the flipper!
			}		
		}
			
	}	
	
}

void logicBlink() {
  
    panelBlinker += 1;
    
    if (panelBlinker == 2000) {
      GIbgSet(modeToBit[Mode[player]], 1);       
    }
    if (panelBlinker > 4000) {
      panelBlinker = 0;
      GIbgSet(modeToBit[Mode[player]], 0);      
    }
  
}

void MachineReset() {

	Serial.println("System Reset");

	cabColor(32, 32, 32, 32, 32, 32);				//Dim lighting
	setGhostModeRGB(0, 0, 0);						//Set ghost to off
	ghostColor(0, 0, 0);
	
	allLamp(0);										//Turn off lamps

	myservo[Targets].write(TargetDown);				//Put targets down
	myservo[HellServo].write(hellDown); 			//Hellavator down
	myservo[DoorServo].write(DoorOpen); 			//Open Door
	myservo[GhostServo].write(90); 					//Center Ghost	
	
	for (int x = 0 ; x < 5 ; x++) {					//Send the high scores to display (in case they changed, or at start of game)
		sendHighScores(x);	
	}
					
	lightSpeed = 1;									//Speed at which the lights change
	
	switchDead = 0;

	Update(startingAttract);						//Set attract mode to ON (also sets Freeplay, number credits)
		
}

void MagnetSet(unsigned long setMagTimer) {

	Coil(Magnet, 255);					  //Magnet on for 100ms to catch ball	
	magFlag = magFlagTime;				//This is how many MS to pulse it 100 times a second. If it exceeds 10, magnet will be "solid on"
	MagnetTimer = setMagTimer + 30;		//Set total time (plus English offset?)
	MagnetCount = 0;					    //Reset PWM counter

}


//FUNCTIONS FOR MINION GHOST............................
void minionStart() {

	AddScore(startScore);
	
	setGhostModeRGB(128, 128, 128);								//Set ghost to white
	setCabModeFade(0, 0, 255, 200);								//Light the cabinet BLUE
	
	minion[player] = 10;									//Set flag that we've started

	playSFXQ(0, 'M', 'D' + random(2), '0' + random(10), 255);			//Now 20 total descriptions! Something Something Specter! MD0-MD9 and ME0-ME9
	
	if (minionHitProgress[player]) {						//Have we already attacked this class Minion?
		minionHits = minionHitProgress[player];				//Set how many hits we have left
	}
	else {													//If not, old school just get next value for that particular class minion (3 hits, 4 hits, etc)
		minionHits = minionTarget[player];					//Count DOWN instead of UP to make it easier to pick video
	}
	
	minionHitProgress[player] = 0;							//Clear the flag no matter what
	
	
	if (hellMB == 0) {
		playMusic('M', 'I');								//Minion music, unless a full Hellavator MB has started
		modeTotal = 0;										//This will be only mode active, so reset mode total
		
		//No HMB active, so OK to show custom Minion Score
		customScore('M', 'M', 'Y', allowAll | loopVideo);				//SHOOT GHOST!
		numbers(8, numberScore | 2, 0, 0, player);						//Put player score upper left
		numbers(9, 2, 122, 0, minionHits);								//Hits to Go upper right					
	}
	
	//playSFX(1, 'M', 'C', '0', 255);							//Ghost Minion Found Sound
	
	if (minionsBeat[player] > 8) {
		playSFX(0, 'M', 'C', '9', 255);									//You can keep beating them, but they only go up to Class 9
		video('M', 'F', '9', allowSmall, 0, 250);						//Ghost level cap at 9
	}
	else {
		playSFX(0, 'M', 'C', '1' + minionsBeat[player], 255);			//It's a class 1-9
		video('M', 'F', '1' + minionsBeat[player], allowSmall, 0, 250);	//Show which level ghost we're fighting
	}
		
	strobe(17, 3);											//Strobe the Ghost Targets

	if (minionHits <= minionDamage) {												//Almost defeat? Will next hit kill it?				
		if (minionsBeat[player] == minionMB1 or minionsBeat[player] == minionMB2) {	//Multiball Minion?
			if (hellMB) {
				videoQ('M', '9', '1', 2, 0, 100);									//Hit Ghost to STACK multiballs
			}
			else {
				videoQ('M', '9', '0', 2, 0, 100);									//Hit ghost for Multiball!	
			}
		}
		else {
			videoQ('M', '9', 64 + 1, 2, 0, 100);									//1 hit to go!
		}		
	}
	else {
		videoQ('M', '9', 64 + minionHits, 2, 0, 100);								//More than a single hit to beat minion? Show how many
	}
	
	if ((minionsBeat[player] == minionMB1 or minionsBeat[player] == minionMB2) and hellMB == 0) {	//Can this Minion Battle start a Minion MB, and Hell MB isn't active?
		hellEnable(0);										//Disable Hell Locks
	}
	else {
		hellEnable(1);										//Else, enable them
	}
	
	TargetTimerSet(10, TargetDown, 50);					//Put targets back up, but not so fast ball is caught	

	ghostAction = 425005;									//Ghost guarding	
	
	GLIRenable(0);											//Fighting a minion, you can't GLIR
	
}

void minionHitLogic() {

	minionHits -= minionDamage;
	lightningStart(50000);	
	
	killQ();	//Prevents incorrect hit # from appearing
	
	if (minionHits > 0) {									//Haven't won yet?
		ghostFlash(100);
		int mX = 'A' + random(10);							//Get a random ASCII letter A-J
		playSFX(1, 'N', '8', mX, 255);						//Sound to match animation
		video('M', '8', mX, allowSmall, 0, 255);			//Ghost hit animation
		animatePF(104, 15, 0);								//Minion hit, stuff flies off
		
		if (hellMB == 0) {
			numbers(9, 2, 122, 0, minionHits);					//Updated Hits to Go upper right					
		}		

		if (minionHits <= minionDamage) {						//Almost defeat? Will next hit kill it?				
			if (minionsBeat[player] == minionMB1 or minionsBeat[player] == minionMB2) {	//Multiball Minion?
				playSFX(0, 'M', 'D', 'F' + random(3), 255);		//Hit the ghost for Multiball! (has a gap so it plays after Whack Sound. Pre-dates playSFXQ command)
				if (hellMB) {
					videoQ('M', '9', '1', 2, 0, 100);			//Hit Ghost to STACK multiballs
				}
				else {
					videoQ('M', '9', '0', 2, 0, 100);			//Hit ghost for Multiball!	
				}
				/*
				minionMB = 1;									//Flag saying Multiball can start						
				if (minionsBeat[player] == minionMB2) {			//Also, starting the second Minion MB also lights EXTRA BALL
					extraBallLight(0);							//Light extra ball, no prompt we'll do there
					videoSFX('S', 'A', 'A', allowSmall, 0, 255, 0, 'A', 'X', 'A' + random(2), 255);	//"Extra Ball is Lit!"		
				}	
				*/
			}
			else {												//Normal minion
				videoQ('M', '9', 64 + minionHits, 2, 0, 100);	//How many hits to go
				playSFXQ(1, 'M', 'D', 'A' + random(5), 255);	//"Let's finish him off!" same channel as Whack Sound, will play after it's done
			}					
		}
		else {
			videoQ('M', '9', 64 + minionHits, 2, 0, 100);		//How many hits to go				
		}

		ghostAction = 468005;									//Minion hit, leading into guarding motion	
		AddScore(minionTarget[player] * 50000);				//Add score
		
		if (minionsBeat[player] > 3) {						//The more difficult minions? Magnet Fun!
			int x = minionsBeat[player] - 3;				//Reduce range	
			if (x > 9) {									//Limit it from 1 to 9
				x = 9;
			}
			Coil(Magnet, 50 + (x * 20));					//Magnet pulse! Stronger the more minions you fight
		}
	}
	else {
		ghostAction = 468005;								//Minion hit, leading into guarding motion	

		if (minionsBeat[player] == minionMB1 or minionsBeat[player] == minionMB2) {	//Multiball Minion?
			minionMB = 1;									//Flag saying Multiball can start						
			if (minionsBeat[player] == minionMB2) {			//Also, starting the second Minion MB also lights EXTRA BALL
				extraBallLight(2);							//Light extra ball, no prompt we'll do there	
			}		
		}				
		if (minionMB == 1) {								//Multiball flag set?
			minionMultiballStart();
		}
		else {
			minionWin();									//Normal Minion End
		}
	}

}

void minionLights() {		//Set Minion Lights to whatever they should be

	if (minion[player] == 0)	{		//Can't advance minions?
		return;							//Do nothing
	}

	if (minion[player] == 10) {		//Fighting a Ghost Minion?
		strobe(17, 3);				//Strobe his lights
		light(16, 0);				//Make sure JACKPOT is off
		return;	
	}
		
	pulse(17);						//Pulse all 3 by default (they're at least lit)
	pulse(18);
	pulse(19);
		
	if (minionsBeat[player] < 3) {		//First 3 minions, where you can just hit any targets 3 times?
	
		pulse(17);						//Pulse all 3 by default (they're at least lit)
		pulse(18);
		pulse(19);
		
		if (minionHits == 2) {			//Make lights solid to count how many we've hit
			light(19, 7);
		}
		if (minionHits == 1) {
			light(18, 7);
			light(19, 7);
		}		
	
	}
	else {								//Otherwise it's a level 4+, meaning targets have to be hit individually
	
		light(17, 7);					//Start with them on (lit) then pulse whichever ones we haven't hit it
		light(18, 7);
		light(19, 7);
	
		if (targetBits & B00000100) {
			pulse(17);
		}
		if (targetBits & B00000010) {
			pulse(18);
		}
		if (targetBits & B00000001) {
			pulse(19);
		}		
	}

}

void minionWin() {

	//ghostAction = 0;

	ghostModeRGB[0] = 0;
	ghostModeRGB[1] = 0;
	ghostModeRGB[2] = 0;
	ghostFlash(300);								//Flash minion, fade to black
	ghostMove(90, 100);
	
	blink(17);										//Blink targets during kill animation
	blink(18);										//They'll get changed to PULSE after ball release
	blink(19);
	
	light(16, 0);									//Turn off MAKE CONTACT
	MagnetSet(350);									//Catch ball
	minion[player] = 11;							//Set flag for mode ending, to put targets up AFTER magnet release

	ghostsDefeated[player] += 1;					//Keep track for bonuses
	minionsBeat[player] += 1;						//Keep track for Multiball
	
	if (hellMB) {
		setCabModeFade(255, 0, 255, 50);			//Turn color back to Magenta
	}
	
	if (minionsBeat[player] > 254) {				//Got a kill screen coming up!
		minionsBeat[player] = 254;
	}

	AddScore(minionsBeat[player] * 100000);
	
	killQ();															//Disable any Enqueued videos
	playSFX(0, 'M', 'E', 'A' + random(8), 255);							//Sound for light-sucking, different "Minion Defeated" quotes
	video('M', '9', 'X' + random(1), noExitFlush, 0, 255);				//Ghost sucked into light! (M9X or M9Y, left or right flip)
	numbersPriority(0, numberFlash | 1, 255, 11, modeTotal, 233);					//Flash the total points scored in mode	
	videoQ('M', '9', 'Z', noEntryFlush | B00000011, 0, 233);			//Minion Mode Total:
	
	minionHits = 3;									//3 hits to find another minion

	if (minionTarget[player] < 8) {					//At limit?
		minionTarget[player] += 1;						//Increase the hits it takes	
	}
	
	GLIRenable(1);									//Re-enable GLIR

	animatePF(44, 30, 0);							//Minion kill animation! (one shot)
			
	if (hellMB == 0) {
		killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
		killCustomScore();					
		modeTotal = 0;													//Reset mode points				
	}
	
}

void minionEnd(unsigned char endType) {

	ghostAction = 0;

	light(17, 0);							//Turn off lights as default
	light(18, 0);
	light(19, 0);

	if (minionMB) {
		light(7, 0);							//Turn off Jackpot Lights
		light(39, 0);
		minionMB = 0;
	}

	ghostAction = 0;
	lightningKill();
	
	if (multiBall) {
		cabModeRGB[0] = 255;						//Manually set Cabinet RGB mode
		cabModeRGB[1] = 0;
		cabModeRGB[2] = 255;
		flashCab(255, 255, 255, 50);				//Go back to Magenta color
	}
	else {
		setCabModeFade(defaultR, defaultG, defaultB, 200);				//Reset cabinet color	
	}
	
	targetReset();								//Reset target flags

	if (endType == 0 and minion[player] == 10) {			//We are disabling Minions because a different mode started, but we were battling one when mode started?
		minionHitProgress[player] = minionHits;				//Store the progress of how much we damaged him, so it's retrieved when next battle starts
	}
	
	//This gets reset because you'll still have to hit targets to bring back the minion (though his "power" will be lower)

	if (endType == 3) {
		if (minion[player] > 9 and minion[player] < 100) {	//Were we fighting a standard minion when the ball drained?
			minionHitProgress[player] = minionHits;			//Store the progress of how much we damaged him, so it's retrieved when next battle starts
		}
		else {
			minionHitProgress[player] = 0;					//Make sure this is clear
			minionHits = 3;
		}
	
		ghostModeRGB[0] = 0;					//Fade out the minion
		ghostModeRGB[1] = 0;
		ghostModeRGB[2] = 0;
		ghostFadeTimer = 100;
		ghostFadeAmount = 100;	
		TargetTimerSet(10000, TargetUp, 100);	//Put the targets back up
		minion[player] = 1;						//Set flag minion fight can be restarted once the player gets the ball back		
		pulse(17);								//Ghost targets strobe for MINION BATTLE!
		pulse(18);
		pulse(19);
		
		killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
		killCustomScore();
		
		return;	
	}

	minionHits = 3;								//First 3 minions, this counts hits. Minions 3+, used to play incrementing target sound		
	
	if (endType == 1) {							//Flag that mode ended with WIN + Reset targets?	
		minion[player] = 1;						//Set flag minion fight can be restarted once the targets are back up
		if (videoMode[player] == 10 and hellMB == 0) {	//If Hell MB not active, and Video Mode paused, re-enable it
			videoMode[player] = 1;
			loopCatch = catchBall;				//Flag that we want to catch the ball in the loop
		}
		else {
			TargetTimerSet(9000, TargetUp, 10);	//Put the targets back up		
		}
		pulse(17);								//Ghost targets strobe for MINION BATTLE!
		pulse(18);
		pulse(19);
		if (Mode[player] == 0) {				//No main modes active, and 
			if (multiBall == 0) {				//Hellavator Multiball not active?
				playMusic('M', '2');			//Revert to normal music		
			}	
		}	
		if (Mode[player] == 7) {
			playMusic('H', '2');							//Photo hunt music		
		}
		return;
	}
	if (endType == 2) {							//Flag that mode ended with WIN? + Do not reset targets yet..
		minion[player] = 1;						//Set flag minion fight can be restarted once the targets are back up
		pulse(17);								//Ghost targets strobe for MINION BATTLE!
		pulse(18);
		pulse(19);		
		if (Mode[player] == 0) {
			playMusic('M', '2');				//Normal music		
		}
		if (Mode[player] == 7) {
			playMusic('H', '2');				//Photo hunt music		
		}
		return;
	}

	minion[player] = 0;						//Set flag to disable Minion Battle

}

void minionMultiballStart() {

	AddScore(150000);

	comboKill();								//So combo lights don't appear after the mode
	
	if (hellMB == 0) {							//Hell MB isn't in progress?
		playMusic('M', 'M');					//Only need to switch to MB music if not stacked with Hell MB		
		storeLamp(player);						//Store the state of the Player's lamps. If HellMB active, this has already been done
		allLamp(0);								//Turn off the lamps so we can repaint them		
		modeTotal = 0;							//If Hell MB was active it already did this, so we don't want to erase that value unless Hell MB didn't start	
	}
		
	spiritGuideEnable(0);						//No spirit guide during Hospital
	
	dirtyPoolMode(0);							//We want to trap balls!

	//PAINT LAMPS HERE! (double check)
	
	strobe(3, 5);								//Strobe left orbit
	strobe(36, 4);								//Strobe right orbit

	pulse(16);									//Pulse JACKPOT
	light(17, 0);								//Turn off lights
	light(18, 0);
	light(19, 0);	
		
	blink(2);									//Blink MINION MASTER progress light
		
	ghostLook = 0;								//Ghost doesn't look around
	ghostAction = 110000;						//Ghost guarding ball

	minion[player] = 100;						//Set flag that we're in Minion Multiball Mode
	minionMB = 10;								//Flag that says a Ball is trapped under the ghost!
	Advance_Enable = 0;							//Disable mode advancement
			
	setCabModeFade(0, 0, 255, 50);				//Bright blue!

	minionJackpot = 100000;						//Starting Jackpot value
		
	if (hellMB == 0) {
		manualScore(5, minionJackpot);				//Store jackpot in Score #5
		customScore('M', 'M', 'W', allowAll | loopVideo);	//Ghost Lites, Orbits Build Jackpot
		numbers(8, numberScore | 2, 0, 0, player);	//Put player score upper left
		numbers(9, 9, 88, 0, 0);					//Ball # upper right
		numbers(10, numberScore | 2, 68, 27, 5);	//Use Score #5 to display the Minion Jackpot Value	
	}
	
	killQ();									//Disable any Enqueued videos	
	video('M', 'M', '1', allowSmall, 0, 255);	//Minion MB Start!
	playSFX(0, 'M', 'M', 'D', 255);				//Ghost Minion Multiball!
	
	MagnetSet(100);								//Hold the ball.
	TargetSet(TargetUp);						//Trap it using the targets
	trapTargets = 1;							//Ball should be trapped behind targets
	
	DoorSet(DoorOpen, 25);						//Make sure the door is open		
	
	//NEEDS IF STILL LOADING CONDITION!
	
	if (multiBall) {												//If a MB is active, it has to be Hellavator MB from Mode 0
		if (multiBall & multiballLoading) {							//It can be in 2 states - active (2 balls or more), or still loading its balls (unlikely BUT POSSIBLE)
			multiCount += 1;								//If it's still loading balls, then 3 will be active. We can only load 1 more.
			multiBall |= multiballMinion;							//Set Minion MB bit
		}	
		else {														//Much more likely that HellMB is already underway
			multiBall |= multiballMinion | multiballLoading;			//Set Minion MB bit, and Ball Loading bit since we need more balls
			multiTimer = 10;										//Next ball will be kicked out pretty quickly
			
			multiCount = countBalls();	 						//Stacked MB? Send all available balls!
			
			// multiCount = (4 - activeBalls);					//Figure out how many balls we can add. 2 balls active = add 2. 3 balls active = add 1			
			// if (multiCount != countBalls()) {				//If this number doesn't match # of balls in the trough...
				// multiCount = countBalls();	 				//then set the value to how many balls are actually in the trough
			// }		
		}
		tourClear();											//Turn off the Tour Ghost Catch lights		
		hellEnable(1);											//Enable this so Hell Jackpots can still be collected
	}
	else {
		multiBall = multiballMinion | multiballLoading;			//Set Minion MB bits, and Ball Loading bit
		multiTimer = 10;										//Next ball will be kicked out pretty quickly
		multiCount = 2;											//We'll add 2 balls
		if (countBalls() < multiCount) {						//If, somehow, there is less than 2 balls in trough...
			multiCount = countBalls();	 						//then set the value to how many balls are actually in the trough
		}	
		hellEnable(0);											//Can't stack the Hell MB on Minion MB (only the other way around)
	}

	ballSave();
	
	popLogic(0);												//Figure out what the pops should be doing
	showProgress(1, player);									//Show the Main Progress lights (not each mode's advancement)

	modeTimer = 99999;							//Prevents timer from starting until second ball trapped
	
}

void minionMBtrap() {

	ghostLook = 0;								//Ghost doesn't look around
	ghostAction = 110000;						//Ghost guarding ball
	
	setCabModeFade(0, 0, 128, 50);				//Medium Blue
	
	video('M', 'M', '7', 0, 0, 255);			//Ghost catches ball (don't show numbers yet...)	
	
	modeTimer = 100000;												//Setup timer
	countSeconds = 13;												//10 seconds to collect jackpot
	numbers(0, numberStay | 4, 0, 0, countSeconds - 1);				//Update the Numbers Timer.	
	
	videoQ('M', 'M', '8', allowSmall | noEntryFlush, 0, 255);	//Can you collect Jackpot in time? Arrows to numbers

	if (hellMB == 0) {
		customScore('M', 'M', 'X', allowAll | loopVideo);	//Ghost Lites, Orbits Build Jackpot
	}

	playSFX(0, 'M', 'M', 'A' + random(2), 255);	//Ghost catch & chuckle
	minionMB = 10;								//Flag that says a Ball is trapped under the ghost!
	MagnetSet(150);								//Hold the ball.
	TargetSet(TargetUp);						//Trap it using the targets
	trapTargets = 1;
	
	pulse(16);									//Pulse JACKPOT
	light(17, 0);								//Turn off lights
	light(18, 0);
	light(19, 0);	
	
	//videoQ('M', 'M', '2', allowSmall, 0, 255);	//Collect Jackpot Countdown! (arrows point at timers)
	
}

void minionMBjackpot(unsigned timeRelease) {

	killNumbers();								//Kill any numbers that are flashing
	killTimer(0);								//Kill the timer (either we got jackpot or it timed out doesn't matter)
	modeTimer = 99999;							//Prevents timer from showing until next target trapped	
	ghostLook = 1;								//Ghost CAN look around
	ghostAction = 0;							//Ghost guarding ball

	cabColor(0, 0, 0, 0, 0, 0);					//Set cab DARK...
	setCabModeFade(0, 0, 255, 50);				//..and flash it back to BRIGHT BLUE
	
	if (hellMB == 0) {
		customScore('M', 'M', 'W', allowAll | loopVideo);	//Ghost Lites, Orbits Build Jackpot
	}	
	
	if (timeRelease == 0) {
		video('M', 'M', '3', allowSmall, 0, 255);	//Minion Jackpot! The really fancy animation
		playSFX(0, 'M', 'M', 'I' + random(3), 255);	//Jackpot!	
		showValue(minionJackpot + (countSeconds * 50000), 40, 1);			//You get jackpot value + seconds remaining bonus		
	}
	else {										//Jackpot timed out - automatic ball release no points
		playSFX(2, 'M', 'Z', 'Z', 255);				//Sizzle sound with laugh
		video('M', 'M', '9', allowSmall, 0, 255);	//Minion Jackpot! The really fancy animation	
	}
	
	minionMB = 20;								//Flag that says a Ball has been freed!
	loopCatch = catchBall;						//Set flag that we want to catch the ball
	TargetSet(TargetDown);						//Drop targets quickly
	trapTargets = 0;
	
	light(16, 0);								//Turn OFF jackpot
	pulse(17);									//Strobe target lights
	pulse(18);
	pulse(19);	
	
}

void minionJackpotIncrease() {

	strobe(3, 5);									//Strobe left orbit
	strobe(36, 4);									//Strobe right orbit
	
	minionJackpot += 100000;						//Increase Jackpot
	manualScore(5, minionJackpot);				//Store jackpot in Score #5
 
  if (minionJackpot == 1000000 and (achieve[player] & jackpotBit) == 0) {    //First time we've done this? A special routine for showing the 1 million get
 
      achieve[player] |= jackpotBit;                      //Set the bit 
      playSFX(0, 'M', 'M', '5' + random(2), 255);		//Jackpot increase sound, Male or Female scream	
      video('R', '7', 'F', 0, 0, 255);             //All sub modes complete!
      demonMultiplier[player] += 1;							    //Add multiplier for demon mode          
      playSFX(1, 'D', 'Y', 'A' + random(6), 255);  //Add Multiplier! 
        
  }
  else {

    playSFX(0, 'M', 'M', '5' + random(2), 255);		//Jackpot increase sound, Male or Female scream	

    if (hellMB) {									                //If stacked, video that explicitly says "Minion Jackpot" As if anyone would be watching DMD
      numbers(7, numberFlash | 1, 255, 11, minionJackpot);	//Load Jackpot value Points as a number
      video('M', 'M', '6', noEntryFlush | B00000011, 0, 255);	//Show new Jackpot value
    }
    else {
      video('M', 'M', '5', allowSmall, 0, 255);	//New Jackpot Value display
      showValue(minionJackpot, 40, 0);			    //Show new value after video (but don't add it to score)		
    }    
 
    playSFXQ(0, 'M', 'M', 'F' + random(3), 255);	//Team leader random compliment

  }
  
}
//FUNCTIONS FOR MINION GHOST............................


void modeAction() {													//If MODETIMER set, check this logic
	
	if (deProgress[player] == 50) {									//Ending credits?

		switchDead = 0;												//Prevent ball search during credits
	
		modeTimer -= 1;
		
		if (modeTimer == 50000) {									//Fade out music
			fadeMusic(1, 0);	
		}	
		
		if (modeTimer == 10000) {									//Release ball
			TargetSet(TargetDown);	
			setGhostModeRGB(0, 0, 0);								//Turn off Ghost Color
		}	
		
		if (modeTimer == 0) {										//Restart player's game!
			stopMusic();
			musicVolume[0] = 35;									//Set back to normal
			musicVolume[1] = 35;
			volumeSFX(3, musicVolume[0], musicVolume[1]);	
			TargetTimerSet(1000, TargetUp, 1);						//Put targets back up right away!			
			restartPlayer(player);
			light(63, 7);											//DEMON BATTLE solid
		}
	
	}

	if (deProgress[player] == 9 or deProgress[player] == 10) {									//Waiting for ball to clear targets?
		modeTimer -= 1;
		if (modeTimer == 1) {		
			modeTimer = DoctorTimer;								//Default time before target moves again			
			TargetTimerSet(10, TargetUp, 1);						//Put targets back up right away!
			deProgress[player] = 10;								//MB officially started
		}				
	}

	if (deProgress[player] == 10) {									//Trying to WEAKEN the demon?
		modeTimer -= 1;
		if (modeTimer == 1) {		
			modeTimer = DoctorTimer;								//Default time before target moves again		
			playSFX(2, 'A', 'Z', 'Z', 255);							//MOVEMENT SOUND		
			DemonMove();
		}		
	}

	if (hosProgress[player] > 5 and hosProgress[player] < 9) {
	
		modeTimer -= 1;
		
		if (modeTimer == 1) {		
			DoorSet(DoorClosed, 5);									//Close door back up		
		}
	
	}

	if (theProgress[player] > 9 and theProgress[player] < 100 and popsTimer == 0) {									//Doing the THEATER GHOST PLAY?
	
		modeTimer -= 1;
		
		if (modeTimer == 1) {
			modeTimer = longSecond;										//Reset timer
			countSeconds -= 1;										//Reduce seconds left
			
			if (countSeconds == 0) {								//Out of time?
				TheaterFail(0);										//Time's up, Fail mode, allow animation and speech		
			}
			else {
				numbers(0, numberStay | 4, 0, 0, countSeconds - 1);				//Update the Numbers Timer
				shotValue -= 10000; 
				numbers(9, 2, 70, 27, shotValue);						//Shot Value
	
				if (countSeconds > 1 and countSeconds < 7) {	//Count down 5 4 3 2 1
					playSFX(2, 'A', 'M', 47 + countSeconds, 1);
				}
				else {
					playSFX(2, 'Y', 'Z', 'Z', 1);				//Beeps
				}				
			}
		}

	}

	
}

void MoveDoor() {

	DoorTimer += 1;
	
	if (DoorTimer < DoorSpeed) {									//Haven't hit the cycle count limit yet?
		return;														//Return from routine
	}

	DoorTimer = 0;													//Reset timer

	if (DoorLocation < DoorTarget) {
		DoorLocation += 1;
	}
	if (DoorLocation > DoorTarget) {
		DoorLocation -= 1;
	}
	if (DoorLocation == DoorTarget) {								//Target acquired?
		DoorSpeed = 0;												//Set flag

		//Code for hellavator Ball Search
		if (DoorTarget == DoorOpen) {
			if (doorCheck == 10) {									//Was sent down as part of a ball search?
				if (hosTrapCheck == 1) {							//If we're trying to find the ball, leave the door open
					doorCheck = 0;			
				}
				else {
					DoorSet(DoorClosed, 500);							//Set door back to closed
					doorCheck = 15;										//Set state 2				
				}
			}
			if (doorCheck == 25) {									//Was down, sent up, back down again?
				doorCheck = 0;										//Check complete	
			}
		}
		if (DoorTarget == DoorClosed) {
			if (doorCheck == 20) {									//Was sent UP as part of a ball search?
				DoorSet(DoorOpen, 1);								//Set door back to open
				doorCheck = 25;										//Set state 2
			}
			if (doorCheck == 15) {									//Was up, sent down, back up again?
				doorCheck = 0;										//Check complete	
			}		
		
		}	
	}	
	
    myservo[DoorServo].write(DoorLocation); 						//Set servo
	
}

void MoveElevator() {

	HellTimer += 1;
	
	if (HellTimer < HellSpeed) {									//Haven't hit the cycle count limit yet?
		return;														//Return from routine
	}

	HellTimer = 0;													//Reset timer

	if (HellLocation < HellTarget) {
		HellLocation += 1;
	}
	if (HellLocation > HellTarget) {
		HellLocation -= 1;
	}
	if (HellLocation == HellTarget) {								//Target acquired?
		HellSpeed = 0;												//Set flag that we're done here, UNLESS...
		
		//Code for hellavator Ball Search
		if (HellTarget == hellDown) {
      
      if (hellFlashFlag == 1) {         //Flag set to flash upon arrival?
        flashCab(0, 0, 0, 200);					//Flash! (he's a miracle!)	
        hellFlashFlag = 0;              //Clear flag
      }
            
			if (hellCheck == 10) {									//Was sent down as part of a ball search?
				ElevatorSet(hellUp, 200);							//Send it back up
				hellCheck = 15;										//Set state 2
			}
			if (hellCheck == 25) {									//Was down, sent up, back down again?
				hellCheck = 0;										//Check complete	
			}
		}
		if (HellTarget == hellUp) {
			if (hellCheck == 20) {									//Was sent UP as part of a ball search?
				ElevatorSet(hellDown, 200);							//Send it back down
				hellCheck = 25;										//Set state 2
			}
			if (hellCheck == 15) {									//Was up, sent down, back up again?
				hellCheck = 0;										//Check complete	
			}		
		
		}		
		
	}	
	
    myservo[HellServo].write(HellLocation); 						//Set servo
	
}

void MoveTarget() {

	TargetTimer += 1;
	
	if (TargetTimer < TargetSpeed) {									//Haven't hit the cycle count limit yet?
		return;														//Return from routine
	}

	TargetTimer = 0;												//Reset timer

	if (TargetLocation < TargetTarget) {
		TargetLocation += 1;
	}
	if (TargetLocation > TargetTarget) {
		TargetLocation -= 1;
	}
	if (TargetLocation == TargetTarget) {								//Target acquired?
		TargetSpeed = 0;												//Set flag that we're done here.
		if (TargetLocation == TargetUp and switchDead < deadTop) {		//Added a condition here so this doesn't abort the Ball Search
			dirtyPoolCheck();
		}
	}	
		
    myservo[Targets].write(TargetLocation); 						//Set servo
	

}

void multiBallStart(unsigned notRandomAward) {

	restartKill(0, 0);

	if (Mode[player] == 0) {						//Not in a mode?
		Advance_Enable = 0;							//Can't advance during multiball
		hellMB = 1;									//Set flag that Hellavator MB has started
		catchValue = 1;								//Cycle 1 of the Ghost Catch
		volumeSFX(3, 80, 80);						//Temp higher volume music	
		modeTimer = 2000;							//Let's do some wicked smart lighting!
		DoorSet(DoorOpen, 500);						//Open the door so we can shoot through it for Ghost Catch!	 (only if no Main Modes active)
		ghostSet(140);
		ghostMove(90, 400);

		if (videoMode[player] == 1) {				//Video Mode was ready to start?
			videoMode[player] = 10;					//Gonna have to wait
			loopCatch = 0;
			TargetTimerSet(1000, TargetUp, 50);		//Put targets back up manually
			minionEnd(2);							//Allow minions
		}		
		
		if (minion[player] < 10) {					//Minion or other mode isn't active?
			modeTotal = 0;							//No other modes active, so reset mode total. If Minion is stacked with MB, the totals combine
		}

		if (notRandomAward) {
			playMusic('M', 'P');					//Also, only change music if we're not in a mode		
		}
		
		comboKill();
		storeLamp(player);							//Store the state of the Player's lamps
		allLamp(0);									//Turn off the lamps so we can repaint them		

		//PAINT LAMPS HERE!!!!!!!!!!
		
		blink(49);									//Blink the MB light during mode
		
		modeTotal = 0;								//Since no mode is active, we can store a value for Hellavator mode
		cabModeRGB[0] = 255;						//Manually set Cabinet RGB mode
		cabModeRGB[1] = 0;
		cabModeRGB[2] = 255;
		cabColor(0, 0, 0, 0, 0, 0);					//Goto black quickly...
		doRGB();
		
	}
	else {
		hellMB = 0;
		blink(41);									//Blink the hellavator
		strobe(26, 5);								//Strobe all lights on that shot except Camera (since it's used for combos)
		blink(49);									//Blink the Multiball Progress light
		if (notRandomAward) {
			playSFX(1, 'Q', 'A', '6', 255); 			//Bells, beeps and ghost noises - non music version	
		}
	}
	
	multiBall = multiballLoading | multiballHell;	//Set Multiball loading flag (bit 0) and the flag that says Hell MB is active
	
	if (notRandomAward) {
		multiTimer = 60000;							//Set timer.
		playSFX(0, 'Q', 'A', '3', 255);				//MULTIBALL!!! (syncs with music FX)		
	}
	else {
		multiTimer = 8000;							//If Spirit Guide award, give next ball right away and don't say MULTIBALL!!!
	}
	
	multiCount = 2;									//We'll kick out 2 balls, for 3 total.

	if (countBalls() < multiCount) {				//If, somehow, there is less than 2 balls in trough...
		multiCount = countBalls();	 				//then set the value to how many balls are actually in the trough
	}
	
	hitsToLight[player] += 1;						//Increase # of call button presses you'll need next time, max 4
	
	if (hitsToLight[player] > 4) {					//Max out at 4 hits to light lock
		hitsToLight[player] = 4;
	}
	
	//hellEnable(0);								//Put elevator down, can't lock anymore
	if (hellMB) {
		videoQ('Q', 'A', '5', 0, 0, 200);			//Ramp builds, Hellavator Collects, Flashing shots catch ghosts	

		manualScore(6, hellJackpot[player]);		//Current Hell Jackpot Value
		
		customScore('Q', 'B', 'A', allowAll | loopVideo);				//Custom Score: Hit ghost for JACKPOTS!
		numbers(8, numberScore | 2, 0, 0, player);						//Put player score upper left
		numbers(9, 9, 88, 0, 0);										//Ball # upper right
		numbers(10, numberScore | 2, 84, 27, 6);							//Use Score #0 to display the Jackpot Value bottom off to right
				
	}
	else {
		videoQ('Q', 'A', '4', 0, 0, 200);			//Ramp builds, Hellavator Collects (What we show when MB is stacked with mode - no ghost catching)
	}

}

void multiBallJackpotIncrease() {

	AddScore(10710);											//Some points just for making the shot
	hellJackpot[player] += 250000;								//Add 250k to player's jackpot value	
	manualScore(6, hellJackpot[player]);						//Current Hell Jackpot Value
	killQ();
	//numbers(3, numberFlash | 1, 255, 11, hellJackpot[player]);	//Load Jackpot value Points as a number
	//video('Q', 'J', 'C', noEntryFlush | B00000011, 0, 255);		//Show new Jackpot value
	video('Q', 'J', 'C', allowAll, 0, 255);						//Show new Jackpot value
	numbers(7, numberFlash | 1, 255, 11, hellJackpot[player]);	//Load Jackpot value Points as a number
	playSFX(2, 'Q', 'J', 'C', 255);								//Whooshing sound
	flashCab(128, 0, 128, 50);
	strobe(26, 5);												//Strobe first 5 lights	

}

void multiBallEnd(unsigned char modeStacked) {

	loopCatch = 0;												//Don't watch to catch balls!

	killQ();
	killNumbers();
		
	multiBall &= B11110000;												//We just want the MSB's that store MB states (mask off the Loaded flags)

	int endState = 0;

//Multiball can end 5 ways:
//1 = Hell MB, nothing else active
//2 = Hell MB, during a mode (usually ends when mode does)
//3 = Minion MB
//4 = Hell MB stacked with Minion MB
//5 = Hell MB, with a Minion active

	if (multiBall == multiballHell) {									//It's either a plain HMB, or one stacked on another mode
		if (modeStacked or Mode[player]) {
			endState = 2;
		}
		else {
			if (minion[player] > 9 and minion[player] < 100) {
				endState = 5;
			}
			else {
				endState = 1;			
			}
		}
	}
	
	if (multiBall == multiballMinion) {									//It was a Minion MB?
		endState = 3;
	}
	
	if (multiBall == (multiballMinion | multiballHell)) {				//Minion MB stacked onto Hell MB?
		endState = 4;
	}

	//Serial.print("ENDSTATE: ");
	//Serial.println(endState);
	
	//A/V functions only here (since we suppress those if TILT)
	if (tiltFlag == 0) {													//If ended normally (not a tilt) restart lights and music as needed	
	
		if (endState == 1) {
			video('Q', 'Z', 'Z', allowAll, 0, 255);							//Multiball Mode Total:		
			numbers(1, numberFlash | 1, 255, 11, modeTotal);				//Show Hell MB Mode Total Points			
			playMusic('M', '2');											//Play the normal music	
			setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color (obviously don't want to do that if mode active)
			killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
			killCustomScore();				
		}
		if (endState == 4 or endState == 3) {
			AddScore(minionsBeat[player] * 250000);								//If stacked, we end it as Minion MB End		
			playSFX(0, 'M', 'I', 'W', 255);										//Shortened version of Ghost Into Light	
			video('M', '9', 'X' + random(1), noExitFlush, 0, 255);				//Ghost sucked into light! (M9X or M9Y, left or right flip)	
			numbers(1, numberFlash | 1, 255, 11, modeTotal);					//Flash the total points scored in mode
			videoQ('M', 'M', '4' , noEntryFlush | allowAll, 0, 255);			//Minion MB Total:
			ghostsDefeated[player] += 1;										//Keep track for bonuses
			minionsBeat[player] += 1;											//Keep track for Multiball		
			minionTarget[player] += 1;											//Increase the hits it takes
			if (minionTarget[player] > 9) {					//At limit?
				minionTarget[player] = 3;					//Reset it
			}			
			playMusic('M', '2');												//...But if in Minion MB, change music as that mode ends along with multiball
			setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color (obviously don't want to do that if mode active)
			killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
			killCustomScore();				
		}	
		if (endState == 5) {												//If normal, non-MB minion battle still active, resume Minion Music
			video('Q', 'Z', 'Z', allowLarge | allowSmall, 0, 255);			//Multiball Mode Total:		
			numbers(1, numberFlash | 1, 255, 11, modeTotal);				//Show Hell MB Mode Total Points			
			playMusic('M', 'I');											//Play the minion music
			setCabModeFade(0, 0, 255, 50);									//Light the cabinet BLUE quickly
			killScoreNumbers();												//Reset score numbers (so they don't bleed over into new display)
			customScore('M', 'M', 'Y', allowAll | loopVideo);				//Change to MINION custom score
			numbers(8, numberScore | 2, 0, 0, player);						//Put player score upper left
			numbers(9, 2, 122, 0, minionHits);								//Hits to Go upper right			
		}	
	}

	//OK now do the logic part of the modes ending

	if (Mode[player] == 0 and modeStacked == 0) {				//Not in a mode or just coming out of one?
		Advance_Enable = 1;										//Re-enable advance
		tourClear(); 											//Clear the Ghost Catch lights
		targetReset();											//Reset Ghost target flags		
		ghostAction = 0;										//Clear ghost movements (obviously don't want to do that if mode active)
		multipleBalls = 0;
		loadLamp(player);										//Not sure if we need this?		
		showProgress(0, player);								//Show all the Main Progress lights
		if (minion[player] < 10) {								//If Minion isn't active, go ahead and reset mode points
			modeTotal = 0;
		}			
	}
	
	if (multiBall & multiballHell) {							//Hell MB was active? Do stuff to end it.

    subWon[player] |= mbWon;         //OR in the bit that says you won this mode	

		lockCount[player] = 0;									//Reset these so we can start normal MB over again
		callHits = 0;
		hellMB = 0;												//It's over!
		light(49, 7);											//Regular Multiball complete!
		if (Advance_Enable == 0) {								//No modes active that might have Tour Shots?
		
			if (videoMode[player] and minion[player] != 10) {	//Video mode ready, and not fighting a minion?
				videoModeLite();
			}	
			for (int x = 0 ; x < 5 ; x++) {						//Kill the camera lights
				light(26 + x, 0);
			}		
		}
	}

	if (multiBall & multiballMinion) {							//Minion MB was active?

    subWon[player] |= minionWon;         //OR in the bit that says you won this mode
	
		minion[player] = 1;										//Since we must have been in Mode 0 on entry, re-enable Minion
		pulse(17);												//Ghost targets strobe for MINION BATTLE!
		pulse(18);
		pulse(19);		
		killTimer(0);											//Kill the Jackpot timer
		ghostModeRGB[0] = 0;
		ghostModeRGB[1] = 0;
		ghostModeRGB[2] = 0;
		ghostFlash(300);										//Flash minion, fade to black
		
		trapTargets = 0;										//No matter what, balls no longer trapped
		
		if (videoMode[player]) {									//Video mode ready? Leave targets down at end
			videoModeLite();
		}
		else {
			if (TargetLocation != TargetDown or minionMB == 10) {	//Targets up, or headed that way? A ball might be trapped behind them	
				TargetSet(TargetDown);								//Put them down...
				TargetTimerSet(10000, TargetUp, 10);				//and after a second, put the back up
			}	
			else {
				TargetTimerSet(1000, TargetUp, 10);					//Else, put them up immediately
			}		
		}
		
		light(7, 0);											//Turn off jackpot lights
		light(39, 0);
		light(16, 0);											//Turn off MAKE CONTACT		
		light(2, 7);											//Light MINION MASTER solid. No matter what you do, you've won the mode!
		minionMB = 0;											//Clear the mode
		spiritGuideEnable(1);									//Allow Spirit Guide again
		minionHits = 3;											//Set # of hits to 3 (for target sounds)

		if (barProgress[player] != 70 and deProgress[player] != 4 and minion[player] != 10) {							//Unless your friend trapped by a ghost, or Demon Advance...
			dirtyPoolMode(1);										//Don't want to trap balls anymore	
		}
		
	}
	else {	
		if (minion[player] != 10) {
			targetLogic(0);										//Not minion mode? See where the targets should be automatically (unless in a mode)
		}
	}
	
	//Stuff that happens no matter what
  
	multiBall = 0;
	multiTimer = 0;
	ElevatorSet(hellDown, 100); 								//Send Hellavator to 1st Floor.
	
	light(41, 0);												//Hellavator flasher off
	light(25, 7);												//Current state is SOLID
	blink(24);													//Other state BLINKS
	light(30, 0);												//Lock is NOT lit
	light(31, 0);												//Make sure camera isn't blinking either

	minionLights();								//See what they should be set at
	
	//checkModePost();							//We're going to do this manually
	
	doorLogic();								//Figure out what to do with the door
	checkRoll(0);								//See if we enabled GLIR Ghost Photo Hunt during that mode
	elevatorLogic();							//Did the mode move the elevator? Re-enable it and lock lights
	popLogic(0);								//Figure out what mode the Pops should be in

	GLIRenable(1);								//Re-enable GLIR (will also paint Scoop Lights for us)

 	if (Advance_Enable == 0) {									//If in a mode...
		hellEnable(0);											//DISABLE more MB - Can only start MB once per mode (if mode allows)
	}
	else {
		hellEnable(1);											//If not in a mode, eligible again
		demonQualify();		
	}	
  
  checkSubWizard();                    //See if there's enough to light Sub Wizard mode	
  
}

void nameEntry(unsigned char whichPlayer, unsigned char whichPlace) {

	cursorPos = 0;									//Position of cursor (0-2)
	inChar = 65;
	initials[0] = 64;								//What player has entered (starts as empty spaces)
	initials[1] = 64;
	initials[2] = 64;
	
	videoPriority(0);								//Set low priority so Match will override Name Entry when we exit here
	
	video('Z', whichPlayer + 48, cursorPos + 48, loopVideo, 0, 0); //Loop the Name Entry video screen
	sendInitials(whichPlayer, whichPlace);						//Go into Name Entry Mode
	
	modeTimer = 375000;									//need to get out of initials screen after this time
	
	while(cursorPos != 99) {

		houseKeeping();
		
		modeTimer --;									//Start countering down to bailing out of initials
		if(modeTimer == 0) {
			initials[0] = 66;							//If they don't enter name, it says BEN!
			initials[1] = 69;
			initials[2] = 78;			
			cursorPos = 99;								//Exit out of initials and move onto next player
		}
		
		if (cabSwitch(LFlip)) {							//Left button pressed?
			playSFX(1, 'O', 'R', '0', 255);
			modeTimer = 375000;
			inChar -= 1;
			if (inChar < 64) {
				inChar = 91;
			}
			sendInitials(whichPlayer, whichPlace);
		}
			
		if (cabSwitch(RFlip)) {							//Right button pressed?
			playSFX(1, 'O', 'R', '1', 255);
			modeTimer = 375000;
			inChar += 1;
			if (inChar > 91) {
				inChar = 64;
			}
			sendInitials(whichPlayer, whichPlace);
		}	
		
		if (cabSwitch(Start)) {							//Press START to enter a character	
			modeTimer = 375000;
			if (inChar == 91 and cursorPos > 0) {		//Backspace?
				initials[cursorPos] = 64;				//Set that initial back to an empty SPACE
				cursorPos -= 1;							//Send cursor back
				playSFX(1, 'O', 'R', '3', 255);			
			}
			if (inChar != 91) {							//Set a character, as long as it's not a backspace				
				initials[cursorPos] = inChar;			//Set the character
				cursorPos += 1;
				if (cursorPos == 3) {					//Done?
					playSFX(1, 'O', 'R', '2', 255);					
					cursorPos = 99;						//Set flag to exit			
				}
				else {
					playSFX(1, 'O', 'R', '2', 255);
				}
			}
			
			if (cursorPos != 3) {						//Don't bother changing this on last press				
				video('Z', whichPlayer + 48, cursorPos + 48, loopVideo, 0, 0);
				sendInitials(whichPlayer, whichPlace);
			}					
		}							
	}

	video('K', 'A', 'A', 0, 0, 255);				//Transistion flash
	sendInitials(0, 0);							//Exit name entry mode

  if (initials[0] == 'H' and initials[1] == 'M' and initials[2] == 'J') {         //Hilton's call out  
    //playSFX(1, 'X', 'N', 'C', 255); 
    endingQuote = 1;															  //No end quote
  }
  if (initials[0] == 'K' and initials[1] == 'E' and initials[2] == 'N') {         //Ken's call out
    //playSFX(1, 'X', 'N', 'A', 255); 
    endingQuote = 2;															  //No end quote       
  }
  if (initials[0] == 'B' and initials[1] == 'E' and initials[2] == 'N') {         //Ben's call out
    //playSFX(1, 'X', 'N', 'B', 255); 
    endingQuote = 3;															  //No end quote  
  }  
  if (initials[0] == 'B' and initials[1] == 'F' and initials[2] == 'K') {         //Bryan F'ing Kelly's call out
    //playSFX(1, 'X', 'N', 'D', 255); 
    endingQuote = 4;															  //No end quote 
  }  
  
	delay(1000);                                                                    //Normal amount of delay	
			
}


//FUNCTIONS FOR PHOTO HUNT MODE 7............................
void photoStart() {								//When you shoot scoop with Photo Hunt lit

  photoAdd[player] = 0;         //Reset this each time you start. Can only increase it DURING the mode

	videoModeCheck();

	lightSpeed = 2;								//Fast light speed
	
	restartKill(0, 0);
	
	AddScore(500000);
	
	comboKill();
	storeLamp(player);							//Store the state of the Player's lamps
	allLamp(0);									//Turn off the lamps
	
	spiritGuideEnable(0);						//No spirit guide during Photo Hunt

	//MINION LIGHTS???
	
	pulse(17);									//Pulse the Ghost Loop Lights
	pulse(18);
	pulse(19);

	modeTotal = 0;								//Reset mode points	
	
	if (!minionMB and minion[player] < 10) {	//Not in a Minion Mode?
		setGhostModeRGB(0, 0, 0);				//Set Ghost to black. But this way we can make him flash
	}
	
	TargetTimerSet(100, TargetDown, 200);		//Put targets down, ghost loop adds time
	
	setCabModeFade(200, 0, 0, 300);				//Kind of (not as dim as before) red "darkroom" lighting
					
	photosToGo = photosNeeded[player];			//See how many photos we need.

	playSFX(0, 'F', '2', 62 + photosToGo, 255);	//Mode start dialog, based off photos needed
	video('F', '2', 'A', 0, 0, 255);
	killQ();									//Disable any Enqueued videos
	GLIR[player] = 255;							//Set flag that we are IN photo hunt mode
	
	Mode[player] = 7;							//Ghost photo hunt mode!
	Advance_Enable = 0;							//Can't advancd until we win or lose (or drain)
	photoTimer = 70000;							//Set high so timer doesn't start for an extra second
	countSeconds = photoSecondsStart[player];	//Time left to hit shot
	numbers(0, numberStay | 4, 0, 0, countSeconds - 1);		//Update the Numbers Timer. We do "-1" so it'll display a zero.
	
	DoorSet(DoorOpen, 5);						//Open the Spooky Door, if it isn't already

	hellEnable(0);								//Can't lock balls
	
	showProgress(1, player);					//Show the Main Progress lights	(do this first so the BLINK PROGRESS will work)
	blink(50);									//Blink the PHOTO ACE progress light
	
	customScore('F', '2', 'Z', allowAll | loopVideo);		//Custom Score: Strobing Shots for Photos!
	numbers(8, numberScore | 2, 0, 0, player);				//Player's score
	photoValue = (countSeconds * 10000) + (100000 * (photosNeeded[player] - 2));
	numbers(9, 2, 70, 27, photoValue + photoAdd[player]);						//Photo Value + bonus
	numbers(10, 2, 122, 0, photosToGo);						//How many photos are left	
		
	playMusic('H', '2');						//Hurry-up music
	
	ScoopTime = 55000;							//Kick out the ball	

	for (int x = 0 ; x < 6 ; x++) {
		photoLocation[x] = 0;					//Clear Control Box locations	
		light(photoLights[x], 0);				//Turn off the 6 camera positions	
	}

	photoCurrent = random(5);					//Select a camera, but not the one on the scoop (since we just came from there)
	
	if (extraLit[player] and photoCurrent == 1) {	//If Extra Ball lit and first photo is same shot, make first photo left orbit
		photoCurrent = 0;
	}
	
	photoWhich = 0;										//Used for tourney path
	
	if (tournament) {
		photoCurrent = photoPath[photoWhich];			//Pre-determined first shot if in Tournament Mode
	}
	
	photoLocation[photoCurrent] = 255;					//Which one has the camera
	strobe(photoLights[photoCurrent] - photoStrobe[photoCurrent], photoStrobe[photoCurrent] + 1);						//Strobe as many under it as we can

  skip = 65;
  
}

void photoLogic() {								//What goes on during Photo Hunt Mode

	photoTimer -= 1;

	switch (photoTimer) {
	
		case 149999:
			allLamp(7);
      GIbg(B11111111);
		break;
		case 149500:
			allLamp(0);
		break;	
		case 149000:
			allLamp(7);
       GIbg(B00000000);
		break;		
		case 148500:
			allLamp(0);
		break;		
		case 148200:
			allLamp(7);
		break;	
		case 147900:
			allLamp(6);
		break;	
		case 147600:
			allLamp(5);
		break;			
		case 147300:
			allLamp(4);
		break;			
		case 147000:
			allLamp(3);
		break;			
		case 146700:
			allLamp(2);
		break;	
		case 146400:
			allLamp(0);
      showScoopLights();    
		break;			
		case 146000:
			if (photosToGo) {							//Not done yet?
				loadLamp(tempLamp);						//Restore previous lights from temp memory
				strobe(photoLights[photoCurrent] - photoStrobe[photoCurrent], photoStrobe[photoCurrent] + 1);						//Strobe as many under it as we can					
				photoTimer = longSecond * 2;			//A grace period of a few seconds before timer starts to decement again
			}
			else {
				photoWin();
			}
		break;			

    case 5:                               //Double it up!
				strobe(photoLights[photoCurrent] - photoStrobe[photoCurrent], photoStrobe[photoCurrent] + 1);	//Make sure STROBE is on!			    
    break;
    
		case 1:
			if (Mode[player] == 7) {					//Still in Photo hunt mode?
      
				strobe(photoLights[photoCurrent] - photoStrobe[photoCurrent], photoStrobe[photoCurrent] + 1);	//Make sure STROBE is on!
				
				photoTimer = longSecond;				//Reset timer
				countSeconds -= 1;						//Reduce seconds left
				
				photoValue -= 10000;					//Lose 10k points per second
				numbers(9, 2, 70, 27, photoValue + photoAdd[player]);		//Update Photo Value
							
				if (countSeconds == 0) {				//Out of time?
					photoFail(0);						//Fail blog!		
				}
				else {
					numbers(0, numberStay | 4, 0, 0, countSeconds - 1);	//Update the Numbers Timer

					if (countSeconds > 1 and countSeconds < 7) {	//Count down 5 4 3 2 1
						playSFX(2, 'A', 'M', 47 + countSeconds, 1);
					}
					else {
						playSFX(2, 'Y', 'Z', 'Z', 1);				//Beeps
					}				
				}
			}
		break;	

		
	}

}

void photoCheck(unsigned int whichSpot) {		//Checking if your shot has the Ghost Photo

	if (photoLocation[whichSpot] == 255) {				//A ghost photo found?
		photoLocation[whichSpot] = 0;					//Clear that location! (8-22-14 fix)
		flashCab(255, 255, 200, 20);					//Flash of white, then back to red mode color
		photoTimer = 150000;								//Reset this, a little higher to trigger LIGHT SHOW
		AddScore(photoAdd[player] + (countSeconds * 10000) + (100000 * (photosNeeded[player] - 2)));		//10 grand per second remaining + ()100k * # Times You've Started Photo Hunt)
		countSeconds = photoSecondsStart[player];		//Time left to hit shot
		
		photoValue = (countSeconds * 10000) + (100000 * (photosNeeded[player] - 2));	//Re-calculate next photo value	
		numbers(9, 2, 70, 27, photoValue + photoAdd[player]);												//Update display Photo Value
		
		numbers(0, numberStay | 4, 0, 0, countSeconds - 1);			//Update the Numbers Timer so we see the new number	right away 		
		photosTaken[player] += 1;						//Total number for bonus
		photosToGo -= 1;								//Reduce this
	
		numbers(10, 2, 122, 0, photosToGo);				//Update how many photos are left
	
		ghostFlash(50);									//Flash the ghost. In photo mode only, fades to black. If minion, goes back to medium white

		light(photoLights[whichSpot] - photoStrobe[whichSpot], 0);	//Turn off the Strobe
		
		if (photosToGo > 0) {									//Didn't win yet?
			playSFX(0, 'F', '3', 'A' + random(8), 255);			//Good, catch another!
			video('F', '3', 'A' + random(26), 0, 0, 255);		//Show ghost photo (A-Z 26 to choose from)
			videoQ('F', '9', 64 + photosToGo, allowSmall, 0, 255);		//Follow-up video saying how many we have to go

			photoCurrent = whichSpot;								//Set X to be the current shot, so we don't pick 2 in a row

			while (photoCurrent == whichSpot) {						//If random camera is same as last, loop continues
      
        //photoCurrent = random(2) + 3;							//Pick from any of the first 5 shots (not the scoop)
				photoCurrent = random(5);							//Pick from any of the first 5 shots (not the scoop)	
				if (extraLit[player] and photoCurrent == 1) {		//If Extra Ball is lit and we choose the door VUK, choose something else
					photoCurrent = whichSpot;
				}
			}

			photoWhich += 1;									//Used for tourney path
			
			if (tournament) {
				photoCurrent = photoPath[photoWhich];			//Pre-determined next shot if in Tournament Mode
			}
			
			photoLocation[photoCurrent] = 255;						//Which new location has the camera
			strobe(photoLights[photoCurrent] - photoStrobe[photoCurrent], photoStrobe[photoCurrent] + 1);	//Strobe the shot!	

			if (photoCurrent == 3) {									//Make SURE this one sticks!
				strobe(26, 6);			
			}
			
			if (photosToGo == 1) {
				lightSpeed = 3;									//If last shot, make the lights pulse even faster!
			}
			
												
		}
		else {															//Ending stuff. Mode TRULY ends after the flash finishes
						
			comboKill();
	
			//AWARD BONUS OF TOTAL PHOTOS * SOMETHING
			killTimer(0);												//Turn off numbers	

			AddScore(1000000 * photosNeeded[player]);					//1 million for each photo you got! Nice win bonus!
					
			killQ();
			playSFX(0, 'F', '4', 'A' + random(4), 255);					//Win dialog!
			video('F', '3', 'A' + random(9), noExitFlush, 0, 255);		//Show final photo
			numbersPriority(0, numberFlash | 1, 255, 11, modeTotal, 233);			//Load Mode Total Points
			videoQ('F', '9', 'Y', noEntryFlush | B00000011, 0, 233);	//Photo Hunt Mode Total:
			
		}
		
		storeLamp(tempLamp);								//Store the lights in temp slot 5 since we're about to do an animation
	}
	else {													//Not a photo shot?
		playSFX(0, 'F', '3', 'I' + random(8), 255);			//Taunt player
		video('F', '2', 'C', allowSmall, 0, 200);			//Empty frame + prompt	
		AddScore(5000);										//A few points
	}

}

void photoWin() {								//What happens when you collect X photos in time

	modeTotal = 0;									//Reset mode total

	loadLamp(player);								//Load the original lamp state back in

	light(50, 7);												//Light PHOTO ACE progress solid!

	if (photosNeeded[player] < 9) {								//Under the max?
		photosNeeded[player] += 1;								//Increase # of photos required
		photoSecondsStart[player] -= 1;							//Decrease 1 second off the timer per photo
	}

	photoEnd(1);												//Win condition, 1 = request new music
  
	if (photosNeeded[player] == 6) {							//Light EXTRA BALL on 3rd successful Photo Hunt

		extraBallLight(2);										//Light extra ball, no prompt we'll do there
		//videoSFX('S', 'A', 'A', allowSmall, 0, 255, 0, 'A', 'X', 'A' + random(2), 255);	//"Extra Ball is Lit!"			

	}
	
	if (photosNeeded[player] == 4) {							//First photo hunt success? Check if Demon Mode is ready
	
		demonQualify();
	
	}
  
  subWon[player] |= photoWon;         //OR in the bit that says you won this mode	  
  checkSubWizard();                   //See if there's enough to light Sub Wizard mode

}

void photoFail(unsigned char reasonFail) {								//What happens when you DON'T

	loadLamp(player);
	comboKill();

	if (photosNeeded[player] == 3) {				//Haven't won a Photo Hunt yet?
		light(50, 0);								//Make sure progress light is OFF
	}
	
	light(43, 0);
	killTimer(0);						//Turn off numbers	
	
	if (reasonFail == 0) {						//Fail via drain we pass a 1, and thus, don't do the video or speech

		killQ();								//Disable any Enqueued videos	
		playSFX(0, 'F', '5', 'A' + random(8), 10);	//Fail dialog
		video('F', '9', 'Z', noExitFlush, 0, 255);	//Show final photo
		numbersPriority(0, numberFlash | 1, 255, 11, modeTotal, 233);			//Load Mode Total Points
		videoQ('F', '9', 'X', noEntryFlush | B00000011, 0, 233);//Photo Hunt Mode Total:
				
		photoEnd(1);							//Send a 1 meaning START new music
	}
	else {
		photoEnd(0);							//We ARE in a drain. Send a 0 meaning DON'T start new music
	}

}

void photoEnd(unsigned char musicChange) {								//What happens after WIN or LOSE, regardless, to close out the mode. Other modes need this!

	lightSpeed = 1;									//Normal light speed

	GLIR[player] = GLIRneeded[player];				//How many times you'll have to spell GLIR to restart

	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();	
	
	setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color

	for (int x = 0 ; x < 6 ; x++) {
		photoLocation[x] = 0;					//Clear Control Box locations	
		light(photoLights[x], 0);				//Turn off the 6 camera positions	
	}

	rollOvers[player] = 0;						//Clear bits
	
	light(43, 0);								//Turn off GLIR MODE LIGHT

	if (!minionMB and minion[player] < 10) {	//Not in a Minion Mode?
		light(16, 0);							//Turn off the Make Contact light that may have been left on the cached Light Data	
	}
	
	if (musicChange) {
		if (minionMB == 0 and minion[player] < 10) {		//Not in Minion Multiball, or fighting a Minion?
			playMusic('M', '2');							//Normal music
		}
		if (minionMB > 9) {									//Minion MB?
			playMusic('M', 'I');							//Placeholder for Minion MB theme
		}
		if (minionMB < 10 and minion[player] > 9) {			//Just fighting a minion?
			playMusic('M', 'I');					
		}		
	}

	photoTimer = 0;							//Kill this timer
	Mode[player] = 0;						//Set mode to ZERO
	Advance_Enable = 1;						//Can advance	
	modeTotal = 0;								//Reset mode points	
			
	checkModePost();	
	hellEnable(1);
	spiritGuideEnable(1);						//Re-enable spirit guide
	
	showProgress(0, player);					//Show the Main Progress lights
	
	photosToGo = 0;								//This is often used to check if mode active, so set it to ZERO
	
}
//FUNCTIONS FOR PHOTO HUNT MODE 7............................


void popCheck() {

	if (skillShot) {			
		if (skillShot == 1) {						//Did we hit the Skill shot?
			skillShotSuccess(1, 0);					//Success!
		}
		else {
			skillShotSuccess(0, 0);					//Failure, so just disable it
		}
		//return;									//The pop hit for skill shot can also advance other stuff 8-22-14 fix
	}
  else {    
    suppressBurst = 1;	  
  }

	//Wasn't a skill shot, so continue as per normal

  
	if (Advance_Enable == 0) {						//In a mode of some sort?
		evpPops();									//Do EVP pops
	}
	else {
		if (popMode[player] == 1) {					//Advancing Fort?		
			if (fortProgress[player] < 50) {			
				WarAdvance(1);
			}											
		}	
		if (popMode[player] == 2) {					//Advancing Bar?
			if (barProgress[player] < 50) {			
				BarAdvance(1);
			}		
		}				
		if (popMode[player] == 3) {					//Done advancing Bar and Fort?
			evpPops();								//Do EVP pops		
		}
	}
	
}

void popLogic(unsigned char popType) {

	if (popType == 0) {													//Need to Figure out what Pop Mode we should be in?
		if (barProgress[player] == 50 or fortProgress[player] == 50) {	//Eligible to start Bar mode or War Fort mode?
			popType = 3;												//Then pops should do EVPs
			light(20, 0);												//Do the lights, and return so nothing else can trigger
			light(21, 0);
			light(22, 0);
			pulse(20);
			return;
		}
	
		if (fortProgress[player] > 99) {	//Has War Fort already been won?
				popType = 2;				//Then Advance Bar	
		}
		if (barProgress[player] > 79) {	//Has Bar Ghost already been won?
				popType = 1;				//Then Advance Fort	
		}
		
		if (fortProgress[player] > 99 and barProgress[player] > 79) {	//Both have been won?
			popType = 3;					//EVP's from now on
		}

		if (fortProgress[player] < 100 and barProgress[player] < 80) {	//Neither have been won?						
			if (barProgress[player] > fortProgress[player]) {
				popType = 2;				//If Bar is progressed further, light it
			}
			else {
				popType = 1;				//Else they're both 0, or Fort is further
			}		
		}
		if (Advance_Enable == 0) {			//If in a mode of some kind, always Jackpot Advance / EVP
			popType = 3;
		}
			
	}

	if (popType == 1) {						//Advancing Fort?
		light(20, 0);
		light(21, 0);
		light(22, 0);
		pulse(21);
	}
					
	if (popType == 2) {						//Advancing Bar?
		light(20, 0);
		light(21, 0);
		light(22, 0);
		pulse(22);		
	}

	if (popType == 3) {						//EVP pops?			
		light(20, 0);
		light(21, 0);
		light(22, 0);
		pulse(20);
	}
	
	popMode[player] = popType;	
				
}

void popToggle() {

	if (leftVolume > rightVolume) {
		leftVolume = 5;
		rightVolume = sfxDefault;
	}
	else {
		leftVolume = sfxDefault;
		rightVolume = 5;
	}

}


//FUNCTIONS FOR PRISON MODE 6............................
void PrisonAdvance() {							//The first 3 advances

	AddScore(advanceScore);
	flashCab(0, 255, 0, 100);					//Flash the GHOST BOSS color
	
	priProgress[player] += 1;
	areaProgress[player] += 1;
	
	if (priProgress[player] < 3) {										//First 2 advances?
		light(2 + priProgress[player], 7);								//Current number solid.
		pulse(3 + priProgress[player]);									//Pulse the next
		playSFX(0, 'P', priProgress[player]+ 48, random(4) + 65, 255);	//Play 1 of 4 audio clips
		video('P', priProgress[player] + 48, 'A', allowSmall, 0, 254);	//Run video
	}

	if (priProgress[player] == 3) {										//Third advance?
		light(3, 7);													//Make sure the first 3 are solid...
		light(4, 7);
		light(5, 7);
		blink(6);														//Blink "Prison Lock"
		playSFX(0, 'P', '3', random(3) + 65, 255);						//Play 1 of 3 audio clips	
		video('P', '3', 'A', allowSmall, 0, 254);						//Run video	
	}	

	if (priProgress[player] == 4) {										//Fourth orbit shot to start mode?
		priProgress[player] = 6;										//Set flag so that when it hits basement Prison Mode will start (left orbit won't do anything now)
	}
	
	//priProgress[player] == 4 is the 4th shot up the orbit. This then goes to ORBS or Basement to Lock the first ball
	//We do this to prevent the 3rd orbit shot from also locking the first ball
	
}

void PrisonAdvance2() {							//Locking the balls

	killQ();									//Combos fuck this up sometimes, so just in case...

	AddScore(advanceScore);
	//flashCab(0, 255, 0, 200);					//Flash the GHOST BOSS color
	
	priProgress[player] += 1;											//Advance progress. First time here this will be 6. Will get incremented to 7 to start mode 8-22-14 fix

	if (priProgress[player] < 7) {										//First 2 balls?		8-22-14 update, this will never occur now	
		light(priProgress[player] - 2, 7);								//Make light solid.
		video('P', 44 + priProgress[player], 'B', allowSmall, 0, 255);	//Video of Ball Locked
		playSFX(0, 'P', '4', 60 + priProgress[player], 255);			//Ah, I'm trapped! Next person get down there!	
	}

	if (priProgress[player] == 7) {										//Locked 3rd Ball? (actually just the 4th shot)
		PrisonStart();	
	}

}

void PrisonStart() {							//Prison Ghost Battle

	videoModeCheck();

	modeTotal = 0;								//Reset mode points	
	AddScore(startScore);
	
	comboKill();
	storeLamp(player);							//Store the state of the Player's lamps	
	allLamp(0);									//Turn off the lamps

	spiritGuideEnable(1);

	popLogic(3);								//Set pops to EVP
	minionEnd(0);								//Disable Minion mode, even if it's in progress

	setGhostModeRGB(255, 131, 0);				//Orange ghost!
	setCabModeFade(0, 255, 0, 200);				//Turn lighting GREEN (with envy)

	Advance_Enable = 0;							//Mode started, disable advancement until we are done

	Mode[player] = 6;							//Set theater mode ACTIVE for player
	teamSaved = 0;								//Reset how many members saved

	jackpotMultiplier = 1;						//Reset this just in case
	
	blink(62);									//Blink the PRISON mode light.
	tourReset(B00101110);						//Tour: Left orbit, center shot, hotel path, right orbit
	
	playMusic('B', '1');						//Boss battle music!
	int x = random(3);							//Video clip must match audio
	video('P', '4', 'D' + x, allowSmall, 0, 255);	
	playSFX(0, 'P', '4', 'D' + x, 255);			//Mode start dialog
	killQ();									//Disable any Enqueued videos
	//videoQ('P', '5', 'G', loopVideo | allowSmall, 0, 200);			//The ghost behind all 3 targets!
	
	hellEnable(0);								//Disable the Hellavator Call & Lock

	customScore('P', '5', 'G', allowAll | loopVideo);		//Shoot score with targets in front
	numbers(8, numberScore | 2, 0, 0, player);	//Show player's score in upper left corner
	numbers(9, 9, 88, 0, 0);					//Ball # upper right
	numbers(10, 2, 2, 27, 3);					//Show balls left to add
	numbers(11, 2, 116, 27, 1);					//Jackpot multiplier	
	
	convictState = 1;							//State of Prison Ghost (Need to open door)
	convictsSaved = 0;							//Reset How many you've saved
	//DoorSet(DoorClosed, 5);						//Close the door for this state
	pulse(14);									//Pulse the door shot

	if (countGhosts() == 5) {						//Is this the last Boss Ghost to beat?
		blink(48);									//Blink that progress light
	}	
	
	TargetTimerSet(10000, TargetUp, 100);		//Put the targets back up
	pulse(17);									//Ghost targets strobe for MINION BATTLE!
	pulse(18);
	pulse(19);	
	targetReset();	

	priProgress[player] = 9;					//Set flag to delay scoop when the ball gets there

	hellEnable(0);								//Can't do multiball since this is a 4 ball mode anyway	
	showProgress(1, player);					//Show the Main Progress lights
	
	doorLogic();
	
}

void PrisonLogic() {

	if (priProgress[player] > 9 and priProgress[player] < 20) {							//Trying to free your friends?
		modeTimer += 1;
		if (modeTimer > 100000) {														//Prisoner prompt?					
			if (convictState == 1) {								//Haven't opened the door yet?
				playSFX(1, 'P', 'X', 'A' + random(4), 255);			//Prompt to do that
				video('P', '8', 'X', B00000011, 0, 254);			
			}
			else {
				//NEW VIDEO HERE:
				video('P', '8', 'V', allowSmall, 0, 255);			//Door is open Prompt to SHOOT VUK
				playSFX(1, 'P', 'V', 'A' + random(4), 255);	
			}	
			modeTimer = 0;
		}
	}
	
	if (priProgress[player] == 20) {													//Prison multiball?
		modeTimer += 1;
		if (modeTimer == 65000) {														//Prisoner prompt?					
			if (convictState == 1) {								//Haven't opened the door yet?
				playSFX(1, 'P', 'X', 'A' + random(4), 255);			//Prompt to do that
				video('P', '8', 'X', B00000011, 0, 254);			
			}
			else {
				video('P', '8', 'V', allowSmall, 0, 255);			//Door is open Prompt to SHOOT VUK
				playSFX(1, 'P', 'V', 'A' + random(4), 255);	
			}	
		}
		if (modeTimer == 130000) {							//Team member prompt?
			playSFX(0, 'P', 'A' + random(4), '0' + random(10), 255);		
			modeTimer = 0;
		}		
	}

}

void PrisonDrainCheck(unsigned char whenDrain) {		
	
	if (whenDrain) {											//1 = Drain after all balls free
		if (activeBalls == 3) {									//Did we lose first member?
			playSFX(0, 'P', '9', 'A' + random(3), 255);			//Heather calls it quits
			video('P', '9', 'X', allowSmall, 0, 255);			//She leaves
			videoQ('P', '7', 'F', allowSmall, 0, 255);			//Prompt how many balls are left
		}
		if (activeBalls == 2) {									//Did we lose second member?
			playSFX(0, 'P', '9', 'D' + random(3), 255);			//Misty calls it quits
			video('P', '9', 'Y', allowSmall, 0, 255);			//She leaves
			videoQ('P', '7', 'E', allowSmall, 0, 255);			//Prompt how many balls are left
		}		
		if (activeBalls == 1) {									//Did we lose third member?
			PrisonWin();
		}
		else {
			jackpotMultiplier = activeBalls;					//Update jackpot multipler
			sendJackpot(0);										//Send jackpot value to score #0
		}
		
		
	}
	else {												//0 = Drain before all balls free
		if (priProgress[player] == 11) {				//Did we lose first member?
			playSFX(0, 'P', '9', 'A' + random(3), 255);	//Heather calls it quits
			video('P', '9', 'X', allowSmall, 0, 255);			//She leaves
		}
		if (priProgress[player] == 12) {				//Did we lose second member?
			playSFX(0, 'P', '9', 'D' + random(3), 255);	//Misty calls it quits
			video('P', '9', 'Y', allowSmall, 0, 255);			//She leaves
		}

		numbers(11, 2, 116, 27, activeBalls);	//Update Jackpot multiplier - 1		
				
	}
		
}

void PrisonRelease() {

	priProgress[player] += 1;	
	modeTimer = 0;

	if (priProgress[player] == 11) {				//First player freed?	
		AddScore(startScore * 1);
		if (ScoopTime and spiritGuide[player]) {	//If both are YES, the ball is in the scoop doing a Spirit Guide, so ENQUEUE release video
			videoSFX('P', '7', 'A', 2, 0, 200, 0, 'P', '5', 'X' + random(3), 200);
		}
		else {										//Normal
			playSFX(0, 'P', '5', 'X' + random(3), 255);	//Heather is free!			
			video('P', '7', 'A', allowSmall, 0, 255);
			videoQ('P', '7', 'C' + activeBalls + 1, allowSmall, 0, 200);					
		}
		
		teamSaved += 1;
		
		if (countBalls() > 0) {						//A ball can be launched?
			AutoPlunge(autoPlungeFast);				//Autolaunch ball!
		}
		
		pulse(17);									//Ghost targets strobe for MINION BATTLE!
		pulse(18);
		pulse(19);	
		targetReset();
		
		customScore('P', '5', 64 + (targetBits & B00000111), allowAll | loopVideo);		//Shoot score with targets in front
		numbers(10, 2, 2, 27, 2);					//Show balls left to add
		numbers(11, 2, 116, 27, activeBalls + 1);	//Jackpot multiplier (add one since the ball won't be loaded yet)		
	}

	if (priProgress[player] == 12) {				//Second player freed?
		AddScore(startScore * 2);
		if (ScoopTime and spiritGuide[player]) {	//If both are YES, the ball is in the scoop doing a Spirit Guide, so ENQUEUE release video
			videoSFX('P', '7', 'B', 2, 0, 200, 0, 'P', '6', 'X' + random(3), 200);
		}
		else {										//Normal
			playSFX(0, 'P', '6', 'X' + random(3), 255);	//Misty is free!
			video('P', '7', 'B', allowSmall, 0, 255);
			videoQ('P', '7', 'C' + activeBalls + 1, allowSmall, 0, 255);							
		}
				
		teamSaved += 1;
		
		if (countBalls() > 0) {						//A ball can be launched?
			AutoPlunge(autoPlungeFast);				//Autolaunch ball!
		}
		
		pulse(17);									//Ghost targets strobe for MINION BATTLE!
		pulse(18);
		pulse(19);	
		targetReset();
		customScore('P', '5', 64 + (targetBits & B00000111), allowAll | loopVideo);		//Shoot score with targets in front
		numbers(10, 2, 2, 27, 1);					//Show balls left to add
		numbers(11, 2, 116, 27, activeBalls + 1);		//Jackpot multiplier (add one since the ball won't be loaded yet)	
		
	}	

	if (priProgress[player] == 13) {				//Third player freed? Start JACKPOT MODE!
		AddScore(startScore * 3);
		if (ScoopTime and spiritGuide[player]) {	//If both are YES, the ball is in the scoop doing a Spirit Guide, so ENQUEUE release video
			videoSFX('P', '7', 'C', 2, 0, 200, 0, 'P', '7', 'X' + random(3), 200);
		}
		else {										//Normal
			playSFX(0, 'P', '7', 'X' + random(3), 255);	//Kaminski is free!
			video('P', '7', 'C', allowSmall, 0, 255);
			videoQ('P', '7', 'C' + activeBalls + 1, allowSmall, 0, 255);
		}	
		teamSaved += 1;
		priProgress[player] = 20;					//Flag that we're now bashing the hell out of the ghost.
		
		if (countBalls() > 0) {						//A ball can be launched?
			AutoPlunge(autoPlungeFast);				//Autolaunch ball!
		}
		
		TargetTimerSet(100, TargetDown, 1);		//Put the targets down quickly so we can get JACPOTS		
		light(62, 7);								//Light mode SOLID = Win
		winMusicPlay();						//Amazing Ghost Squad theme!
		
		//All balls released, so now we ease up a bit and allow a Ball Save time
		multipleBalls = 1;							//When MB starts, you get ballSave amount of time to loose balls and get them back
		ballSave();									//That is, Ball Save only times out, it isn't disabled via the first ball lost		

		killScoreNumbers();							//Disable any custom score numbers so we can rebuild them

		jackpotMultiplier = activeBalls + 1;			//Update jackpot value
		sendJackpot(0);								//Send jackpot value to score #0
				
		customScore('B', '1', 'D', allowAll | loopVideo);				//Custom Score: Hit ghost for JACKPOTS!
		numbers(8, numberScore | 2, 0, 0, player);						//Put player score upper left
		numbers(9, numberScore | 2, 72, 27, 0);							//Use Score #0 to display the Jackpot Value bottom off to right
		numbers(10, 9, 88, 0, 0);										//Ball # upper right
		
		ModeWon[player] |= 1 << 6;				//Set PRISON WON bit for this player.	
		
		if (countGhosts() == 6) {										//This the final Ghost Boss? Light BOSSES solid!
			light(48, 7);
		}
		
	}	
	
}

void PrisonJackpot() {

	MagnetSet(50);											//Catch ball briefly	
	video('P', '9', 'A' + random(2), allowSmall, 0, 255);			//One of two Jackpot Bash videos (left or right)
	playSFX(0, 'P', '8', 'A' + random(8), 255);				//Jackpot Sound!
	ghostFlash(50);
	ghostAction = 20000;											//Whack routine	
	showValue(EVP_Jackpot[player] * activeBalls, 40, 1);

}

void PrisonWin() {

	multipleBalls = 0;
	tourClear();								//Clear the tour lights / values
	
	AddScore(winScore);

	loadLamp(player);
	comboKill();

	convictState = 0;
	
	light(3, 0);							//Turn off mode counter lights
	light(4, 0);
	light(5, 0);
	light(6, 0);
	
	light(16, 0);							//Turn off Ghost Lights
	light(17, 0);
	light(18, 0);
	light(67, 7);							//Old Prison solid = Mode Won!
	
	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();		
	
	ghostMove(90, 20);
	ghostModeRGB[0] = 0;
	ghostModeRGB[1] = 0;
	ghostModeRGB[2] = 0;
	ghostFadeTimer = 200;
	ghostFadeAmount = 200;	
	setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color
	
	light(62, 7);							//Light mode SOLID = Win
	
	ghostLook = 1;													//Ghost will now look around again.
	ghostAction = 0;

	ghostsDefeated[player] += 1;					//For bonuses	
	Advance_Enable = 1;						//Allow other modes to be started
	TargetTimerSet(5000, TargetUp, 100);	//Put targets back up, but not so fast ball is caught

	killQ();													//Disable any Enqueued videos
	
	playSFX(0, 'P', '9', 'X' + random(3), 255);					//Ghost dies, We fuckin' did it!
	video('P', '9', 'Z', noExitFlush, 0, 255); 					//Play Death Video	
	numbersPriority(0, numberFlash | 1, 255, 11, modeTotal, 233);			//Load Mode Total Points
	modeTotal = 0;							//Reset mode points		
	videoQ('P', '9', 'V', noEntryFlush | B00000011, 0, 233);	//Prison Mode Total:	
			
	playMusic('M', '2');							//Normal music
	
	Mode[player] = 0;						//Set mode active to None
	priProgress[player] = 100;				//Reset this for no real reason.

	if (countGhosts() == 2 or countGhosts() == 5) {	//Defeating 2 or 5 ghosts lights EXTRA BALL
	
		extraBallLight(2);							//Light extra ball, no prompt we'll do there
		//videoSFX('S', 'A', 'A', allowSmall, 0, 255, 0, 'A', 'X', 'A' + random(2), 255);	//"Extra Ball is Lit!"			
	
	}	
	
	demonQualify();									//See if Demon Mode is ready
	
	checkModePost();
	hellEnable(1);
	showProgress(0, player);					//Show the Main Progress lights
	
}

void PrisonFail() {

	multipleBalls = 0;
	tourClear();								//Clear the tour lights / values

	loadLamp(player);						//Bring in the old lights
	comboKill();

	convictState = 0;
	
	light(2, 0);							//Turn off mode counter lights
	light(3, 0);
	light(4, 0);
	light(5, 0);
	
	light(16, 0);							//Turn off Ghost Lights
	light(17, 0);
	light(18, 0);
	light(67, 7);

	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();	
	
	ghostModeRGB[0] = 0;
	ghostModeRGB[1] = 0;
	ghostModeRGB[2] = 0;
	ghostFadeTimer = 200;
	ghostFadeAmount = 200;	
	setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color

	if (ModeWon[player] & prisonBit) {								//Did we win this mode before?
		light(62, 7);												//Make Prison Mode light solid, since it HAS been won
	}
	else {
		light(62, 0);												//Haven't won it yet, turn it off
	}		
	
	ghostLook = 1;													//Ghost will now look around again.
	ghostAction = 0;

	ghostMove(90, 20);
	
	Advance_Enable = 1;						//Allow other modes to be started

	modeTotal = 0;							//Reset mode points	

	//playMusic('M', '2');					//Normal music

	Mode[player] = 0;						//Set mode active to None

	if (modeRestart[player] & prisonBit) {							//Able to restart Prison?
		modeRestart[player] &= ~prisonBit;							//Clear the restart bit	
		priProgress[player] = 3;									//When you come back, Prison lock will already be lit
	}
	else {
		priProgress[player] = 0;									//Blew it a second time? Gotta start all over!
	}	
		
	checkModePost();
	hellEnable(1);
	showProgress(0, player);					//Show the Main Progress lights
	
}

void restartPlayer(unsigned char whichPlayer) {

	animatePF(0, 0, 0);	

	randomSeed(micros());					//Reset randomizer

	int x = whichPlayer;

	popMode[x] = random(2) + 1;				//Starts either 1 = Fort or 2 = Bar (3 = EVP but never starts in that mode)
	
	if (popMode[x] == 1) {					//Start out Advancing Fort?
		light(20, 0);
		light(21, 0);
		light(22, 0);
		pulse(21);
	}
					
	if (popMode[x] == 2) {					//Start Out Advancing Bar?
		light(20, 0);
		light(21, 0);
		light(22, 0);
		pulse(22);	
	}

	Mode[x] = 0;
	achieve[x] = 0;                     //Clear achievements
      
	demonMultiplier[x] = 1;				//Reset this		
	achieve[x] = 0;							//BUT reset achievements so we can get them again
	
	SetScore(x);							//Set player's score on DMD
	ModeWon[x] = 0;							//Clear the bits of what modes they've won
	subWon[x] = 0;                    		//Clear the bits that enable Sub Wizard mode
	modeRestart[x] = B01111110;				//At the start each player gets 1 re-start chance per mode
	tourComplete[x] = B00000000;			//Which tours player has completed	
	
	hosProgress[x] = 0;
	theProgress[x] = 0;
	barProgress[x] = spotProgress;			//Can be changed in settings
	fortProgress[x] = spotProgress;			//Can be changed in settings
	hotProgress[x] = 0;
	priProgress[x] = 0;
	deProgress[x] = 100;					//You completed Demon Mode!
	
	lockCount[x] = 0;						//Reset # of locked Hellavator balls
	spiritProgress[x] = 0;					//If tourney mode, players get awards in sequence	
	spiritGuide[x] = 1;						//Spirit guide is always lit to start for each player	
	EVP_Jackpot[x] = 1000000;				//Reset to 1 million

	//Don't Reset EVP's!
	
	photosTaken[x] = 0;						//Total photos a player got.
	areaProgress[x] = 0;					//How many mode-advancing shots each player has made
	ghostsDefeated[x] = 0;
	photosNeeded[x] = 3;
	photoSecondsStart[x] = 21;				//How many seconds to get a ghost photo
	GLIR[x] = 1;							//At the start of the game, spell GLIR once to light Photo hunt, then twice, 3 times, ect.
	GLIRneeded[x] = 1;						//How many GLIR spells player needs to light PHOTO HUNT
	GLIRlit[x] = 0;							//Zero PHOTO HUNTS lit to start
	
	minion[x] = 1;							//Each player starts with Minion Fight enabled
	minionTarget[x] = 3;					//3 hits for first Minion Battle
	minionHits = 3;							//Reset this
	minionsBeat[x] = 0;						//How many minions you've beaten.
	minionHitProgress[x] = 0;				//No minion damage progress yet
	slingCount[x] = 0;	
	
	TargetSet(TargetUp);					//Put targets UP so we can enagage Minion Battle!

	//Don't reset ORB or Extra Balls!
	
	wiki[x] = 0;
	tech[x] = 0;
	psychic[x] = 0;	
	rollOvers[x] = 0;
	
	hellLock[x] = 1;						//Always start with Hell lock enabled		

	hellJackpot[x] = 1000000;				//Starting MB jackpot value
	hitsToLight[x] = 1;						//How many times you have to press "Call" before hellavator moves / lights for lock	(starts with just 1)						

	callHits = 0;								//How many times you've hit Call this ball (resets per player)	
	
	minionEnd(1);							//The default is to enable the Minion Battle	

	doorLogic();							//Figure out what to do with the door
	elevatorLogic();						//Can lock balls, Hellavator is Lit		

	scoreMultiplier = 1;					//This will almost always be 1
		
	trapDoor = 0;							//Flags if the ball should be trapped or not
	trapTargets = 0;
	

	spiritGuideEnable(1);					//Mode 0, it can always be lit		
	bonusMultiplier = 1;					//Reset multiplier (it's per ball so don't need unique variable per player)		
	modeTimer = 0;	
	HellBall = 0;

	tiltCounter = 0;						//Reset to zero
	
	sweetJumpBonus = 0;						//Reset score (hitting it adds value)
	sweetJump = 0;							//Reset video/SFX counter
	
	Advance_Enable = 1;						//Game starts with all modes eligible for advancement.
	AutoEnable = 255; 						// 255 /enables everything

	//The ball under the ghost is Active Ball #1. Release it and there is no need to change the value
	
	setCabMode(defaultR, defaultG, defaultB);	//Set the cab mode to default color
	
	comboKill();
	
	dirtyPoolMode(1);						//Check for Dirty Pool Balls
	Update(0);								//Update with the current info

	comboEnable = 1;						//OK combo all you want
	GLIRenable(1);								
	
	playMusic('M', '2');					//Normal music

	showProgress(0, player);				//Reset progress lights
	storeLamp(x);							//Store the status of every lamp in that player's memory

}

void restartBegin(unsigned char whichMode, unsigned char startingSeconds, int startingTimer) {

	restartMode = whichMode;				//If we fail, which mode progress do we reset?
	restartSeconds = startingSeconds;		//How many seconds you get
	restartTimer = startingTimer;			//Start this above 25k to give player time to get the ball back
	
	numbers(0, numberStay | 4, 0, 0, restartSeconds - 1);	//Update the Numbers Timer.	
	
}

void restartKill(unsigned char whichKill, unsigned char whatReason) {	//Fail to get a restart? Reset whatever mode we were trying to restart.

	killTimer(0);											//Turn off timer
	restartTimer = 0;										//Disable the timer
	restartSeconds = 0;										//Clear the seconds

	if (whichKill == restartMode and whatReason == 1) {		//Did we restart the same mode we just failed?
		restartTimer = 0;									//Disable the timer
		restartSeconds = 0;									//Clear the seconds	
		restartMode = 0;									//Clear the mode and return
		return;
	}
	
	if (whichKill == 0 and restartMode) {					//Did we get here via a drain, and there was a restart mode active?
	
		switch (restartMode) {								//Kill whatever restart mode was active (since the call to here wasn't explicit)
			case 1: 										//Hospital Restart Fail
				hosProgress[player] = 0;
				ghostMove(90, 20);
				checkModePost();
				showProgress(0, player);
				break;
			case 2: 										//Theater Fail
				theProgress[player] = 0;
				ghostMove(90, 20);
				checkModePost();
				showProgress(0, player);
				break;
			case 3: 										//Bar fail
				barProgress[player] = 0;
				ghostMove(90, 20);
				dirtyPoolMode(1);							//Check for Dirty Pool!
				loopCatch = 0;								//Disable loop catch
				checkModePost();
				showProgress(0, player);
				break;	
		}

		showProgress(0, player);
		restartMode = 0;		
		return;
	
	}
	
	//OK, player must have timed out the restart and game is still active

	video('B', '0', 'X', allowSmall, 0, 200);		//Restart time out video
	
	if (Advance_Enable) {
		playMusic('M', '2');							//Go back to normal music if nothing is going on
	}
	switch (whichKill) {								//Kill whatever restart mode was eligible (in case you actually started something else!)
		case 1: 										//Hospital Restart Fail
			hosProgress[player] = 0;
			ghostMove(90, 20);
			checkModePost();
			showProgress(0, player);
			break;
		case 2: 										//Theater Fail
			theProgress[player] = 0;
			ghostMove(90, 20);
			checkModePost();
			showProgress(0, player);
			break;
		case 3: 										//Bar fail
			barProgress[player] = 0;
			ghostMove(90, 20);
			dirtyPoolMode(1);							//Check for Dirty Pool!
			loopCatch = 0;								//Disable loop catch
			checkModePost();
			showProgress(0, player);
			break;	
	}
	showProgress(0, player);
	restartMode = 0;

}

void rollLeft() {								//Lane change LEFT

	rollOvers[player] = (rollOvers[player] << 1) | (rollOvers[player] >> 7);
	orb[player] = (orb[player] << 1) | (orb[player] >> 5);					//Top 2 MSB's of ORB are unused. Rotate lower 6.

  if (burstLane) {    
    if (burstLane > 52) {
      burstLane -= 1;
    }   
  }
	
	laneChange();

	//checkRoll();
	//checkOrb(0);
}

void rollRight() {								//Lane change RIGHT

	rollOvers[player] = (rollOvers[player] >> 1) | (rollOvers[player] << 7); //Rotate bit right
	orb[player] = (orb[player] >> 1) | (orb[player] << 5);					 //Top 2 MSB's of ORB are unused. Rotate lower 6
	
  if (burstLane) {    
    if (burstLane < 55) {
      burstLane += 1;
    }   
  }
  
	laneChange();
	//checkRoll();
	//checkOrb(0);
}

void scoopDo() {								//What to do when the ball is shot into the scoop (a lot can happen!)

  if (subWon[player] == subWizReady and Advance_Enable) {
  
    bumpsStart();
    return;
    
  }

	if (barProgress[player] == 80) {								//In ghost whore multiball?
		if (kegsStolen < 10) {
			video('B', '0', 'W', allowSmall, 0, 255); 						//Kaminski with beer
			playSFX(0, 'B', 'K', 'A' + random(8), 255);						//Kaminski comments about free beer
      
      if ((achieve[player] & barBit) == 0) {            //First time we've done this?
      
        achieve[player] |= barBit;                      //Set the bit
        
        if ((achieve[player] & allWinBit) == allWinBit) {             //Did we get them all? Add the multiplier prompt
          videoQ('R', '7', 'E', 0, 0, 255);             //All sub modes complete!
          demonMultiplier[player] += 1;							    //Add multiplier for demon mode
          playSFXQ(0, 'D', 'Y', 'A' + random(6), 255);  //Add Multiplier! 
        }
        
      }         
            
			kegsStolen += 1;		
			showValue(kegsStolen * 100000, 40, 1);
		}
		else {
			video('B', '0', 'U', allowSmall, 0, 255); 						//"No Kegs Left!"
			playSFX(0, 'B', 'K', 'I' + random(4), 255);		
		}
		
	}

	if (Mode[player] == 1) {										//If Touring the Hospital, complete % of tour and kick out.
		tourGuide(0, 1, 5, 505010, 1);								//Give more points than normal (scoop is harder shot)
		return;
	}

	if (hotProgress[player] > 29 and hotProgress[player] < 40) {	//Fighting the Hotel Ghost? (can't do tour during the Control Box search)
		tourGuide(0, 5, 5, 505010, 1);								//Give more points than normal (scoop is harder shot)
		return;
	}	

	if (Advance_Enable and fortProgress[player] == 50) {			//Eligible to start War Fort?			
		WarStart();			
		return;
	}
				
	if (Advance_Enable and barProgress[player] == 50) {				//Eligible to start Bar?			
		BarStart();			
		return;														//Return so other modes can't start
	}
			
	if (hotProgress[player] == 20)	{								//Searching for the Control Box?
		BoxCheck(4);												//Check / flag box for this location
		ScoopTime = 20000;											//Kick out the ball
		return;														//Return so other modes can't start
	}

	if (GLIRlit[player] == 1 and Advance_Enable == 1) {				//Flag for Photo Hunt Start? Must equal 1, so if MSB set, will prevent a start
		GLIRlit[player] = 0;										//Decrement how many we have
		photoStart();												//Start that mode!
		return;														//Return so other modes can't start
	}

	if (deProgress[player] > 9 and deProgress[player] < 100) {									//Trying to weaken demon
		DemonCheck(5);
		return;
	}	
	
	if (Mode[player] == 7) {										//Are we in Ghost Photo Hunt?
		photoCheck(5);
		return;														//Return so other modes can't start
	}

	if (theProgress[player] > 9 and theProgress[player] < 100) {	//Theater Ghost?
		if (theProgress[player] > 9 and theProgress[player] < 100) {			//Theater Ghost?
			if (theProgress[player] == 12) {	//Waiting for Shot 3, in which case this shot is CORRECT?
				TheaterPlay(1);					//Advance the play!
				return;
			}
			else {			
				TheaterPlay(0);					//Incorrect shot, ghost will bitch!
				return;
			}
		}
	}			

	//If none of those things are active, we do Spirit Guide (if lit)
	
	if (spiritGuide[player] == 255) {									//Spirit guide not lit?
		video('S', 'G', 'Y', allowSmall, 0, 250);					//Spell Team Members prompt
		return;														//Just give the ball back
	}
	if (spiritGuide[player] == 1) {									//Player has a Spirit Guide, but can we collect it?
		if (spiritGuideActive == 1) {								//Spirit guide is LIT and available at the moment
			spiritGuideStart();										//Do routine
			return;
		}
		else {
			video('S', 'G', 'X', allowSmall, 0, 250);				//Available after mode ends
			return;		
		}
	}

}

void sendJackpot(unsigned char whichNumber) {	//Adds any multipliers to jackpot and sends that current # to the display

	//Most jackpots use a simple multipler. Check if it's a fancy one first.

	if (barProgress[player] == 80) {			//Fighting ghost whore? Then it's special. So special.
		if (whoreJackpot < 10) {											//Play the normal-ish ones for first 10 hits
			manualScore(0, EVP_Jackpot[player] + ((whoreJackpot + 1) * 100000));	//Update the value for score display		
		}
		else {
			manualScore(0, EVP_Jackpot[player] + ((whoreJackpot + 1) * 200000));	//Update the value for score display
		}	
		return;
	}

	if (jackpotMultiplier == 0) {				//Did we forget to set it?
		manualScore(0, EVP_Jackpot[player]);	//Send normal value
	}
	else {
		manualScore(0, EVP_Jackpot[player] * jackpotMultiplier);	//Send multiplied value
	}

}	


void showProgress(unsigned char modeStatus, unsigned char whichPlayer) {

	//modeStatus:
	//0000 - Not in a mode, show overall mode progress, path progress, ORB, GLIR
	//0001 - In a mode, show overall mode progress, ORB and GLIR (basically, just no paths)

	if (HellSpeed)	{												//In motion? Base this off where it's headed, not where it IS
		if (HellTarget == hellDown) {
			light(41, 0);											//Turn OFF Hell Flasher
		}
		if (HellTarget == hellUp) {
			blink(41);												//Turn ON Hell Flasher	
		}						
	}
	else {															//Not in motion? Normal check
		if (HellLocation == hellDown) {								//State of Hellavator may have changed during mode so update its flasher to match its position. Notice how I used "its" properly both times?			
			light(41, 0);											//Turn OFF Hell Flasher				
		}		
		if (HellLocation == hellUp) {		
			blink(41);												//Turn ON Hell Flasher		
		}		
	}	
		
	if (modeStatus == 0 and Advance_Enable == 1) {				//Show all the mode path progress (1 2 3 indicators, etc)

		if (priProgress[player] < 100) {						//Able to advance or restart Prison?
			if (priProgress[player] == 0) {									//Always fill lights
				pulse(3);
				light(4, 0);
				light(5, 0);
				light(6, 0);		
			}
			if (priProgress[player] == 1) {									//Always fill lights
				light(3, 7);
				pulse(4);
				light(5, 0);
				light(6, 0);		
			}	
			if (priProgress[player] == 2) {									//Always fill lights
				light(3, 7);
				light(4, 7);
				pulse(5);
				light(6, 0);		
			}			
			if (priProgress[player] == 3) {									//Third advance?
				pulse(3);													//Pulse the 3 lights
				pulse(4);													//As player locks balls, lights go from Pulse to Solid
				pulse(5);
				blink(6);													//Blink "Prison Lock"
			}	
			
			if (priProgress[player] > 2 and priProgress[player] < 8) {		//Locking Balls?
				light(3, 7);												//First 3 solid
				light(4, 7);
				light(5, 7);
				blink(6);													//Blink "Prison Lock"		
			}		
		}
		else {
			light(3, 0);
			light(4, 0);
			light(5, 0);
			light(6, 0);			
		}

		if (hosProgress[player] < 90) {						//Able to advance hospital
			if (hosProgress[player] == 0) {
				pulse(8);
				light(9, 0);
				light(10, 0);
				light(11, 0);		
			}
			if (hosProgress[player] == 1) {
				light(8, 7);
				pulse(9);
				light(10, 0);
				light(11, 0);		
			}
			if (hosProgress[player] == 2) {
				light(8, 7);
				light(9, 7);
				pulse(10);
				light(11, 0);		
			}		
			if (hosProgress[player] == 3) {
				light(8, 7);
				light(9, 7);
				light(10, 7);
				pulse(11);		
			}	
		}
		else {							//Can't restart it!
			light(8, 0);
			light(9, 0);
			light(10, 0);
			light(11, 0);		
		}
		
		if (hotProgress[player] < 100) {						//Able to advance hotel?
			if (hotProgress[player] == 0) {
				pulse(26);
				light(27, 0);
				light(28, 0);
				light(29, 0);		
			}
			if (hotProgress[player] == 1) {
				light(26, 7);
				pulse(27);
				light(28, 0);
				light(29, 0);		
			}
			if (hotProgress[player] == 2) {
				light(26, 7);
				light(27, 7);
				pulse(28);
				light(29, 0);		
			}		
			if (hotProgress[player] == 3) {
				light(26, 7);
				light(27, 7);
				light(28, 7);
				pulse(29);		
			}	
		}
		else {
			light(26, 0);
			light(27, 0);
			light(28, 0);
			light(29, 0);
		}

		if (theProgress[player] < 100) {						//Able to advance Theater?
			if (theProgress[player] == 0) {
				pulse(36);
				light(37, 0);
				light(38, 0);
				light(12, 0);		
			}
			if (theProgress[player] == 1) {
				light(36, 7);
				pulse(37);
				light(38, 0);
				light(12, 0);		
			}
			if (theProgress[player] == 2) {
				light(36, 7);
				light(37, 7);
				pulse(38);
				light(12, 0);		
			}		
			if (theProgress[player] == 3) {										//Ready to start?
				light(36, 7);
				light(37, 7);
				light(38, 7);
				pulse(12);
				light(11, 0);													//If doctor AND theater both ready, Theater gets priority
			}	
		}
		else {													//Can't start or re-start, all lights OFF
			light(36, 0);														//Turn them all OFF
			light(37, 0);
			light(38, 0);
			light(12, 0);	
		}

		if (minionMB == 10) {									//Is that going on as well?
			light(16, 0);								//Turn OFF make contact
			pulse(17);									//Strobe target lights
			pulse(18);
			pulse(19);
			pulse(39);

		}	
		if (minionMB == 20) {									//Is that going on as well?
			pulse(16);									//Pulse MAKE CONTACT
			light(17, 0);								//Turn off lights
			light(18, 0);
			light(19, 0);	
			pulse(7);
		}			
		
	}

	laneChange();								//Update ORB and GLIR
	
	//updateRollovers();							//Update ORB and GLIR

  GIbg(0x00);                               //Clear the GI backglass bits, then add back in any ghosts we've beaten
  
	if (ModeWon[whichPlayer] & B00000010) {		//Hospital?
		light(57, 7);
    GIbgSet(1, 1);
	}
	if (ModeWon[whichPlayer] & B00000100) {		//Theater?
		light(58, 7);
    GIbgSet(5, 1);
	}
	if (ModeWon[whichPlayer] & B00001000) {		//Haunted bar?
		light(60, 7);
    GIbgSet(2, 1);
	}
	if (ModeWon[whichPlayer] & B00010000) {		//War fort?
		light(59, 7);
    GIbgSet(3, 1);
	}
	if (ModeWon[whichPlayer] & B00100000) {		//Hotel?
		light(61, 7);
    GIbgSet(4, 1);
	}
	if (ModeWon[whichPlayer] & B01000000) {		//Prison?
		light(62, 7);
    GIbgSet(0, 1);
	}		

	if (deProgress[whichPlayer] == 100) {		//Already beat it once?
		light(63, 7);							//Light is solid!
	}
	
	if (wiki[player] < 255) {
		pulse(0);
	}
	else {
		light(0, 7);
	}
	if (tech[player] < 255) {
		pulse(1);
	}
	else {
		light(1, 7);
	}	
	if (psychic[player] < 255) {
		pulse(51);
	}
	else {
		if (scoringTimer) {						//Double scoring active so the light blinks	
			blink(51);	
		}
		else {
			light(51, 7);						//Completed, so it's solid			
		}	
	}
	
	showScoopLights();

	if (extraLit[player]) {						//Extra ball lit?
		pulse(15);								//Pulse the light			
	}
	else {
		light(15, 0);							//If not, that sucker should be OFF
	}
	
	//Overall Progress Towards Demon Mode
	if (photosNeeded[player] > 3) {				//Did you complete at least 1 photo hunt?
		light(50, 7);	
	}	
	if (hitsToLight[player] > 1) {				//Completed a Hellavator Multiball?
		light(49, 7);
	}
	if (ModeWon[whichPlayer] == B01111110) {	//Beat all Ghost Bosses?
		light(48, 7);							//Light is solid!
	}	
	if (minionsBeat[player] > minionMB1) {		//Beat 3 or more minions?
		light(2, 7);
	}

  if (subWon[player] == subWizReady) {        //If Sub Wizard enabled, pulse the 3 mode complete lights that led to it
    pulse(50);
    pulse(49);
    pulse(2);   
  }
  
  if (subWon[player] == subWizWon) {        //If Sub Wizard enabled, pulse the 3 mode complete lights that led to it
    light(50, 7);
    light(49, 7);
    light(2, 7);   
  }  
  
}

void showScoopLights() {

	if (theProgress[player] == 12) {								//Waiting for third shot for Theater?
		TheaterStrobe();											//Turn the strobe back on, return
		return;
	}

	//Show what the scoop can do.
	//Dimly light lights = available but not Top Priority

	light(43, 0); //Clear all SCOOP lights, start with a clean slate
	light(44, 0);
	light(45, 0);
	light(46, 0);
	light(47, 0);
	
	int guideBright = 7;											//By default, these can be Bright (Pulsing)
	int glirBright = 7;												//If they get modifed, they will light differently
																	//This code doesn't control priority, just makes the lights represent priority
		
	//CONDITIONS WHERE CAMERA LIGHT MIGHT BE ON

  
  //Don't enable this yet until we get the mode programmed
  if (subWon[player] == subWizReady and Advance_Enable) {         //If sub mode lit, the Scoop will start it next shot
  
    strobe(43, 5);
    return;    
    
  }
  
	if (hotProgress[player] == 20)	{													//Searching for the Control Box?

		if (ControlBox[4] == 1) {												//Did we already check here?
			light(47, 0);																//Camera is OFF
		}	
		if (ControlBox[4] == 0 or ControlBox[4] == 255) {				//Haven't checked there yet?
			pulse(47);																	//Camera is PULSING
		}		
	
	}

	if (tourLights[5] == 1) {										//If a TOUR LIGHT is set here, make sure it resumes blinking
		blink(photoLights[5]);
	}
	
	if (barProgress[player] == 80) {								//Ghost whore multiball?
		pulse(47);													//Pulse Scoop Camera for beer stealing
	}
	
	if (Advance_Enable and fortProgress[player] == 50) {			//Eligible to start War Fort?			
		guideBright = 1;											
		glirBright = 1;		
		pulse(44);
	}
				
	if (Advance_Enable and barProgress[player] == 50) {				//Eligible to start Bar?			
		guideBright = 1;
		glirBright = 1;		
		pulse(45);
	}

	light(43, 0);													//Default is GLIR off
	
	if (GLIRlit[player] == 129) {									//GLIR is lit but has been disabled for this mode (MSB set)
		light(43, 1);												//Light it dimly lest we forget about it
	}
	
	if (GLIRlit[player] == 1) {										//OK GLIR is lit and no specific limitation set on it (usually via Minion Mode)
	
		if (Advance_Enable) {										//Modes can be started?
			pulse(43);												//Pulse that sucker						
			guideBright = 1;										//... and indicate Spirit Guide is low priority (if it happens to be lit also)
		}
		else {														//GLIR is dim
			light(43, 1);
		}	
	}

  GIbgSet(6, 0);                                //By default, turn OFF the Crystal Ball BG light
  
	if (spiritGuide[player] == 1) {									//Is it lit / has been earned (EARN THIS!!!)
		if (spiritGuideActive) {									//Can it currently be collected?
			if (guideBright == 7) {									//GLIR doesn't have priority?
				pulse(46);											      //Pulse SPIRIT GUIDE
        GIbgSet(6, 1);                        //Set the light since it is eligible
			}
			else {
				light(46, guideBright);								//Earned, but not what scoop will award at this time so dim
			}			
		}
		else {
			light(46, 1);											//We earned it, but can't collect at this time, so dim
		}	
	}
	else {
		light(46, 0);												//Not even lit, so it's off
	}
	
}

void skillShotNew(unsigned char show1st) {						//Call this to randomly pick a Skill Shot and enable it (either on Player 1 Ball 1 or next player start)

	skillShot = random(3);										//Pick 1, 2 or 3
	skillShot += 1;												//Pops = 1, ORBS = 2, Basement = 3
	//videoPriority(0);											//Zero out video priority

	skillScoreTimer = 0;										//Reset this
	
	if (numPlayers == 1) {										//In single player games, do not indicate Player #	
		customScore('K', '0', 64 + skillShot, allowSmall | loopVideo);			//Custom Score for skill shot
    numbers(8, numberScore | 6, 0, 0, player);						//Put player score upper left, using Double Zeros
    numbers(9, 9, 88, 0, 0);										          //Ball # upper right	
	}
	else {																				              //Multiplayer, show which player is up and has the skill shot

    videoQ('K', 48 + player, 64 + skillShot, allowSmall | noEntryFlush, 0, 1);
    numbers(7, 2, 44, 27, numPlayers);										    //Update Number of players indicator
    numbers(6, numberScore | 6, 0, 0, player);						    //Put player score upper left, using Double Zeros
    numbers(5, 9, 88, 0, 0);										              //Ball # upper right	  

		//customScore('K', 48 + player, 64 + skillShot, allowSmall | loopVideo);			//Custom Score for skill shot
		//video('K', '0', 64 + skillShot, loopVideo | allowSmall, 0, 1);
		
	}	
  
  if (ball > 1) {
    playSFX(0, 'S', '0' + skillShot, 'A' + random(3), 255);			//Psychic skill shot prompt				
  }

}

void skillShotSuccess(unsigned char didSucceed, unsigned char showMiss) {						//What happens when you make the skill shot

  gameRestart = 0;                 //Used for holding START to restart game. Re-clear it once ball has launched

	//This happens no matter what
	ballSave();												//Start the ballsaver at this point and check what to do with Spook Again light
	//killQ();												//Disable any queued videos
	//killNumbers();
	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();		
	
	unsigned long skillValue = 0;
	
	if (didSucceed) {
		//video('K', '0', '0', 0, 0, 255);					  //Top priority success video!

		switch(skillShot) {									          //Gonna be 1, 2 or 3
			case 1:
				skillValue = 250000;						          //Pops a bit harder
				skillShotComplete[player] |= popSS;		    //Set bits
			break;
			case 2:
				skillValue = 125000;						          //Orbs easiest
				skillShotComplete[player] |= orbSS;		    //Set bits
			break;
			case 3:
				skillValue = 500000;						          //Behind hellavator hardest
				skillShotComplete[player] |= helSS;		    //Set bits
			break;			
		}	
		
    lightningStart(200000);
    animatePF(460, 30, 0);
    
		if (skillShotComplete[player] == allSS) {					                //Were all 3 SS's done in the course of the game? Double the award!
			skillShotComplete[player] = 0;									                //Clear it. In theory, with extra balls + 5 ball games this could be accomplished again
			video('K', '0', '2', allowAll, 0, 255);							            //All clear video   
			playSFX(1, 'A', 'F', '0' + random(3), 255);						          //Skill Shot Complete / Success!
			numbers(7, numberFlash | 1, 255, 11, (skillValue * ball) * 2);	//Print skill shot value  DOUBLE VALUE!      
			AddScore((skillValue * ball) * 2);								              //WHAT IS AWARD?							
		}
		else {			
			video('K', 'A', 'D', allowAll, 0, 255);						//New success video!    
			playSFX(1, 'A', 'E', '0' + random(6), 255);				//Normal Success Dialog!	
			//showValue(skillValue * ball, 40, 1);						//Show the value after video	
			numbers(7, numberFlash | 1, 255, 11, skillValue * ball);	//Print skill shot value       
			AddScore(skillValue * ball);								//500k pops, 1 mil ORB, 1.5 mil Basement X Ball # (so worth more on Ball 3)					
		}
	
	}
	else {
		if (showMiss) {
			video('K', '0', '1', 0, 0, showMiss);			//Put in a SKILL SHOT MISSED graphic here (very low priority)
			playSFX(0, 'Q', 'Z', 'Z', 200);						//Else, negative sound!	
			//playSFX(0, 'S', 'H', '0' + random(8), 255);		//Give player shit
		}
	}

	skillShot = 0;											//Disable skill shot
	modeTimer = 0;											//Reset the timer
  
  Update(0);
	
}

void skippable() {								//If a skippable event is active (SKIP > 0) this function decides what to jump to if player chooses to speed things up

	switch (skip) {								//Choose what to do!
		case 10:								//Hospital Ghost Stuff (probably just the beginning)
			if (plungeTimer > 25010) {			//Waiting for second ball?
				plungeTimer = 25010;			//Set it to near-immediate load state
			}
			break;
		case 20:								//Theater Ghost (beginning and every subsequent shot!)
			if (LeftTimer > 6010) {				//Beginning of theater? (Eject from behind door)
				LeftTimer = 6010;
				modeTimer = longSecond * 2;		//Remove grace period on timer
			}
			break;
		case 21:								//Theater Ghost second shot, waiting for elevator to go down
			if (HellLocation > hellDown) {		//Did the Hellavator not make it to the stuck position yet?
				ElevatorSet(hellDown, 5);		//Speed up the hellavator!
				modeTimer = longSecond * 2;
			}
			break;	
		case 22:								//Theater Ghost third shot waiting for left VUK?
			if (LeftTimer > 6010) {
				LeftTimer = 6010;
				modeTimer = longSecond * 2;		//Remove grace period on timer
			}
			break;		
		case 23:								//Theater Ghost (beginning and every subsequent shot!)
			if (ScoopTime > 9010) {				//Waiting for ball to eject scoop?
				ScoopTime = 9010;				//KIck it out now!
				TargetTimerSet(10, TargetDown, 50);	//Put targets down quickly
				modeTimer = longSecond;			//Remove grace period
			}
			break;			
		case 30:								//Bar ghost "waiting for embrace"
			if (ScoopTime > 9010) {
				ScoopTime = 9010;
				TargetTimerSet(10, TargetDown, 30);	//Put targets down quickly
			}
			break;
		case 35:								//Bar ghost "waiting for embrace"
			if (plungeTimer > 25010) {			//Waiting for second ball?
				plungeTimer = 25010;			//Set it to near-immediate load state
			}
			break;			
		case 40:								//War ghost, probably just the mode opening (rest is pretty fast)
			if (ScoopTime > 9010) {
				TargetTimerSet(10, TargetUp, 50);	//These might not be up yet, so do it now quickly
				ScoopTime = 9010;
			}
			break;
		case 50:								//Hotel ghost. Elevator move 1, elevator move 2 + scoop eject
			if (HellLocation > hellStuck) {		//Did the Hellavator not make it to the stuck position yet?
				ElevatorSet(hellStuck, 5);		//Speed up the hellavator!
			}
			break;
		case 55:								//Hotel ghost. Waiting for ball to get ejected from scoop
			if (ScoopTime > 9010) {				//Waiting for ball to start Control Box Search?
				ScoopTime = 9010;				//KIck it out now!
			}
			break;			
		case 60:								//Scoop eject while Ghost is talking about devouring friends
			if (ScoopTime > 9010) {				//Waiting for ball to start Control Box Search?
				ScoopTime = 9010;				//KIck it out now!
			}
			break;
		case 65:								//Scoop eject while Ghost is talking about devouring friends
			if (ScoopTime > 9010) {				//Waiting for ball to start Ghost Photo Hunt?
				ScoopTime = 9010;				    //KIck it out now!
			}
			break;
		}

	skip = 0;									        //Reset skip no matter what
	video('K', 'A', 'A', 0, 0, 255);	//White to black transition	

}

void spiritGuideStart() {						//When you shoot into the scoop with Spirit Guide lit
	
	//pulse(46);
	light(46, 0);								//Turn off its light
	
	//volumeSFX(3, 100, 100);						//Temp music volume increase

	if (tournament) {
		spiritGuide[player] = spiritProgress[player];		//If in tourney mode, see what award is next	
	}

	while (spiritGuide[player] < 99) {					//Repeat this until we give an award that doesn't conflict with anything going on

		if (tournament == 0) {
			spiritGuide[player] = random(18); //9;				//18 Get a random number
		}
															//If that award is valid, we add 100 to its value to leave this loop
															//There are several points awards so there's always something valid
		switch (spiritGuide[player]) {						//Turn off the lights when we hit them
			case 0: //Light GLIR
				if (Advance_Enable == 1 and (GLIR[player] > 0 and GLIR[player] < 100) and Mode[player] == 0 and minion[player]) {
					spiritGuide[player] += 100;				//Approved, continue
				}
				break;
			case 1: //Lite HOSPITAL
				if (Advance_Enable == 1 and (ModeWon[player] & B00000010) == 0 and hosProgress[player] < 3 and theProgress[player] < 3) {	//Hospital hasn't been won, or in progress?
					spiritGuide[player] += 100;				//Award approved, proceed
				}
				break;
			case 2: //500,000 points
				spiritGuide[player] += 100;				//Award approved, proceed
				break;
			case 3: //Reveal Minion?
				if (Advance_Enable == 1 and minion[player] == 1 and videoMode[player] == 0) {	//Not in a mode, and Minion is able to be started, and we're not waiting for Video Mode start?
					spiritGuide[player] += 100;				//Award approved, proceed
				}
				break;
			case 4: //Lite theater?
				if (Advance_Enable == 1 and (ModeWon[player] & B00000100) == 0 and theProgress[player] < 3 and hosProgress[player] < 3) {	//Can't enable Theater and Hospital at same time
					spiritGuide[player] += 100;				//Award approved, proceed
				}
				break;
			case 5: //1,000,000 points
				spiritGuide[player] += 100;				//Award approved, proceed
				break;
			case 6: //Advance Bonus?
				spiritGuide[player] += 100;				//Award approved, proceed
				break;
			case 7: //Lite War Fort?
				if (Advance_Enable == 1 and (ModeWon[player] & B00001000) == 0 and fortProgress[player] < 50 and barProgress[player] < 50 and videoMode[player] == 0) {	//Can't enable War and Bar at the same time
					spiritGuide[player] += 100;				//Award approved, proceed
				}
				break;
			case 8: //2,000,000
				spiritGuide[player] += 100;				//Award approved, proceed
				break;
			case 9: // 30 seconds Ball Save
				spiritGuide[player] += 100;				//Award approved, proceed
				break;
			case 10: //Lite Haunted Bar?
				if (Advance_Enable == 1 and (ModeWon[player] & B00010000) == 0 and fortProgress[player] < 50 and barProgress[player] < 50 and videoMode[player] == 0) {	//Can't enable War and Bar at the same time
					spiritGuide[player] += 100;				//Award approved, proceed
				}
				break;
			case 11: //3,000,000 points
				spiritGuide[player] += 100;				//Award approved, proceed
				break;
			case 12: //Start Multiball?
				if (Advance_Enable == 1 and lockCount[player] == 0 and multiBall == 0 and minionMB == 0 and videoMode[player] == 0) {
					spiritGuide[player] += 100;				//Award approved, proceed
				}
				break;
			case 13: //Lite Hotel?
				if (Advance_Enable == 1 and (ModeWon[player] & B00100000) == 0 and hotProgress[player] < 3) {
					spiritGuide[player] += 100;				//Award approved, proceed
				}
				break;
			case 14: //3,666,000
				spiritGuide[player] += 100;				//Award approved, proceed
				break;
			case 15: //Award EVP
				spiritGuide[player] += 100;				//Award approved, proceed
				break;
			case 16: //Lite Prison Lock
				if (Advance_Enable == 1 and (ModeWon[player] & B01000000) == 0 and priProgress[player] < 3) {	//If not in a mode, or doing this already, it's a good award
					spiritGuide[player] += 100;				//Award approved, proceed
				}
				break;
			case 17: //Lite extra ball?
				if (ball > 2 and allowExtraBalls) {			//Won't give you one on Ball 1 or 2, hahaha! Or if they're disabled
					spiritGuide[player] += 100;				//Award approved, proceed
				}
				break;	
			}
		
		if (tournament and spiritGuide[player] < 99) {		//Current award wasn't valid?
			spiritGuide[player] += 1;						//If in tourney mode, see what award is next
			spiritProgress[player] += 1;					//Advance our progress as well
			if (spiritGuide[player] > 17) {					//Did we somehow get them ALL???
				spiritGuide[player] = 0;					//Reset back to 0
				spiritProgress[player] = 0;		
			}						
		}					
	}	
	
	killQ();												//Disable an Enqueued videos

	spiritProgress[player] += 1;						//Advance our progress since we collected that one
	
	if (spiritProgress[player] > 17) {					//Did we somehow get them ALL???											
		spiritProgress[player] = 0;						//Reset back to 0		
	}	
	
  
	if (Advance_Enable) {
		playMusicOnce('S', 'V');								                  //Switch to Spirit Guide Theme
		playSFX(2, 'S', 'G', '0' + random(9), 255);				        //Spirit Guide!	
		video('S', 'G', spiritGuide[player] - 35, 0, 0, 255);		  //Play video A-R	
    playSFX(1, 'R', 'A',  spiritGuide[player] - 35, 255);	    //Start playing Team Leader callout for what we've won (has built-in blank space)
		ScoopTime = 60000;											                  //Award is given as ball is shot out (we'll have to play with the timing)		
	}
	else {
		video('U', 'Q', spiritGuide[player] - 35, 0, 0, 255);		  //Play video A-R	
		ScoopTime = 25000;											                  //Award is given as ball is shot out (we'll have to play with the timing)	
		playSFX(2, 'S', 'G', 'C', 255);								//Short "Spirit Guide" + music
		playSFX(1, 'R', 'B',  spiritGuide[player] - 35, 255);		//Team leader callout (shorter)		
	}	  
  
/*  
  
	if (Advance_Enable) {
		playMusicOnce('S', 'G');								//Switch to Spirit Guide Theme
		//playMusicOnce('S', 'V');								//New altered version	
		video('S', 'G', spiritGuide[player] - 35, 0, 0, 255);	    //Play video A-R	    
		playSFX(2, 'S', 'G', '0' + random(9), 255);				        //"Spirit Guide"			
		playSFX(1, 'R', 'A',  spiritGuide[player] - 35, 255);	    //Start playing Team Leader callout for what we've won (has built-in blank space)		
		ScoopTime = 60000;										//Award is given as ball is shot out (we'll have to play with the timing)		
	}
	else {
		video('U', 'Q', spiritGuide[player] - 35, 0, 0, 255);		//Play video A-R	
		ScoopTime = 25000;											//Award is given as ball is shot out (we'll have to play with the timing)	
		//playSFX(2, 'S', 'G', 'B', 255);							//Orchestra hits...
		//playSFX(1, 'S', 'G', '0' + random(9), 255);				//Spirit Guide!	
		playSFX(2, 'S', 'G', 'C', 255);								//Short "Spirit Guide" + music
		playSFX(1, 'R', 'B',  spiritGuide[player] - 35, 255);		//Team leader callout (shorter)		
		
	}	

*/
}

void spiritGuideAward() {						//It gives you the award and spits out ball

	//volumeSFX(3, musicVolume[0], musicVolume[1]); //Revert to normal volume

	spiritGuide[player] -= 100;					//Set the number back to normal
	
	switch (spiritGuide[player]) {						//Award whatever prize we came up with. It's already approved, so just DO IT
		case 0: //Light GLIR
			if (GLIRneeded[player] < 9) {							//Getting free GLIR also increases spellings required to get more (to be fair)
				GLIRneeded[player] += 1;							//Increase target #	needed, max is 9		
			}
			GLIR[player] = GLIRneeded[player];						//Set counter to new target #				
			GLIRlit[player] = 1;									//Set flag			
			rollOvers[player] = 0;									//Clear rollovers
			blink(52);												//Blink GLIR for a bit
			blink(53);
			blink(54);
			blink(55);
			showScoopLights();										//Update lights		
			
			displayTimerCheck(89999);								//Check if anything was running, set new value						
			playSFX(0, 'F', '1', 'A' + random(4), 200);				//"Photo Hunt is Lit!" prompt. Higher priority, will override normal rollover sound
			video('F', '1', 'A', allowSmall, 0, 200);						//GLIR, photo hunt is lit!			

			break;
		case 1: //Lite HOSPITAL
			hosProgress[player] = 3;
			for (int x = 0 ; x < hosProgress[player] ; x++) {			//in case we did a Double Advance
				light(x + 8, 7);										//Completed lights to SOLID		
			}
			pulse(hosProgress[player] + 8);								//Pulse DOCTOR GHOST light
			video('H', 48 + hosProgress[player], 'A', allowSmall, 0, 200);		//Prompts to shoot for it
			playSFX(0, 'H', 48 + hosProgress[player], random(4) + 65, 255);
			DoorSet(DoorOpen, 500);										//Set door to creak open, 25 cycles per position
			break;
		case 2: //500,000 points
			AddScore(500000);
			break;
		case 3: //Reveal Minion?
			minionStart();
			break;
		case 4: //Lite theater?
			theProgress[player] = 3;									//Set progress
			light(36, 7);
			light(37, 7);
			light(38, 7);
			pulse(12);
			if (hosProgress[player] == 3) {								//Can only start one or the other, Theater has priority
				light(11, 0);
			}
			playSFX(0, 'T', '3', random(4) + 65, 255);
			video('T', '3', 'A', allowSmall, 0, 255);					//Play video
			light(theProgress[player] + 34, 7);							//Solid progress light
			pulse(12);													//Blink light 12 for Theater Start	
			DoorSet(DoorOpen, 50);										//Open the door.
			break;
		case 5: //1,000,000 points
			AddScore(1000000);
			break;
		case 6: //Advance Bonus?
			orb[player] = B00111111;				//Manually set them to Rolled Over
			checkOrb(1);
			break;
		case 7: //Lite War Fort?
			video('W', '0', '0', 0, 0, 255);		//Prompt for Army Ghost Lit		
			playSFX(0, 'W', '3', random(4) + 65, 250); //Prompt for Mode Start					
			fortProgress[player] = 50;				//50 indicates Mode is ready to start.				
			popLogic(3);							//EVP pops	
			spiritGuideEnable(0);		
			showScoopLights();						//Update the Scoop Lights
			break;
		case 8: //2,000,000
			AddScore(2000000);
			break;
		case 9: // 30 seconds Ball Save
			saveTimer = 30 * cycleSecond;				//Huge ball saver!
			spookCheck();								//See what to do with the light
			//blink(56);									//Blink the SPOOK AGAIN light
			break;
		case 10: //Lite Haunted Bar?
			video('B', '4', '0', 0, 0, 255);			//Prompt for Bar Ghost Lit		
			playSFX(0, 'B', '3', random(4) + 65, 255); //Advance sound 3							
			barProgress[player] = 50;					//50 indicates Mode is ready to start.			
			popLogic(3);								//Pops won't do anything else until you start the mode
			spiritGuideEnable(0);	
			showScoopLights();							//Update the Scoop Lights
			break;
		case 11: //3,000,000 points
			AddScore(3000000);
			break;
		case 12: //Start Multiball?											//NEEDS MANUAL SETTINGS!!!
			stopMusic();
			blink(26);														//Need to do a few things manually...
			blink(27);
			blink(28);		
			multiBallStart(0);
			if (hellMB == 1) {
				hellMB = 10;						//Set flag that music / mode has begun!
				volumeSFX(3, musicVolume[0], musicVolume[1]);	//Back to normal
				playMusic('M', 'B');				//The multiball music!	
				multipleBalls = 1;					//When MB starts, you get ballSave amount of time to loose balls and get them back
				ballSave();							//That is, Ball Save only times out, it isn't disabled via the first ball lost							
			}
			break;
		case 13: //Lite Hotel?
			hotProgress[player] = 3;
			playSFX(0, 'L', 48 + hotProgress[player], random(4) + 65, 255);	//First 3 sets of Hotel advance sounds.
			video('L', 48 + hotProgress[player], 'A', allowSmall, 0, 255);			//Adance videos
			light(26, 7);													//Light hotel status solid
			light(27, 7);
			light(28, 7);
			pulse(29);														//Pulse HOTEL GHOST
			ElevatorSet(hellUp, 200);										//Move the elevator into 2nd floor position
			blink(41);
			light(24, 0);													//Turn off CALL ELEVATOR lights
			light(25, 0);
			break;
		case 14: //3,666,000
			AddScore(3666000);
			break;
		case 15: //Award EVP
			popCount = EVP_Target - 1;				//Set it so we'll get one
			evpPops();
			break;
		case 16: //Lite Prison Lock
				priProgress[player] = 3;										//Set progress
				light(3, 7);														//Make 3 lights solid
				light(4, 7);														//As player locks balls, lights go from Pulse to Solid
				light(5, 7);
				blink(6);														//Blink "Prison Lock"
				playSFX(0, 'P', '3', random(3) + 65, 255);						//Play 1 of 3 audio clips	
				video('P', '3', 'A', allowSmall, 0, 255);						//Run video	
			break;
		case 17: //Lite extra ball?
			extraBallLight(1);
			break;	
		}
		
	spiritGuide[player]	= 255;					//Flag that Spirit Guide needs to be re-lit
	
}

void spiritGuideEnable(unsigned char enableYesNo) {

	spiritGuideActive = enableYesNo;			//Set incoming state

	showScoopLights();							//Scoop lights will show updated state

}

void spiritGuideLight() {

	if (spiritGuide[player]	== 255) {						//Needs to be re-lit?
		spiritGuide[player]	= 1;							//Set Spirit Guide as active
		if (spiritGuideActive) {							//Can we hit Spirit Guide?
			pulse(46);
      GIbgSet(6, 1);                              //Set the BG Crystal Ball light
			videoQ('S', 'P', 'Z', allowSmall, 0, 10);		//Spirit Guide LIT!				
		}
		else {
			light(46, 0);
			videoQ('S', 'P', 'Y', allowSmall, 0, 10);		//Spirit Guide ready after mode ENDS
		}	
	}	

}

void spookCheck() {								//See what the Spook Again light should be doing

	if (drainTimer or tiltFlag) {				//First, see if game is drained or tilted.
		if (extraBalls) {						//If extra ball active, leave the light solid
			light(56, 7);
		}
		else {
			light(56, 0);						//Otherwise turn it off (either ball save = 0 or you tilted)
		}
	}
	else {										//Not in a tilt/drain condition? We either have ball save, extra ball lit or nothing lit
	
		if (extraBalls) {						//An extra ball?
			if (saveTimer > cycleSecond2) {				//If save time is active, keep blinking it until save timer is over
				blink(56);
			}
			else {
				light(56, 7);					//No more save timer? Light SPOOK AGAIN solid (this code will get called when Save Timer finishes)
			}		
		}
		else {
			if (saveTimer <= cycleSecond2) {		//Save timer either done or just about done?
				light(56, 0);					//Turn it off
			}	
			else {
				blink(56);						//Else it's still active so blink
			}	
		}
	
	}

}

void StartGame(unsigned char loadOrNot) {								//Resets all variables, player progress, sets up initial lights

	animatePF(0, 0, 0);							//Kill attract mode animations

	switchDead = 0;								//Reset dead counter
	searchAttempts = 0;							//Reset try counter
	chaseBall = 0;
	
	menuAbortFlag = 0;							//In case user tries to enter a menu during a game
	Enable();									//Allow solenoids
	videoPriority(0);							//Reset video priority	
	killNumbers();								//Clear all numbers
	setGhostModeRGB(0, 0, 0);					//Set ghost to off
  killScoreNumbers();
  
  killCustomScore();          //In case we did a restart from ball launch
  
	ballSearchDebounce(0);						//In case the trap debounce was changed during a ball search
	kickFlag = 0;								//Clear flag, ball kick complete
	drainTries = 0;	

	deadTop = deadTopSeconds * cycleSecond;		//Calculate what this should be every time a game starts
	
	GIpf(B11100000);							//All GI on to start
	GIbg(B00000000);							//Panel add-on and BG lights off
	
	sfxVolume[0] = sfxDefault;
	sfxVolume[1] = sfxDefault;
	volumeSFX(0, sfxVolume[0], sfxVolume[1]);		
	volumeSFX(1, sfxVolume[0], sfxVolume[1]);		
	volumeSFX(2, sfxVolume[0], sfxVolume[1]);	
	
	musicVolume[0] = musicDefault;
	musicVolume[1] = musicDefault;
	volumeSFX(3, musicVolume[0], musicVolume[1]);
  
	repeatMusic(1);								//Set music to repeat
		
	randomSeed(micros());						//Reset randomizer
	allLamp(0);									//Clear the lights

	//Set all game start variables here:
	
	player = 1;
	numPlayers = 1;
	ball = 1;
	
	//SET ALL STARTING LAMPS
	pulse(3);								//PRISON 1 and THEATER 1 are different in production version
	pulse(8);
	pulse(22);
	pulse(26);
	pulse(36);								//PRISON 1 and THEATER 1 are different in production version
	
	pulse(0);									//Wiki, Tech and Psychic pulse
	pulse(1);
	pulse(51);
  
	//Reset all player Progress
	for (int x = 1 ; x < 5 ; x++) {

		popMode[player] = random(2) + 1;		//Starts either 1 = Fort or 2 = Bar (3 = EVP but never starts in that mode)

		if (bitRead(cabinet, LFlip) == 1) {		//Left flipper at start makes it begin with Bar
			popMode[player] = 2;
		}
		if (bitRead(cabinet, RFlip) == 1) {		//Right flipper = fort
			popMode[player] = 1;
		}
		
		if (popMode[player] == 1) {				//Start out Advancing Fort?
			light(20, 0);
			light(21, 0);
			light(22, 0);
			pulse(21);
		}
						
		if (popMode[player] == 2) {				//Start Out Advancing Bar?
			light(20, 0);
			light(21, 0);
			light(22, 0);
			pulse(22);	
		}

		Mode[x] = 0;

		demonMultiplier[x] = 1;				//Default is 1, but you can "earn" multiplier during the game
    
		achieve[x] = 0; //B01111010; //0;                     //Clear achievements
    
		rollOverValue[x] = 2500;            //Starting rollover GLIR value
    
		skillShotComplete[x] = 0;
		photoAdd[x] = 0;                    //Add-on value for the Photo Hunt scores (starts at zero)
    
		playerScore[x] = 0;						//Clear scrores
		SetScore(x);							//Clear them on DMD
		replayPlayer[x] = 0;					//Nobody's gotten a replay yet
		ModeWon[x] = 0;							//Clear the bits of what modes they've won
		subWon[x] = 0;                    //Clear the bits that enable Sub Wizard mode
		modeRestart[x] = B01111110;				//At the start each player gets 1 re-start chance per mode
		tourComplete[x] = B00000000;			//Which tours player has completed	
		
		hosProgress[x] = 0;
		theProgress[x] = 0;
		barProgress[x] = spotProgress;			//Can be changed in settings
		fortProgress[x] = spotProgress;			//Can be changed in settings
		hotProgress[x] = 0;
		priProgress[x] = 0;
		deProgress[x] = 0;
		
		lockCount[x] = 0;						//Reset # of locked Hellavator balls
		spiritProgress[x] = 0;					//If tourney mode, players get awards in sequence
		spiritGuide[x] = 1;						//Spirit guide is always lit to start for each player	
		EVP_Jackpot[x] = 1000000;				//Starts at 1 million
	
		EVP_Total[x] = 0;						//How many EVP's each player has collected
		EVP_EBtarget[x] = EVP_EBsetting;		//Load the setting for how many EVP's each player must get to earn Extra Ball
	
		photosTaken[x] = 0;						//Total photos a player got.
		areaProgress[x] = 0;					//How many mode-advancing shots each player has made
		ghostsDefeated[x] = 0;
    
		photosNeeded[x] = 3;          //The starting # of photos player needs to complete photo hunt mode
    
		photoSecondsStart[x] = 21;				//How many seconds to get a ghost photo
		GLIR[x] = 1;							//At the start of the game, spell GLIR once to light Photo hunt, then twice, 3 times, ect.
		GLIRneeded[x] = 1;						//How many GLIR spells player needs to light PHOTO HUNT
		GLIRlit[x] = 0;							//Zero PHOTO HUNTS lit to start
		
		minion[x] = 1;							//Each player starts with Minion Fight enabled
		minionTarget[x] = 3;					//3 hits for first Minion Battle
		minionHits = 3;							//Reset this
		minionsBeat[x] = 0;						//How many minions you've beaten.
		minionHitProgress[x] = 0;				//No minion damage progress yet

		orb[x] = 0;
		extraLit[x] = 0;						//No extra balls lit
		
		wiki[x] = 0;
		tech[x] = 0;
		psychic[x] = 0;	
		rollOvers[x] = 0;
		
		hellLock[x] = 1;						//Always start with Hell lock enabled		
		storeLamp(x);							//Store the status of every lamp in that player's memory

		hellJackpot[x] = 1000000;				//Starting MB jackpot value
		hitsToLight[x] = 1;						//How many times you have to press "Call" before hellavator moves / lights for lock	(starts with just 1)						

		saveCurrent[x] = saveStart;				//Set each player's Ball Save time to the default to start. Spelling TECH can increase it!
		
		videoMode[x] = 0;						//Video mode not lit to start
    slingCount[x] = 0;
    
	}

	scoreMultiplier = 1;						//This will almost always be 1

	comboTimerStart = comboSeconds * longSecond;//Compute actual timer setting

	minionDamage = 1;							//Default damage
	
	TargetSet(TargetUp);						//Put targets UP by default so we can enagage Minion Battle!
				
	callHits = 0;								  //How many times you've hit Call this ball (resets per player)	

  //playerScore[1] = 2147000000;						//Signed 32 bit rollover testing
  
  //subWon[1] = subWizReady;    //FOR TESTING PURPOSES
  
  //demonMultiplier[1] = 1;       //TEST MODE
	//deProgress[1] = 1;						//TEST DEMON MODE READY TO START
	//blink(13);								    //BLINK LIGHT	
 
  //-----------------------------------
  //tourComplete[1] = B01111000;    //FOR TESTING ONLY. Only missing Doctor Tour. Complete to light SUB WIZ
  
  //-----------------------------------
  
  suppressBurst = 0;
  
	trapDoor = 0;								//Flags if the ball should be trapped or not
	trapTargets = 0;
	
	doorLogic();								//Figure out what to do with the door
	elevatorLogic();							//Can lock balls, Hellavator is Lit		
	targetLogic(1);								//Where the Ghost Targets should be, up or down
	targetReset();								//Reset state of targets
	
	multiTimer = 0;							//Used in attract mode, so clear it just in case
	multiCount = 0;
	
	spiritGuideEnable(1);					//Mode 0, it can always be lit		
	bonusMultiplier = 1;					//Reset multiplier (it's per ball so don't need unique variable per player)		
	modeTimer = 0;	
	HellBall = 0;

	badExit = 0;							//Haven't gone in VUK yet
	tiltCounter = 0;						//Reset to zero
	ghostLook = 0;
	
	sweetJumpBonus = 0;						//Reset score (hitting it adds value)
	sweetJump = 0;							//Reset video/SFX counter
	
	Advance_Enable = 1;						//Game starts with all modes eligible for advancement.
	AutoEnable = 255; 						// 255 /enables everything
	activeBalls = 0;						//Starts at ZERO	

	setCabMode(defaultR, defaultG, defaultB);	//Set the cab mode to default color
	
	comboKill();

	ghostBurst = 1;       //Clear the GhostBurst stuff			
	burstReady = 0;       //If rollover hit, set this flag to 1. Next score will be X ghostBurst!
	burstLane = 0;        //Which lane is lit for GHOST BURST

	dirtyPoolMode(1);						//Check for Dirty Pool Balls

	Update(0);								//Update with the current info
	
	scoreBall = 0;							//No points scored on this ball as yet
	comboEnable = 1;						//OK combo all you want
	GLIRenable(1);              //This will also light the Spirit Guide and Crystal Ball	
	
	playMusic('L', '1');
	playSFXQ(0, 0, 0, 0, 0);                    //Kils audio queue, in case someone started a new game before the Ending Team Leader Quote (so you don't here it during skill shot)
	playSFX(0, 'A', 'A', '1' + random(4), 255);	//Team leader intro lines

	ballQueue = 0;

  video('K', 'P', '1', 0, 0, 255);		//Team Leader Player 1 stats + static transition
  skillShotNew(1);						//Prep a Skill Shot!	   

  if (loadOrNot) {

    drainSwitch = 59 + ballsInGame; //63;						//Set starting drain switch, just in case    
    loadBall();								//Manually load a ball into shooter lane.		    
  }
  else {
    
    drainSwitch = 59 + 3; //63;	  
  }

  gameRestart = 0;         //If player holds START this increments
	
}

void switchCheck() {						//Check all matrixed switches. Calling "Switch(x)" invokes automatic debounce

	popActive = 0;							//Reset pop detector each cycle

  //We use SwitchPop(x) for pops because it won't count these switch hits against the Ball Search timer (since it can self-trigger)
  
	if (SwitchPop(45)) {						//Bumper 0 hit?
		Coil(Bump0, PopPower);    //Fire bumper solenoid
		popActive += 1;
	}
  
	if (SwitchPop(46)) {						//Bumper 1 hit?
		Coil(Bump1, PopPower);    //Fire bumper solenoid
		popActive += 1;
	}
 
	if (SwitchPop(37)) {						//Bumper 2 hit?
		Coil(Bump2, PopPower);    //Fire bumper solenoid
		popActive += 1;
	}

	if (popActive) {						//Was any pop bumper hit?

		popsTimer = longSecond; //30000;					//Set pops timer so ball doesn't trigger center shot if rolls down there
		popCheck();							//Check the pops!
					
	}	

  popActive = 10;             //Set it to 10 once we're done. We can use this in the Switch() function to ignore false pop hits during ball search
  
	if (Switch(50)) {						//Left sling hit?
		Coil(LSling, SlingPower);
		 slingCount[player] += 1;
		suppressBurst = 1;	   
		if ( slingCount[player] >= orbSlings) {										//Enough to award an ORB letter?
			AddScore(20000);
			 slingCount[player] = 0;
			checkOrbAdd();													//Add a letter		
		}
		else {
			video('O', 'L', 'A' + random(2), allowLarge, 0, 211);			//Sling hits til ORB
      
			if ((orbSlings -  slingCount[player]) > 9) {                       //Ghetto right-justify. This is automatic on my newer kernels :(
				numbersPriority(6, 1, 9, 0, orbSlings -  slingCount[player], 211);		//Send numbers of Sling Hits left, and it will only display on videos matching this priority	         
			}
			else {
				numbersPriority(6, 1, 21, 0, orbSlings -  slingCount[player], 211);          
			}
							
			//playSFX(2, 'C', 'A', 65 + random(14), 99);						//Low priority ghost wail
			playSFX(2, 'C', 'Z', 'L', 99);										//New sound!
			AddScore(5000);
		}
	}	

	if (Switch(53)) {						//Right sling hit?
		Coil(RSling, SlingPower);
		slingCount[player] += 1;
		suppressBurst = 1;	   
		if ( slingCount[player] >= orbSlings) {										//Enough to award an ORB letter?
			AddScore(20000);
			 slingCount[player] = 0;
			checkOrbAdd();													//Add a letter			
		}
		else {
			video('O', 'L', 'C' + random(2), allowLarge, 0, 211);			//Sling hits til ORB    
      
			if ((orbSlings -  slingCount[player]) > 9) {                       //Ghetto right-justify. This is automatic on my newer kernels :(
				numbersPriority(6, 1, 9, 0, orbSlings -  slingCount[player], 211);		//Send numbers of Sling Hits left, and it will only display on videos matching this priority	         
			}
			else {
				numbersPriority(6, 1, 21, 0, orbSlings -  slingCount[player], 211);          
			}		
      
			//playSFX(2, 'C', 'A', 65 + random(14), 99);						//Low priority ghost wail
			playSFX(2, 'C', 'Z', 'R', 99);										//New sound!
			AddScore(5000);
		}
		
	}		

	if (Switch(40)) {						//"O"
		if (skillShot) {			
			if (skillShot == 2) {							//Did we hit the Skill shot?
				skillShotSuccess(1, 0);							//Success!
			}
			else {
				skillShotSuccess(0, 0);								//Failure, so just disable it
			}			
		}		
		orbTimer = cycleSecond2;
    suppressBurst = 1;  
		if (orb[player] & B00100100) {		//Already lit?
			AddScore(10000);
		}
		else {								//Not yet lit?
			AddScore(30000);
			orb[player] |= B00100100;		//Set bits
			checkOrb(1);					//Set lights, with video update
		}	
	}
	if (Switch(41)) {						//"R"
		if (skillShot) {			
			if (skillShot == 2) {							//Did we hit the Skill shot?
				skillShotSuccess(1, 0);							//Success!
			}
			else {
				skillShotSuccess(0, 0);								//Failure, so just disable it
			}			
		}		
		orbTimer = cycleSecond2;
    suppressBurst = 1;    
		if (orb[player] & B00010010) {		//Already lit?
			AddScore(10000);
		}
		else {								//Not yet lit?
			AddScore(30000);
			orb[player] |= B00010010;		//Set bits
			checkOrb(1);						//Set lights
		}	
	}
	if (Switch(42)) {						//"B"
		if (skillShot) {			
			if (skillShot == 2) {							//Did we hit the Skill shot?
				skillShotSuccess(1, 0);							//Success!
			}
			else {
				skillShotSuccess(0, 0);								//Failure, so just disable it
			}			
		}		
		orbTimer = cycleSecond2;
    suppressBurst = 1;
		if (orb[player] & B00001001) {		//Already lit?
			AddScore(10000);
		}
		else {								//Not yet lit?
			AddScore(30000);
			orb[player] |= B00001001;		//Set bits
			checkOrb(1);					//Set lights
		}		
	}	
  
	//playSFX(0, 'F', '1', 'J', 200);								//Negative rollover sound with BEEPS
	//playSFX(0, 'F', '1', 'K', 200);								//Negative rollover sound NO BEEPS	
	 
	if (Switch(48)) {						//Left outlane G?

		playSFX(2, 'F', '1', 'K', 205);		//Always a "bad" sound. Priority will override any "good" completion sound

		rollOvers[player] |= B10001000;		//Add bit
    suppressBurst = 1;
		AddScore(rollOverValue[player]);
    if (burstLane == 52) {             //Was this lane lit for burst? Enable the shot!
      burstLoad();
    }
		checkRoll(1);						//Puts the bit on the lamp and checks if full
	}
	if (Switch(49)) {						//Left inlane? L		
		if (badExit) {						//If BadExit was set, clear it (checks that VUK'd ball rolled down the habitrail)
			badExit = 0;
		}
		if ((rollOvers[player] & B01000100) == 0) {	//Not already lit?
			playSFX(2, 'F', '1', '0', 205);		//Low priority sound
		}
		else {
			playSFX(2, 'F', '1', 'L', 205);		//Rollover when already lit sound FX (reduced version of normal)						
		}		
		rollOvers[player] |= B01000100;				//Add bit
    suppressBurst = 1;
		AddScore(rollOverValue[player]);
    if (burstLane == 53) {             //Was this lane lit for burst? Enable the shot!
      burstLoad();
    }    
		checkRoll(1);						//Puts the bit on the lamp and checks if full
	} 
	if (Switch(54)) {						//Right inlane?	I
		if ((rollOvers[player] & B00100010) == 0) {	//Not already lit?
			playSFX(2, 'F', '1', '0', 205);		//Low priority sound
		}
		else {
			playSFX(2, 'F', '1', 'L', 205);		//Rollover when already lit sound FX (reduced version of normal)						
		}		
		rollOvers[player] |= B00100010;		//Add 
    suppressBurst = 1;
		AddScore(rollOverValue[player]);
    if (burstLane == 54) {             //Was this lane lit for burst? Enable the shot!
      burstLoad();
    }    
		checkRoll(1);						//Puts the bit on the lamp and checks if full
	} 
	if (Switch(55)) {						//Right outlane? R
	
		playSFX(2, 'F', '1', 'K', 205);		//Always a "bad" sound. Priority will override any "good" completion sound

		rollOvers[player] |= B00010001;		//Add bit
    suppressBurst = 1;
		AddScore(rollOverValue[player]);
    if (burstLane == 55) {             //Was this lane lit for burst? Enable the shot!
      burstLoad();
    }    
		checkRoll(1);						//Puts the bit on the lamp and checks if full
	} 

	if (Switch(39)) {						//Left orbit LOWER switch hit?
 		if (skillShot) {					//Going for Skill Shot?			
			skillShotSuccess(0, 255);		//Failure, so disable it		
		} 
		if (LeftOrbitTime == 0) {			//Upper orbit was not hit first?
			LeftOrbitTime = 15000;			//Set timer to indicate upper motion (going UP to Zero)				
		}
	}
	
	if (Switch(38)) {						//Left orbit UPPER switch hit?
 		if (skillShot) {					//Going for Skill Shot?			
			skillShotSuccess(0, 255);		//Failure, so disable it		
		} 	
		if (LeftOrbitTime) {				//If lower target WAS hit first, we count this as a Left Orbit Shot. Prevents event from activating via launch or pop actions
			orbitDelta = (15000 - LeftOrbitTime);       //Grab this number
      orbitDelta /= 5;                           //Divide for lightning effect
      
      LeftOrbitTime = 0;				//Clear it
			comboCheck(0);
			ghostLooking(10);
			leftOrbitLogic();
			//comboSet(0, comboTimerStart);				  //Sets a combo to itself

			if (DoorLocation == DoorOpen) {	        //Can shoot through the door?
				comboSet(1, comboTimerStart);	        //Door VUK set as combo
			}
			else {							                    //If door not open, shoot up middle for combo
				comboSet(2, comboTimerStart);
			}      
      
      if (orbitDelta < 1600) {      //Don't do the effect if it's too slow       
        lightningStart(180000);     //Do the back panel scroll effect  
      }
  
		}
	}

	if (cabSwitch(doorOpto)) {				//Did we hit or go past the Spooky Door?
		switchDead = 0;						//Since it's not a matrix switch, we set this manually	
		doorDo();	
	}

	if (trapDoor == 0) {					//Ball isn't supposed to be trapped behind door? Then check the switch! (This prevents switch from counting during Ball Search)
    
		if (Switch(23) and LeftTimer == 0) {	//ball goes into VUK behind door?		
    
			if (leftVUKlogic() == 1) {			//Call function. If it returns a 1, we are allowed to set a new combo
      
				if (HellLocation == hellDown) {	//Only light the combo if the Hotel	Path is open
					comboSet(3, comboTimerStart);			//Enable a combo at Hotel Path
				}
				else {
					comboSet(4, comboTimerStart);			//Else, Theater Path
				}				
        
			}		
      
		}
    
	}

	if (hosTrapCheck == 1) {
		if (Switch(23) and activeBalls > 1 and LeftTimer == 0) {					//Ball back in VUK, and we still have 2+ balls active?
			activeBalls -= 1;				//Subtract the ball we just caught
			hosTrapCheck = 0;				//Clear the flag
			DoorSet(DoorClosed, 1);			//Close the door and continue as normal			
		}
	}
	
	if (TargetLocation == TargetUp) {		//Are targets fully up and hit-able?	
		
		int targetHit = 0;						//Reset Flag for any Target Hit

		if (Switch(18))	{ 						//Ghost Target 1 hit?
			switchDebounce(19);					//Debounce the other switches so only gets hit at once
			switchDebounce(20);
			targetHit = 1;						//Set flag

			if (minion[player] == 1 and minionsBeat[player] > 2) {	//Can Minion be advanced, and it is Minion 3 or higher?

				targetBits &= ~B00000100;							//Clear that bit
				light(17, 7);										//Turn that light SOLID

				if (gTargets[0] == 0) {								//Haven't hit this one yet?
					minionHits -= 1;								//Used to set incrementing sound
					if (minionHits == 2) {									//Make lights solid to count how many we've hit
						playSFX(2, 'M', 'J', '0', 250);						//Minion target SFX (slightly longer)
						ghostAction = 509998;									//Slight ghost movement	
					}
					if (minionHits == 1) {
						playSFX(2, 'M', 'J', '1', 250);						//Minion target SFX (slightly longer)
						ghostAction = 509998;									//Slight ghost movement	
					}	
					gTargets[0] = 1;								//Set the flag that we already hit this				
					ghostMove(90, 250);								//Ghost only reacts if you HAVEN'T hit that target yet
					AddScore(minionTarget[player] * 10510);			//Increase score
					flashCab(0, 0, 255, 50);						//Brief flash to blue
				}
				else {
					playSFX(1, 'H', '0', '0', 100);				//Clunking sound
					AddScore(1000);									//Nominal points
				}
			
				if (targetBits) {									//Haven't cleared them all yet?				
					killQ();
					video('M', 'I', 64 + targetBits, allowSmall, 0, 210);	//Show which blocks are cleared			
					videoQ('M', 'I', 'G', allowSmall, 0, 100);				//"Clear targets to find minions"
				}
				else {
					minionStart();									//Start the battle!
				}
				
			}

			if (fortProgress[player] == 60 and gTargets[0] == 1) {			//Ghost already hit?
				video('W', 'B', 'H', allowSmall, 0, 255);					//Show ball missing him,
				//videoQ('W', 'A', 64 + soldierUp, allowSmall, 0, 200);		//then back to Soldier View
				playSFX(0, 'W', '9', 'Z', 255);								//Soldier miss noise!
				AddScore(5000);
			}			
			
			if (fortProgress[player] == 60 and gTargets[0] == 0) {			//Are we trying to knock down Ghost Soldiers?
				if (goldHits == 10) {
					ghostAction = 229999;							//Set WHACK routine, turns back towards door
				}
				else {
					ghostAction = 339999;							//Set WHACK routine, turn back towards front			
				}
				
				AddScore(250000);
				soldierUp &= ~B00000100;							//Subtract that soldier
				//playSFX(0, 'W', '9', 'A' + random(16), 255);			//Soldier hit noise! (will be more random later on)
				light(17, 7);										//Turn that light SOLID.
				video('W', 'A', 'H', allowSmall, 0, 255); 					//Show soldier on left knocked down
				gTargets[0] = 1;									//Set the flag that we already hit this
				if (soldierUp == 0) {								//All soldiers down?
					WarFight();
				}
				else {
					playSFX(0, 'W', '9', 'A' + random(16), 255);			//Soldier hit noise!				
					customScore('W', 'A', 64 + soldierUp, allowAll | loopVideo);		//Shoot score with targets in front
					//videoQ('W', 'A', 64 + soldierUp, allowSmall, 0, 200);
				}
			}
				
			if (hotProgress[player] == 30) {								//Are we trying to qualify Hotel Jackpots?

				if (gTargets[0] == 0) {									//Target not hit yet
					playSFX(0, 'L', '8', 'A' + random(8), 255);			//Jackpot multiplier sound + voice
					jackpotMultiplier += 1;				
					video('L', 'M', '0' + jackpotMultiplier, allowSmall, 0, 255);	//Show multiplier		
					//videoQ('L', '8', 'E', allowSmall, 0, 200);						//Ramp re-lights Jackpot					
					light(17, 7);										//Turn that light SOLID.
					gTargets[0] = 1;									//Set the flag that we already hit this
					AddScore(100000);
					sendJackpot(0);										//Send updated jackpot value to score #0
					if (jackpotMultiplier == 3) {								//Jackpot maxed out?
						customScore('L', 'P', 'C', allowAll | loopVideo);		//Change prompt to only mention Ramp (no more point hitting ghost)
					}
				}
				else {
					playSFX(0, 'L', 'W', 'A' + random(8), 255);			//Oh noes!				
					video('L', '8', 'A', allowSmall, 0, 240);			//Ghost worried!
					//videoQ('L', '8', 'E', allowSmall, 0, 200);			//Ramp re-lights Jackpot					
					AddScore(10000);					
				}
			}
			
			if (priProgress[player] > 9 and priProgress[player] < 13) {			//Are we freeing our friends from Ghost Prison?

				ghostFlash(100);
				targetBits &= ~B00000100;									//Clear that bit
				light(17, 7);												//Turn that light SOLID
								
				if (targetBits) {											//Haven't cleared them all yet?				
					if (gTargets[0] == 1) {
						AddScore(10);										//Pwned
						playSFX(2, 'H', '0', '0', 100);						//CLUNK!	
					}
					else {
						AddScore(50070);										//Increase score
						gTargets[0] = 1;										//Set the flag that we already hit this						
						playSFX(2, 'P', '5', 'U' + random(3), 200);				//Random chain whack sound
						
						video('P', 'A', 'Y', 0, 0, 255);			//Flash transition					
						customScore('P', '5', 64 + (targetBits & B00000111), allowSmall | loopVideo);		//Shoot score with targets in front
		
					}					
				}
				else {
					PrisonRelease();										//Release a friend
				}
				modeTimer = 0;	//Reset timer so ghost prompt doesn't override audio

			}	

			if (barProgress[player] == 70) {		//Trying to free our friend from Ghost Whore?				
				BarTarget(0);
			}			
	
		}	

		if (Switch(19)) {						//Ghost Target 2 hit?
			switchDebounce(18);					//Debounce the other switches so only gets hit at once
			switchDebounce(20);
			targetHit = 1;						//Set flag

			if (minion[player] == 1 and minionsBeat[player] > 2) {			//Can Minion be advanced?

				targetBits &= ~B00000010;							//Clear that bit
				light(18, 7);										//Turn that light OFF
				
				if (gTargets[1] == 0) {								//Haven't hit this one yet?
					minionHits -= 1;								//Used to set incrementing sound
					if (minionHits == 2) {									//Make lights solid to count how many we've hit
						playSFX(2, 'M', 'J', '0', 250);						//Minion target SFX (slightly longer)
						ghostAction = 509998;									//Slight ghost movement	
					}
					if (minionHits == 1) {
						playSFX(2, 'M', 'J', '1', 250);						//Minion target SFX (slightly longer)
						ghostAction = 509998;									//Slight ghost movement	
					}	
					gTargets[1] = 1;								//Set the flag that we already hit this				
					ghostMove(90, 250);								//Ghost only reacts if you HAVEN'T hit that target yet
					AddScore(minionTarget[player] * 10510);				//Increase score
					flashCab(0, 0, 255, 50);						//Brief flash to blue
				}
				else {
					playSFX(1, 'H', '0', '0', 100);				//Clunking sound
				}				
				
				if (targetBits) {									//Haven't cleared them all yet?				
					killQ();
					video('M', 'I', 64 + targetBits, allowSmall, 0, 210);	//Show which blocks are cleared			
					videoQ('M', 'I', 'G', 2, 0, 100);				//"Clear targets to find minions"
				}
				else {
					minionStart();									//Start the battle!
				}
				
			}			

			if (fortProgress[player] == 60 and gTargets[1] == 1) {			//Ghost already hit?
				video('W', 'B', 'I', allowSmall, 0, 255);							//Show ball missing him,
				//videoQ('W', 'A', 64 + soldierUp, 2, 0, 200);					//then back to Soldier View
				playSFX(0, 'W', '9', 'Z', 255);								//Soldier miss noise!
				AddScore(5000);
			}			
			
			if (fortProgress[player] == 60 and gTargets[1] == 0) {			//Are we trying to knock down Ghost Soldiers?
				if (goldHits == 10) {
					ghostAction = 229999;							//Set WHACK routine, turns back towards door
				}
				else {
					ghostAction = 339999;							//Set WHACK routine, turn back towards front			
				}
				AddScore(250000);
				soldierUp &= ~B00000010;							//Subtract that soldier
				//playSFX(0, 'W', '9', 'A' + random(16), 255);			//Soldier hit noise!
				light(18, 7);										//Turn that light SOLID.	
				video('W', 'A', 'I', allowSmall, 0, 255); 					//Show soldier in middle knocked down
				gTargets[1] = 1;									//Set the flag that we already hit this
				if (soldierUp == 0) {
					WarFight();
				}
				else {
					playSFX(0, 'W', '9', 'A' + random(16), 255);			//Soldier hit noise!				
					customScore('W', 'A', 64 + soldierUp, allowAll | loopVideo);		//Shoot score with targets in front
					//videoQ('W', 'A', 64 + soldierUp, allowSmall, 0, 200);
				}
			}

			if (hotProgress[player] == 30) {			//Are we trying to qualify Hotel Jackpots?

				if (gTargets[1] == 0) {									//Target not hit yet
					playSFX(0, 'L', '8', 'A' + random(8), 255);			//Jackpot multiplier sound + voice
					jackpotMultiplier += 1;				
					video('L', 'M', '0' + jackpotMultiplier, allowSmall, 0, 255);	//Show multiplier
					//videoQ('L', '8', 'E', allowSmall, 0, 200);						//Ramp re-lights Jackpot					
					light(18, 7);										//Turn that light SOLID.
					gTargets[1] = 1;									//Set the flag that we already hit this
					AddScore(100000);
					sendJackpot(0);										//Send updated jackpot value to score #0
					if (jackpotMultiplier == 3) {								//Jackpot maxed out?
						customScore('L', 'P', 'C', allowAll | loopVideo);		//Change prompt to only mention Ramp (no more point hitting ghost)
					}					
				}
				else {
					playSFX(0, 'L', 'W', 'A' + random(8), 255);			//Oh noes!				
					video('L', '8', 'A', allowSmall, 0, 240);					//Ghost worried!
					//videoQ('L', '8', 'E', allowSmall, 0, 200);						//Ramp re-lights Jackpot					
					AddScore(10000);					
				}
			}

			if (priProgress[player] > 9 and priProgress[player] < 13) {			//Freeing friends from prison?

				ghostFlash(100);			
				targetBits &= ~B00000010;									//Clear that bit
				light(18, 7);												//Turn that light SOLID

				if (targetBits) {											//Haven't cleared them all yet?				
					if (gTargets[1] == 1) {
						AddScore(10);										//Pwned
						playSFX(2, 'H', '0', '0', 100);						//CLUNK!	
					}
					else {
						AddScore(50070);										//Increase score
						//video('P', '5', 64 + (targetBits & B00000111), allowSmall | loopVideo, 0, 200);			//Show which blocks are cleared	
						playSFX(2, 'P', '5', 'U' + random(3), 200);				//Random chain whack sound	
						gTargets[1] = 1;										//Set the flag that we already hit this	
						video('P', 'A', 'Y', 0, 0, 255);			//Flash transition
						customScore('P', '5', 64 + (targetBits & B00000111), allowSmall | loopVideo);		//Shoot score with targets in front
											
					}					
				}
				else {
					PrisonRelease();										//Release a friend
				}
				
				modeTimer = 0;	//Reset timer so ghost prompt doesn't override audio

			}

			if (barProgress[player] == 70) {		//Trying to free our friend from Ghost Whore?				
				BarTarget(1);
			}	
			
		}
			
		if (Switch(20)) {						//Ghost Target 3 hit?
			switchDebounce(18);					//Debounce the other switches so only gets hit at once
			switchDebounce(19);
			targetHit = 1;						//Set flag

			if (minion[player] == 1 and minionsBeat[player] > 2) {			//Can Minion be advanced?

				targetBits &= ~B00000001;							//Clear that bit
				light(19, 7);										//Turn that light OFF
				
				if (gTargets[2] == 0) {								//Haven't hit this one yet?
					minionHits -= 1;								//Used to set incrementing sound
					if (minionHits == 2) {									//Make lights solid to count how many we've hit
						playSFX(2, 'M', 'J', '0', 250);						//Minion target SFX (slightly longer)
						ghostAction = 509998;									//Slight ghost movement	
					}
					if (minionHits == 1) {
						playSFX(2, 'M', 'J', '1', 250);						//Minion target SFX (slightly longer)
						ghostAction = 509998;									//Slight ghost movement	
					}	
					gTargets[2] = 1;								//Set the flag that we already hit this				
					ghostMove(90, 250);								//Ghost only reacts if you HAVEN'T hit that target yet
					AddScore(minionTarget[player] * 10510);			//Increase score
					flashCab(0, 0, 255, 50);						//Brief flash to blue
				}
				else {
					playSFX(1, 'H', '0', '0', 100);				//Clunking sound
				}	
				
				if (targetBits) {									//Haven't cleared them all yet?				
					killQ();
					video('M', 'I', 64 + targetBits, allowSmall, 0, 210);	//Show which blocks are cleared			
					videoQ('M', 'I', 'G', allowSmall, 0, 100);				//"Clear targets to find minions"
				}
				else {
					minionStart();									//Start the battle!
				}
				
			}	

			if (fortProgress[player] == 60 and gTargets[2] == 1) {			//Ghost already hit?
				video('W', 'B', 'J', allowSmall, 0, 255);							//Show ball missing him,
				//videoQ('W', 'A', 64 + soldierUp, allowSmall, 0, 200);				//then back to Soldier View
				playSFX(0, 'W', '9', 'Z', 255);								//Soldier miss noise!
				AddScore(5000);
			}			
			
			if (fortProgress[player] == 60 and gTargets[2] == 0) {			//Are we trying to knock down Ghost Soldiers?
				if (goldHits == 10) {
					ghostAction = 229999;							//Set WHACK routine, turns back towards door
				}
				else {
					ghostAction = 339999;							//Set WHACK routine, turn back towards front			
				}
				AddScore(250000);
				soldierUp &= ~B00000001;							//Subtract that soldier
				//playSFX(0, 'W', '9', 'A' + random(16), 255);			//Soldier hit noise!
				light(19, 7);										//Turn that light SOLID.
				video('W', 'A', 'J', allowSmall, 0, 255); 					//Show soldier on right knocked down
				gTargets[2] = 1;									//Set the flag that we already hit this
				if (soldierUp == 0) {
					WarFight();
				}
				else {
					playSFX(0, 'W', '9', 'A' + random(16), 255);			//Soldier hit noise!
					customScore('W', 'A', 64 + soldierUp, allowAll | loopVideo);		//Shoot score with targets in front		
					//videoQ('W', 'A', 64 + soldierUp, allowSmall, 0, 200);
				}
			}
			
			if (hotProgress[player] == 30) {							//Are we trying to qualify Hotel Jackpots?

				if (gTargets[2] == 0) {									//Target not hit yet
					playSFX(0, 'L', '8', 'A' + random(8), 255);			//Jackpot multiplier sound + voice
					jackpotMultiplier += 1;				
					video('L', 'M', '0' + jackpotMultiplier, allowSmall, 0, 255);	//Show multiplier
					//videoQ('L', '8', 'E', allowSmall, 0, 200);						//Ramp re-lights Jackpot					
					light(19, 7);										//Turn that light SOLID.
					gTargets[2] = 1;									//Set the flag that we already hit this
					AddScore(100000);
					sendJackpot(0);										//Send updated jackpot value to score #0
					if (jackpotMultiplier == 3) {								//Jackpot maxed out?
						customScore('L', 'P', 'C', allowAll | loopVideo);		//Change prompt to only mention Ramp (no more point hitting ghost)
					}					
				}
				else {
					playSFX(0, 'L', 'W', 'A' + random(8), 255);			//Oh noes!				
					video('L', '8', 'A', allowSmall, 0, 240);			//Ghost worried!
					//videoQ('L', '8', 'E', allowSmall, 0, 200);						//Ramp re-lights Jackpot					
					AddScore(10000);					
				}
			}

			if (priProgress[player] > 9 and priProgress[player] < 13) {			//Are we trying to Free Friends from Prison?

				ghostFlash(100);
				targetBits &= ~B00000001;									//Clear that bit
				light(19, 7);												//Turn that light SOLID
				
				if (targetBits) {											//Haven't cleared them all yet?				
					if (gTargets[2] == 1) {
						AddScore(10);										//Pwned
						playSFX(2, 'H', '0', '0', 100);						//CLUNK!	
					}
					else {
						AddScore(50070);										//Increase score
						//video('P', '5', 64 + (targetBits & B00000111), allowSmall | loopVideo, 0, 200);			//Show which blocks are cleared	
						playSFX(2, 'P', '5', 'U' + random(3), 200);				//Random chain whack sound	
						gTargets[2] = 1;										//Set the flag that we already hit this
						video('P', 'A', 'Y', 0, 0, 255);			//Flash transition
						customScore('P', '5', 64 + (targetBits & B00000111), allowSmall | loopVideo);		//Shoot score with targets in front						
					}					
				}
				else {
					PrisonRelease();										//Release a friend
				}
				
				modeTimer = 0;												//Reset timer so ghost prompt doesn't override audio

			}

			if (barProgress[player] == 70) {		//Trying to free our friend from Ghost Whore?				
				BarTarget(2);
			}	
			
		}

		if (targetHit) {						//Any of the 3 targets hit?
                                          //Some modes don't require you to be specific									
      if (Mode[player] == 8) {
        
        if (bumpHits == 10) {
          playSFX(2, 'J', 'R', 'D', 255);	  //Ghost radar sound
          video('J', '0', '4', 0, 0, 255);              
          animatePF(280 + (bumpWhich * 30), 30, 0);    //Show the ghost spot, briefly                     
        }
        else {                              //If fighting a ghost, pauses the VALUE DECREMENT
          stopVideo(0);                     //Stop a video, if playing, to draw attention to the Score Display
          playSFX(1, 'J', 'R', 'E', 255);	  //Freeze beep timer. Events that SHOULD interrupt it (like a good shot) will go over it on Channel 1
          modeTimer = cycleSecond3;         //Freeze time a bit     
          setCabMode(0, 255, 255);          //Change color to TEAL while timer stopped
          
          if (bumpValue > 9999999) {              //Position different if 7 or 8 digits
            numbers(10, numberFlash | 2, 12, 7, bumpValue);					         //Current value                  
          }
          else {
            numbers(10, numberFlash | 2, 14, 7, bumpValue);					         //Current value       
          }
          
        }
    
      }
                    
			if (minion[player] == 1 and minionsBeat[player] < 3) {	//First 3 minions, hit any target 3 times to reveal
				minionHits -= 1;
				
				flashCab(0, 0, 255, 50);						//Brief flash to blue
					
				if (minionHits > 0) {										//Haven't made 3 hits yet?
					AddScore(10000);					
					video('M', 'H', '0' + minionHits, allowSmall, 0, 210);	//Show how many hits we need to find minion
									
					if (minionHits == 2) {									//Make lights solid to count how many we've hit
						//pulse(17);										//Apparently this was confusing, so just keep pulsing them I guess?
						//pulse(18);
						//light(19, 7);
						playSFX(2, 'M', 'I', '0', 250);						//Minion target SFX
					}
					if (minionHits == 1) {
						//pulse(17);
						//light(18, 7);
						//light(19, 7);
						playSFX(2, 'M', 'I', '1', 250);						//Minion target SFX
					}		
					ghostAction = 509998;									//Slight ghost movement					
				}
				else {
					light(17, 7);
					light(18, 7);
					light(19, 7);
					minionStart();				
				}			
			}
												
			if (hotProgress[player] == 20) {	//Looking for control box?
				modeTimer = 0;											//Hit ghost for random taunt
				playSFX(0, 'L', '5', 'A' + random(22), 200);				//Will not override advance dialog
				video('L', '5', 'A', allowSmall, 0, 100);						//Will not override video				
				AddScore(10000);
			}
												
			if (Mode[player] == 1) {			//Are we distracting Ghost Doctor? If so, we don't care which switch was hit.
				HospitalSwitchCheck();
			}	
			
			if (theProgress[player] > 9 and theProgress[player] < 100) {		//Doing the Theater Ghost play?
				countSeconds += 5;								//Increase 5 seconds
				modeTimer = 40000;								//Reset seconds countdown timer
				playSFX(0, 'T', '0', 'A' + random(8), 250);		//Will not override advance dialog				
				if (countSeconds > TheaterTime) {
					countSeconds = TheaterTime;
					video('T', '4', 'F', allowSmall, 0, 255);				//Ghost talking TIMER MAXED OUT					
				}
				else {
					video('T', '4', 'G', allowSmall, 0, 255);				//Ghost talking TIMER ADD 5 SECONDS
				}
				numbers(0, numberStay | 4, 0, 0, countSeconds - 1);			//Update numbers station
				shotValue = (10000 * countSeconds) + 500000;				//Recalculate shot value
				numbers(9, 2, 70, 27, shotValue);							//Update Shot Value				
				
				AddScore(10000);
				sweetJumpBonus = 0;								//BUT it resets your Sweet Jumps meter!
				sweetJump = 0;
			}

			if (minionMB == 10) {				//Ball trapped there for Minion Multiball?
				minionMBjackpot(0);				//Score jackpot, release ball
				cabDebounce[ghostOpto] = 10000;	//Temporarily set it higher so ball behind targets won't re-trigger opto when it bounces up
			}

			if (deProgress[player] == 10) {									//Haven't weakened the demon yet?
				playSFX(0, 'D', 'Z', 'A' + random(15), 255);				//Prompt that we can't hit demon yet
				video('D', 'D', 'I', noExitFlush, 0, 255);					//Shoot flashing shots!
				DemonState();		
			}		
		}
	}	
	
	if (cabSwitch(ghostOpto) and MagnetTimer == 0 and TargetLocation == TargetDown) {	//GHOST HIT? (the loop)

		ghostLoopCheck();					//Check in another function so we can do return aborts
		
	}

	
	if (Switch(34)) {						//Ball heading towards Pops / Jump Fail?

		if (skillShot) {					//We'll count this as a Pop Skill shot, if somehow ball slipped through the pops (unlikely, but possible)			
			if (skillShot == 1) {			//Did we hit the Skill shot?
				skillShotSuccess(1, 0);			//Success!
			}
			else {
				skillShotSuccess(0, 255);				//Failure, so just disable it
			}			
		}	
	
		if (centerTimer == 0 and popsTimer == 0) {	//Wasn't a weak shot up the middle, or just came down from the Pops?

			centerTimer = longSecond;						//Set timer. This prevents roll-backs, or Pop Values overriding what center shot triggered

			if (rampTimer == 0) {							//Not a jump fail? Normal switch actions below:

				comboCheck(2);								  //Check combo
				centerPathCheck();							//See what to do. Defaults to hopefully satisfying lighting sound + FX
				//comboSet(2, comboTimerStart); //Old
        if (HellLocation == hellDown) {	//Only light the combo if the Hotel	Path is open
					comboSet(3, comboTimerStart);			//Enable a combo at Hotel Path
				}
				else {
					comboSet(4, comboTimerStart);			//Else, Theater Path
				}		
			}
			else {											//Did a jump fail?
				//PERSON FALLING + SCREAM
				video('T', '9', 'Z', allowSmall, 0, 200);	//Kaminski falling
				if (theProgress[player] < 10) {				//Haven't started theater?
					playSFX(0, 'T', 'J', random(9) + 65, 240);
				}
				else {										//Fall but no theater prompt
					playSFX(0, 'T', 'H', random(9) + 65, 240);
				}
				rampTimer = 0;								//Reset timer		
			}
		}

	}

	if (Switch(29))	{						//Hellavator Call Button Pressed?

		//See if we can press it first
		if (hotProgress[player] != 3) {															//Hotel Mode not ready to start?
			callHits += 1;																		//Increment # of call hits
		}
		if (callHits == hitsToLight[player] or multiBall > 0) {									//Did we hit it enough, or is Multiball active?
			callHits -= 1;																		//Decrement this so future hits will do this same action
			callButtonLogic();																	//Move hellavator, if we can			
		}
		else {
			if (hotProgress[player] != 3) {
				AddScore(10000);
				video('Q', 'P', '0' + (hitsToLight[player] - callHits), allowSmall, 0, 240);		//Pushing button in vain, how many hits are left		
				playSFX(2, 'Q', 'P', '0' + (hitsToLight[player] - callHits), 200);						//Sound effect to match
			}
			else {
				AddScore(10000);
				playSFX(2, 'H', '0', '0', 100);				//Door clunking sound
			}
		}

	}
		
	if (Switch(28)) {						//Ball up Hotel path?
	
		if (hotelPathLogic()) {				                //Function says we can set a combo?
			if (DoorLocation == DoorOpen) {	            //Can shoot through the door?
				comboSet(random(3), comboTimerStart);	    //Either left orbit, Door VUK or up center as combo
			}
			else {							                        //If not, left orbit 0 or center shot 2
				comboSet(random(2) * 2, comboTimerStart);
			}
		}		
	}

	if (Switch(43)) {						//Is there a ball in the Hellavator?
		ballElevatorLogic();
	}
	
	if (Switch(33) and orbTimer == 0) {		//Ball Heading towards balcony, and didn't just roll down from ORB rollovers?

		if (rampTimer == 0) {								//Ball didn't roll back down from ramp?

			rampTimer = 16000;								//About 1.5 second before the time out			
			ghostLooking(165);	
			
			balconyApproach();	
		}
		else {
			playSFX(1, 'T', '9', 'V', 200);					//Run abort sound
			video('T', '9', 'V', allowSmall, 0, 200);		//Run abort animation
		}		
		
	}	

	if (Switch(32)) {						//Balcony Jump Success?

		balconyJump();

		rampTimer = 0;						//Reset ramp timer.
		//comboSet(4, comboTimerStart);					//Balcony jump always lights itself, no matter what mode
		
    if (HellLocation == hellDown) {
      comboSet(3, comboTimerStart);			//Enable a combo at Hotel Path if open
    }
    else {
      comboSet(2, comboTimerStart);			//Else, up the middle (never combo to same)
    }   
        
	}

	if (Switch(subUpper)) {					//Ball down upper Subway? (from rear entry)

		if (skillShot) {			
			if (skillShot == 3) {														//Did we hit the Skill shot?
				skillShotSuccess(1, 0);													//Success!
			}
			else {
				skillShotSuccess(0, 255);												//Failure, show message (high priority)
			}			
		}		
	
		if (ghostLook == 1) {				//Ghost "watches" ball go down subway	
			ghostLooking(165);
		}

		if (Advance_Enable and priProgress[player] > 3 and priProgress[player] < 7) {	//We've hit the left orbit a 4th time and are ready to lock ball?
			PrisonAdvance2();		
		}
		
		Tunnel = 2;
		
	}
	
	if (Switch(subLower)) {					//Ball down lower Subway? (from elevator)

		if (HellBall == 10) {				//Came from Hellavator?
			ballExitElevatorLogic();		//Do logic for that
		}

		if (Tunnel != 2) {					//Unless it came from upper entry...
			Tunnel = 1;						//Set flag so scoop will just kick, not advance.
		}
		
	}
	
	if (Switch(22) and ScoopTime == 0) {	//Basement scoop hit, and not waiting for a ball eject?

		ScoopTime = 9010;					//The default. Can be changed by the following:
	
		if (Tunnel == 1)	{			 	//Did ball get to the tunnel from the Hellavator?
		
			if (hellMB == 1) {
				ScoopTime = 32500;			//Sync to music and stuff. Re-test on the real, metal subway at Chuck's			
			}

			if (theProgress[player] == 11) {	//If ball rolled down from hellavator, remove that Skip Event
			 skip = 0;
			}
			
			if (hotProgress[player] == 15) { //Did we just start Control Box Search?
				ScoopTime = 80000;			 //Kick it out, after a longer delay
				hotProgress[player] = 20;	 //Set flag that ball is out and can find Control Boxes!
				skip = 55;					//Set skip event for ball scoop eject
			}
			if (deProgress[player] == 8) {	//Ready to start DEMON BATTLE?
				DemonStart();
			}

		}
		
		if (Tunnel == 2) {					//Ball came down from rear? (not hellavator)
			if (Advance_Enable and priProgress[player] > 4 and priProgress[player] < 7) {	//First 2 locks?
				if (priProgress[player] == 6) {	//Second ball lock has shorted speech
					ScoopTime = 80000;				
				}
				else {
					ScoopTime = 85000;				
				}
			}
			if (priProgress[player] == 9) {	//Did we lock the third ball down through upper Basement subway?
				ScoopTime = 130000;			//Delay for storytelling
				skip = 60;					//Allow a skip once the ball is in position
			}		
		}
		
		if (Tunnel == 0) {					//Was ball just shot right into Basement?		
			ghostLooking(120);
			scoopDo();		
		}
		
	}

	if (Switch(63)) {						//Ball in drain?

		drainClear();
	
		/*
		if (coinDoorDetect) {										//Do we care if door is open or not?
			if (coinDoorState == 0) {								//Door must be closed for drain to register
				Drain(0);											//Drain the ball
			}
		}
		else {														//We don't care about the door, so drain the ball!
			Drain(0);												//Drain the ball		
		}
		*/
	}

	if (Switch(drainSwitch)) {				//Ball on Ball Switch 4, and we're in an active game state?	
		
		if (kickFlag) {												//Ball got her via a drain kick?
			kickFlag = 0;											//Clear flag, ball kick complete
			drainTries = 0;											//Reset the kick power increase
		}
		else {														//kTimer not active? It must have bounced in!			
			if (drainTimer == 0 and plungeTimer == 0) {				//Not a drain or an autosave?
				Drain(1);											//Drain with flag to NOT do a drain kick				
			}		
		}	
	}
	
	if (Switch(16)) {						//Wiki target?		
		if (wiki[player] < 255) {			//Hasn't been completed yet?
			wiki[player] += 1;				//Increment counter
		}
		else {
			AddScore(5000);											//Some points for hitting inert target
			playSFX(2, 'H', '0', '0', 250);							//REJECT sound
			video('S', 'W', 'F', allowSmall, 0, 255);				//VIDEO THAT SAYS COMPLETE REST TO RE-LITE WIKI
		}
		if (wiki[player] < 4) {										//Not spelled yet?
			video('S', 'W', 64 + wiki[player], allowSmall, 0, 250);  //Advance letters
			playSFX(2, 'S', 'A', 'X', 250);							//Normal WIKI sound
			AddScore(25000);			
		}
		if (wiki[player] == 4) {
			minionDamage += 1;										//Increase the damage Minion will take, this ball only
			if (minionDamage > 5) {									//Top off at 5
				minionDamage = 5;				
			}
			AddScore(100000);		
			video('S', 'W', 'D', 0, 0, 255);						//WIKI completed!
			videoQ('S', 'W', 'E' + minionDamage, 0, 0, 238);		//Show 2-5x Minion Damage (it will never be lower than 2 here)
			
			playSFX(0, 'S', 'B', 'X', 255);							//WIKI Research complete sound
			wiki[player] = 255;										//Set TECH to complete (must complete all 3 light restart / re-light)
			light(0, 7);											//Light WIKI solid			
			spiritGuideLight();										//If it needs to be re-lit, re-lite it
		}	
	}
	if (Switch(17)) {						//Tech  Target?			
		if (tech[player] < 255) {			//Hasn't been completed yet?
			tech[player] += 1;				//Increment counter
		}
		else {
			AddScore(5000);											//Some points for hitting inert target
			playSFX(2, 'H', '0', '0', 250);							//REJECT sound
			video('S', 'T', 'F', allowSmall, 0, 255);				//VIDEO THAT SAYS COMPLETE REST TO RE-LITE TECH
		}
		if (tech[player] < 4) {										//Not spelled yet?
			video('S', 'T', 64 + tech[player], allowSmall, 0, 250);
			playSFX(2, 'S', 'A', 'Y', 250);							//Normal TECH sound
			AddScore(25000);			
		}
		if (tech[player] == 4) {
			AddScore(200000);		
			video('S', 'T', 64 + tech[player], allowSmall, 0, 255);	//TECH complete, Overclocked!
			playSFX(0, 'S', 'B', 'Y', 255);							//OVERCLOCKED sound
			tech[player] = 255;										//Set TECH to complete (must complete all 3 light restart / re-light)
			light(1, 7);											//Light tech solid	
			saveCurrent[player] += 2;								//Add 2 seconds to this player's Ball Save timer			
			spiritGuideLight();										//If it needs to be re-lit, re-lite it
		}	
	}
	if (Switch(30)) {						//Psychic Target?
	
		playSFX(2, 'S', 'A', 'Z', 250);
		if (psychic[player] < 255) {									//Can be advanced?
			psychic[player] += 1;		
		}
		else {			
			if (scoringTimer) {											//Double scoring active?
				video('S', 'P', 'I', allowSmall, 0, 255);				//Scoring TIME EXTEND
				playSFX(2, 'E', '3', 'A' + random(3), 250);				//DOUBLE SCORING time extension prompt
				scoringTimer += (3 * longSecond);						//Add about 3 seconds
				AddScore(10000);										//Some points for hitting inert target
			}
			else {
				AddScore(5000);											//Some points for hitting inert target
				playSFX(2, 'H', '0', '0', 250);							//REJECT sound
				video('S', 'P', 'L', allowSmall, 0, 255);				//VIDEO THAT SAYS COMPLETE REST TO RE-LITE PSYCHIC	
			}
		}
		
		if (psychic[player] < 7) {									//Not spelled yet?
			video('S', 'P', 64 + psychic[player], allowSmall, 0, 250);
			playSFX(2, 'S', 'A', 'Z', 250);							
			AddScore(25000);													
		}
		if (psychic[player] == 7) {									//Psychic Spelled?
			video('S', 'P', 'G', allowSmall, 0, 255);				//Video for it
			playSFX(2, 'E', '1', 'A' + random(3), 250);				//DOUBLE SCORING prompt
			scoringTimer = 20 * longSecond;							//Set double scoring timer
			scoreMultiplier = 2;									//Double scoring!
			animatePF(119, 30, 1);									//Psychic Scoring light animation (loops)
			AddScore(200000);										//Double points for spelling the longer word		
			psychic[player] = 255;									//Reset counter
			blink(51);												//Blink the Psychic light
			spiritGuideLight();										//If it needs to be re-lit, re-lite it
		}		
	}

	if (Switch(57)) {						//Ball back on the shooter lane?
		if (run == 3 and plungeTimer == 0) {					//The ball has started? Check conditions
			if (skillShot > 0) {								//Did it fall back after shitty skill shot attempt? Give player greif!
				//Serial.println("SKILL FAIL RUN=2");
        
				run = 2;										//Reset condition
 
				if (launchCounter > 1) {						//A couple failed attempts?				
					if (numPlayers == 1) {							//In single player games, do not indicate Player #
						playSFX(0, 'S', 'H', '0' + random(8), 255);	//Give player shit
					}
					else {											//Multiplayer, show which player is up and has the skill shot
						playSFX(0, 'S', 'I', '0' + random(8), 255);	//Give player shit
					}
					launchCounter = 0;
				}				
			}
			else {												//Ball was launched, it bounced back here somehow. Kick it out!
				//Serial.println("On shooter lane during game KICK (Run=3)");
				Coil(Plunger, plungerStrength);
			}
		}
	}

	switchDead += 1;

	if (switchDead > deadTop) {				//No switch has been hit in a while?						
		switchDeadCheck();
	}
		
}

void switchDeadCheck() {

	if (coinDoorDetect and bitRead(cabinet, Door) == 0) {		//Do we care if door is open, and is it open?
		switchDead = 0;											//Reset timer
		return;													//No ball search with door open
	}

	if (skip or MagnetTimer) {           //If a skippable event is current (like a ghost talking) or the magnet is holding the ball, don't do ball search over it
		switchDead = 0;											//Reset timer   
		return;    
	}

	//Magnet gets turned on for Dirty Pool check when targets go back up
	//This causes the search to terminate
	//To fix, do NOT do a Dirty Pool check on target up if switchDead > deadTop
	
	if (bitRead(cabinet, LFlip) == 0 and bitRead(cabinet, RFlip) == 0 and ballSearchEnable == 1 and bitRead(switches[7], 1) == 0) { //We're not cradling the ball, and the ball isn't sitting in the shooter lane? Do a ball search!
	
		if (switchDead == deadTop + 1) {
			Serial.print("Searching.");
			Coil(Bump2, 8); //PopPower);
			if (trapTargets == 0 or tiltFlag) {   //If we're holding a ball behind the targets, don't fully drop them during ball search (Tilt overrides this)
				if (TargetLocation == TargetUp) {		//Targets up?
					TargetSet(TargetDown);				//Put targets directly down
					TargetTimerSet(12000, TargetUp, 10);//After a second, put them back up
				}
				else {
					TargetSet(TargetJog);				//Put targets up partially
					TargetTimerSet(8000, TargetDown, 10); //And back down quickly
				}					
			}
			else {
				TargetSet(TargetJog);					//Put targets down partially
				TargetTimerSet(8000, TargetUp, 10);		//After a second, put them back up										
			}
			
			if (HellLocation == hellUp) {
				hellCheck = 10;					//Set state 1
				ElevatorSet(hellDown, 100);
			}
			if (HellLocation == hellDown) {
				hellCheck = 20;					//Set state 2
				ElevatorSet(hellUp, 100);
			}			
		}		
		if (switchDead == deadTop + (searchTimer)) {
			Serial.print(".");
			Coil(Bump2, 8); //PopPower);
			if (trapDoor == 0) {							//Don't kick this if a ball is SUPPOSED to be trapped behind door
				Coil(LeftVUK, vukPower);
			}	
			else {
				if (hosProgress[player] > 5 and hosProgress[player] < 9 and hosTrapCheck == 0) {	//Ball trapped for Hospital Mode?
					Coil(LeftVUK, vukPower);
					activeBalls += 1;										//Add the ball we just kicked out back to the Active Ball count
					LeftTimer = 0;											//A little bit of a gap
					swDebounce[23] = 500;									//Manually set the debounce
					hosTrapCheck = 1;										//Hospital ball search mode
				}
			}
		}	 
		if (switchDead == deadTop + (searchTimer * 2)) {
			Serial.print(".");
			Coil(Bump2, 8); //PopPower);
			Coil(ScoopKick, scoopPower);

			if (DoorLocation == DoorOpen) {
				doorCheck = 20;					//Set state 1
				DoorSet(DoorClosed, 500);
			}
			if (DoorLocation == DoorClosed) {
				doorCheck = 10;					//Set state 2
				DoorSet(DoorOpen, 1);
			}			
			
		}			
		if (switchDead == deadTop + (searchTimer * 3)) {
			Serial.print(".");
			Coil(Bump2, 8); //PopPower);
			Coil(drainKick, 5); //drainStrength);
		}	   
		if (switchDead == deadTop + (searchTimer * 4)) {
			Serial.print(".");
			Coil(Bump0, 10); //PopPower);	//Do pops lower so they don't self-trigger		
		}
		if (switchDead == deadTop + (searchTimer * 5)) {
			Serial.print(".");
			Coil(Bump1, 10); //PopPower);		
		}
		if (switchDead == deadTop + (searchTimer * 6)) {
			Serial.print(".");
			Coil(Bump2, 10); //PopPower);	
		}      
		if (switchDead == deadTop + (searchTimer * 7)) {
			Serial.print(".");
			Coil(Bump0, 15); //PopPower);	//Do pops lower so they don't self-trigger		
		}
		if (switchDead == deadTop + (searchTimer * 8)) {
			Serial.print(".");
			Coil(Bump1, 15); //PopPower);		
		}
		if (switchDead == deadTop + (searchTimer * 9)) {
			Serial.print(".");
			Coil(Bump2, 15); //PopPower);	
		}
		if (switchDead == deadTop + (searchTimer * 25)) {			//Still nothing?
			Serial.print(".");
			if (chaseBall == 10) {									//Did we send a chase ball, it drained, and we STILL had to do a ball search?
				switchDead = 0;
        creditDot = 1;                        //Ball must be stuck GOOD, so set credit dot
				Drain(1);											        //Do a drain and bounce out of this routine
				return;
			}
		
			searchAttempts += 1;									          //Increment attempts
			
			Serial.print(" attempt #");
			Serial.print(searchAttempts, DEC);			
			Serial.println(" FAILED");

			if (run == 0) {											            //Trying to start a game?
				switchDead = 0;
				return;
			}
			else {
				if (searchAttempts == sendChase) {						//Reached search limit?
					searchAttempts = 0;									        //Reset attempts
					switchDead = 0;										          //Reset switch timer
					if (countBalls() > 0 and chaseBall == 0 and tournament == 0 and tiltFlag == 0) {	//At least 1 ball in trough, and chase ball not already sent? And not in tournament mode (per Hilton)
						Serial.println("Sending CHASE BALL");
          	video('A', 'S', 'A', 0, 0, 255);			        //Sending chase ball
						chaseBall = 1;
						AutoPlunge(autoPlungeFast);						    //Send another ball (and more paramedics)
					}				
				}
				else {
					switchDead = deadTop - cycleSecond2;				  //Reset timer so it'll restart a little quicker
				}			
			}
			
		}		
	}
	else {
		switchDead = 0;											//Ball isn't actually trapped, reset timer
	}

}

void TargetSet(unsigned char dTarget) {			//Puts the Target Bank to a specified position

	if (dTarget == TargetUp) {
		dirtyPoolCheck();
	}
	TargetLocation = dTarget;
	myservo[Targets].write(TargetLocation);

}

void TargetTimerSet(unsigned long dDelay, unsigned char dTarget, unsigned long dSpeed) {

	TargetSpeed = 0;													//Clear this flag so we don't move until after delay
	TargetDelay = dDelay;												//How long before Targets start to move
	TargetTarget = dTarget;												//Where to move to.	
	TargetNewSpeed = dSpeed;											//What the speed will be when we start	

	TargetTimer = 0;													//Reset cycle timer

  if (magEnglish and TargetTarget == TargetUp) {  //If english added to ball, better wait a BIT longer before putting up targets
    TargetDelay += 2000;     
  }
  
}

void targetLogic(unsigned char resetMinion) {

	//showGameStatus();				//For debugging

	if (videoMode[player] > 0 and Advance_Enable and Mode[player] == 0) {					//Video mode is available, and we're not in a mode?
		videoModeLite();
		return;		
	}

	if (hosProgress[player] > 5 and hosProgress[player] < 9) {		//Friend trapped behind door?
		TargetSet(TargetUp);										//Keep targets UP		
		return;
	}

	if (hosProgress[player] == 90) {								//Bashing Dr. Ghost? (not paging him)
		TargetSet(TargetDown);										//Keep targets DOWN		
		return;
	}	
	
	if (barProgress[player] == 60 or barProgress[player] == 80) {	//Ghost waiting for your embrace, or Bashing Ghost Whore Multiball?
		TargetSet(TargetDown);										//Put targets down, so player can restart Ghost Whore
		return;
	}
	
	if (barProgress[player] == 70) {								//Ghost Whore has your friend trapped still?
		dirtyPoolMode(0);											//Don't check for Dirty Pool
		TargetSet(TargetUp);										//Keep targets UP
		return;
	}

	if (fortProgress[player] == 60) {								//Fighting the Army Ghost Soldiers?
		TargetSet(TargetUp);										//Targets should be UP
		return;
	}

	if (fortProgress[player] > 69 and fortProgress[player] < 100) {	//Fighting the Army Ghost Himself?
		TargetSet(TargetDown);										//Make sure targets are down so we can hit him
		return;
	}
			
	if (minionMB > 9) {												//Doing a Minion MB?
		return;														//Do nothing
	}
	if (minion[player] > 9) {										//Was fighting a minion during Photo Hunt?
		return;	
	}

	TargetSet(TargetUp);											//Default is TARGETS UP
	
	if (resetMinion) {
		pulse(17);														//Ghost targets strobe for MINION BATTLE!
		pulse(18);
		pulse(19);
		light(16, 0);													//Turn off Jackpot by default
		minionEnd(1);													//The default is to enable the Minion Battle	
	}
		
}

void targetReset() {

	targetsHit = 0;													//We've hit no targets
	targetBits = B00000111;											//Set targets as NOT HIT
	gTargets[0] = 0;												//Set G Targets to NOT HIT
	gTargets[1] = 0;
	gTargets[2] = 0;

}

void Timers() {									//Check all game function timers.

	//SwitchLogic();								//Debounce timers and stuff

	if (drainTimer) {							//Are we in a drain?
		drainTimer -= 1;		
		DrainLogic();
		ballClear();							//Make sure locks are clear
	}
	else {										//Normal function
		if (HellSpeed) {							//Is the elevator supposed to be moving?
			MoveElevator();			//Do routine.
		}	
		if (TargetSpeed) {							//Is the target supposed to be moving?
			MoveTarget();
		}
		if (DoorSpeed) {							//Is the door supposed to be moving?
			MoveDoor();				//Do routine.
		}	
	}

	if (plungeTimer) {														//Auto-plunge in progress?

		plungeTimer -= 1;													//Decrement counter

		if (plungeTimer == 25001 and bitRead(switches[7], 3) == 0) {		//At first event point, but ball not ready to be loaded?				
			//Serial.println("BALL NOT READY");
			plungeTimer += 10000;											//Give it more time to roll in place
		}
		
		if (plungeTimer == 25000) {											//Second event point. A ball must have been in the load position to get here
			//Serial.print("LOAD BALL: ");
			Coil(LoadCoil, loadStrength);									//Try to load ball from trough
			skip = 0;
		}
		
		if (plungeTimer > 5001 and plungeTimer < 25000) {					//At any point after the ball load?
			if (bitRead(switches[7], 1) == 1) {								//As soon as the ball hits the switch...
				//Serial.println("LOAD GOOD");
				activeBalls += 1;											//...Set a new ball as officially active! If you swat it away before autoplunge, doesn't matter
				
				drainSwitch -= 1;											//Advance which switch drains the ball
				
				//Serial.print("-Drain Switch = ");
				//Serial.println(drainSwitch, DEC);
				
				if (run == 1) {												//Start of game or new ball?
					run = 2;
					//spookCheck();											//Save timer won't be started until Skill Shot collected. Thus spookCheck won't give proper result
					blink(56);												//A new game/ball will always have a ball save, so blink it manually here												
					launchCounter = 0;
					plungeTimer = 0;										//Don't autoplunge it
					//Serial.println("Start-of-Ball Load Complete");
				}
				else {
					plungeTimer = 5000;										//Set plunge point. This gives ball a 4000 cycle delay to "settle"				
				}
			}
		}
					
		if (plungeTimer == 5001) {											//Ready to "take the plunge?" Make sure ball is there...
			if (bitRead(switches[7], 1) == 0) {								//Ball isn't there?
				//Serial.println("LOAD FAIL - RETRY");
				plungeTimer = 25001;										//Reset timer to try and re-load ball from trough
			}
		}
		
		if (plungeTimer == 1000 and bitRead(switches[7], 1) == 1) {			//At second event point, and a ball is there to launch?
			//Serial.println("Auto-plunging NOW");
			Coil(Plunger, plungerStrength);
		}
	

		if (plungeTimer == 0 and ballQueue and countBalls() > 0) {				//Was another autolaunched ball queued during previous launch? (somehow?)
			ballQueue -= 1;
			AutoPlunge(autoPlungeFast + 5000);											//Launch another fairly quickly
		}
		
	}

	if (LeftOrbitTime) {
		LeftOrbitTime -= 1;
	}

	if (ScoopTime) {
		ScoopTime -= 1;

		if (drainTimer == 0) {						//Flash before the ball shoots out
		
			switch(ScoopTime) {
				
				case 9000:
					skip = 0;							//If you were waiting on something, the wait is over!
					playSFX(2, 'S', 'G', 'V', 100);
					GIword |= (1 << 4);
					light(43, 0);
					light(44, 0);
					light(45, 0);
					light(46, 0);
					light(47, 7);				
				break;
				case 8000:
					GIword &= ~(1 << 4);
				break;
				case 7000:
					playSFX(2, 'S', 'G', 'W', 100);
					GIword |= (1 << 4);		
					light(46, 7);				
				break;
				case 6000:
					GIword &= ~(1 << 4);
				break;				
				case 5000:
					playSFX(2, 'S', 'G', 'X', 100);
					GIword |= (1 << 4);	
					light(45, 7);				
				break;
				case 4000:
					GIword &= ~(1 << 4);
				break;
				case 3000:
					playSFX(2, 'S', 'G', 'Y', 100);
					GIword |= (1 << 4);
					light(44, 7);				
				break;				
				case 2000:
					GIword &= ~(1 << 4);
				break;	
				case 1500:
					animatePF(240, 10, 0);					//Scoop explode animation		
				break;
				case 1000:
					playSFX(2, 'S', 'G', 'Z', 100);
					GIword |= (1 << 4);
					light(43, 7);				
				break;				
				case 1:
					GIword &= ~(1 << 4);		
					showScoopLights();					//Restore the lights				
				break;					
			}
		}
		
		if (ScoopTime == 1000) {					//Scoop timer just about done? We check it at 1000 so the kick post can't retrigger the scoop

			if (hellMB == 1) {
				hellMB = 10;						//Set flag that music / mode has begun!
				volumeSFX(3, musicVolume[0], musicVolume[1]);	//Back to normal
				playMusic('M', 'B');				//The multiball music!	
				playSFX(0, 'Q', 'D', 'A' + random(4), 255);		//Leader prompts what to do
				multipleBalls = 1;					//When MB starts, you get ballSave amount of time to loose balls and get them back
				ballSave();							//That is, Ball Save only times out, it isn't disabled via the first ball lost							
			}
			if (priProgress[player] == 9) {
				priProgress[player] = 10;	 		//Set mode as started
				modeTimer = 0;				 		//Reset timer
			}
		
			if (fortProgress[player] == 59) {		//We don't blink these lights until player gets the ball, so they notice them more I guess?
				fortProgress[player] = 60;
				blink(17);									//Blink the targets for the Soldier.
				blink(18);
				blink(19);			
			}

      if (deProgress[player] == 9) {      //Is Demon Battle starting?
        playMusic('D', 'Z');						//Until we get final music ready
      }
      
			Coil(ScoopKick, scoopPower);					//Kick out ball	
			
			if (Tunnel) {
				Tunnel = 0;							//Clear flag, if set
			}
			if (spiritGuide[player] > 99 and spiritGuide[player] < 200) {			//Are we supposed to award Spirit Guide thing?
				spiritGuideAward();
			}

      if (scoopSaveWhen) {                                //Scoop save isn't set to ALWAYS trigger? Do a check...
      
        if (multiBall == 0 and multipleBalls == 0) {      //Only allow the scoop save timer if a multiple ISN'T active (which granted is most of the time)  
          //Serial.println("SCOOP SAVE OVERRIDE");
          ballSaveScoop();								                //Grace period in case ball goes down drain    
        }
        
      }
      else {
          ballSaveScoop();								//Grace period in case ball goes down drain
        
      }

		}
		
	}
	
	if (MagnetTimer) {							//Ghost Magnet enabled?

		MagnetCount += 1;							//Increment PWM timer
		
		if (MagnetCount > magPWM) {					//End of cycle?
			MagnetCount = 0;				 		//Reset PWM counter
			MagnetTimer -= 1;						//Decrement main timer.
						
			//Only do logic when a magnet cycle completes

			if (theProgress[player] == 50 or fortProgress[player] == 99) {		
				switchDead = 0;							//Prevent a ball search while mode is ending and ball is being held			
			}
			
			if (MagnetTimer == 40) {						//Check mode ending status
      
				if (minion[player] == 11) {
					magFlag = 0;						      //Clear the flag so magnet is no longer pulsed (but timing stays the same)							
					minionEnd(1);						      //End the mode, with flag to advance Minion Hits				
				}	
				if (fortProgress[player] == 99) {		//Ending War mode?
					WarOver();							      //Finish the mode	
				}			
				if (theProgress[player] == 50) {		//Ending theater mode?			
					TheaterOver();						    //Finish the mode				
				}			
			
			}
			
			if (MagnetTimer == 31) {					  //Just about done?
				if (minion[player] != 11) {
					magFlag = 0;						      //Clear the flag so magnet is no longer pulsed (but timing stays the same)
					swDebounce[24] = 5000;				//Manually enable the ghost switch debounce so if we hit them with our job, won't reactivate				
				}       
			}	

			if (Mode[player] == 4) {           						 //War fort? This is the only time we English the ball manually at power 3 (and override normal settings)
				if (MagnetTimer == 5) {                             //The stronger the pull, the longer we should wait before triggering
					cabDebounce[ghostOpto] = cycleSecond;			//Make sure it doesn't re-trigger opto   
					Coil(Magnet, 210);         
				} 
			}
			else {          
				if (magEnglish) {                 					//Flag to add some spin on release?         
				  if (MagnetTimer == (25 - (magEnglish * 5))) { 	//The stronger the pull, the longer we should wait before triggering
          cabDebounce[ghostOpto] = 6000;			//See if this is enough.... Else use a multipler over a base * magEnglish
					Coil(Magnet, magEnglish * 70); 					
				  }         
				}                
			}

			if (SolTimer[Magnet] == 0) {			//Magnet not on?
				Coil(Magnet, magFlag);				  //Pulse the magnet for magFlag MS (if magFlag set)
			}
    
		}
		
	}

	if (orbTimer) {
		orbTimer -= 1;
	}

	if (LeftTimer) {
		LeftTimer -= 1;
		
		if (drainTimer == 0) {
			if (LeftTimer == 6000) {
				light(40, 7);
			}
			if (LeftTimer == 5000) {
				light(40, 0);
			}		
			if (LeftTimer == 4000) {
				light(40, 7);
			}
			if (LeftTimer == 3000) {
				light(40, 0);
			}	
			if (LeftTimer == 2000) {
				light(40, 7);
			}
			if (LeftTimer == 1000) {
				light(40, 0);
			}	
		}
		
		if (LeftTimer == 1000) {
			switchDebounce(23);					//Set the debounce just in case
			Coil(LeftVUK, vukPower);        //Kick it out!
			skip = 0;
      playSFX(2, 'O', 'L', 'W', 240); //Left VUK eject sound
			
			if (hosProgress[player] == 90) {	//Just started Doctor Ghost Battle?
				hosProgress[player] = 10;		//Ball is kicked, officially started!
			}
		}
	}

	if (rampTimer) {
		rampTimer -= 1;
	}

	if (centerTimer) {
		centerTimer -= 1;
	}

	if (popsTimer) {
		popsTimer -= 1;
	}
	
	if (TargetDelay) {							//Target set to move after a delay?
	
		TargetDelay -= 1;						//Decrement
		
		if (loopCatch == checkBall) {			//Trying to catch the ball?		
			if (TargetDelay == 300) {											//Almost ready to check?
				MagnetSet(100);													//Pulse magnet again
			}
			if (TargetDelay < 1) {												//Timed out? Ball must not be there. Bummer.
				magFlag = 0;													//Clear the pulse flag
				TargetTimerSet(1, TargetDown, 2);								//Keep targets down so you can re-trap
				loopCatch = catchBall;											//Reset state, we still need to catch the ball	
				killQ();														//Disable any Enqueued videos	
				video('D', 'Z', 'A', allowSmall, 0, 255); 						//Speed Demon Bonus!
				showValue(100000, 40, 1);										//It's a combo value * Ghosts defeated because why not?	
				playSFX(2, 'D', 'Z', 'X', 255);									//Vrooom! Just like a Mustang!				
			}			
			if (TargetDelay < 300 and bitRead(cabinet, ghostOpto)) {			//After second pulse, we consider a ball in opto to be a good catch
				MagnetSet(100);													//Pulse it again to make sure it stays there while targets are going up
				TargetDelay = 0;												//Clear this just in case
				TargetSpeed = TargetNewSpeed;									//Allow targets to move up	
				cabDebounce[ghostOpto] = 10000;									//Make sure it doesn't re-trigger opto				
				loopCatch = ballCaught;											//External logic will take it from here. Allow targets to go up
			}			
		}
		else {
			if (TargetDelay < 1) {					//Ready to move targets?
				TargetSpeed = TargetNewSpeed;		//Set Speed flag to start targets moving	
				TargetDelay = 0;					//Clear this just in case
			}			
		}
	}

	if (loadChecker) {							//Did we just try to load a ball?
	
		loadChecker -= 1;
		
		if (loadChecker == 1) {					//Timer just about done?
			if (bitRead(switches[7], 1) == 0) {	//Did ball not load into shooter lane properly?				
				//Serial.println("LOAD FAIL, RE-TRYING...");
				loadBall();						//Try and re-load it.
			}
		}		
	}

	if (saveTimer and popsTimer == 0 and kickTimer == 0) {		//Save timer doesn't decrement during pops action or when a ball is being kicked from drain
		saveTimer -= 1;
		
		if (saveTimer == cycleSecond2 or saveTimer == (cycleSecond2 - 10) or saveTimer < 10) {		//Light turns off about TWO seconds before it's actually done. Double check near very end as well
			spookCheck();										//Check what to do with the light
		}
	}

	if (modeTimer) {
	
		modeAction();
	
	}

	if (displayTimer) {
	
		displayTimer -= 1;						//Decrement timer
	
		if (displayTimer > 0 and displayTimer < 45000) {				//Flashing ORB win?		

			if (displayTimer == 1) {			//Just about done?
				//orb[player] = 0;				//Clear player's ORB variable so it can be reset
				checkOrb(0);
				displayTimer = 0;
			}
		}
		if (displayTimer > 45000 and displayTimer < 90000) {				//Flashing GLIR spelling?		

			if (displayTimer == 45001) {									//Just about done?
				checkRoll(0);					//See what status the lights should be and set them to that (just in case they changed during the blinking)
				displayTimer = 0;
			}
		}			
	}

	if (ghostFadeTimer) {

		ghostFadeTimer -= 1;
		
		if (ghostFadeTimer == 1) {				//Just about done?
	
			if (ghostRGB[0] > ghostModeRGB[0]) {
				ghostRGB[0] -= 1;					//Decrement values		
			}
			if (ghostRGB[0] < ghostModeRGB[0]) {
				ghostRGB[0] += 1;					//Decrement values		
			}
			if (ghostRGB[1] > ghostModeRGB[1]) {
				ghostRGB[1] -= 1;					//Decrement values		
			}
			if (ghostRGB[1] < ghostModeRGB[1]) {
				ghostRGB[1] += 1;					//Decrement values		
			}
			if (ghostRGB[2] > ghostModeRGB[2]) {
				ghostRGB[2] -= 1;					//Decrement values		
			}
			if (ghostRGB[2] < ghostModeRGB[2]) {
				ghostRGB[2] += 1;					//Decrement values		
			}				
			doRGB();							//Send new RGB
			ghostFadeTimer = ghostFadeAmount;	//Reset timer
		
			if ((ghostRGB[0] == ghostModeRGB[0]) and (ghostRGB[1] == ghostModeRGB[1]) and (ghostRGB[2] == ghostModeRGB[2])) {	//Done?
			
				ghostFadeTimer = 0;
				ghostColor(ghostRGB[0], ghostRGB[1], ghostRGB[2]);
			
			}
		
		}	
	}

	if (RGBtimer) {								//Changing the cabinet lighting?
		RGBtimer -= 1;
		
		if (RGBtimer < 1) {						//Time to change?
			RGBtimer = RGBspeed;				//Reset timer
			int RGBflag = 0;					//Set flag to 0. This checks if all 3 have reached their target (since some might be closer to others when starting)
			for (int x = 0 ; x < 3 ; x++) {		//Make current colors match the target
				if (leftRGB[x] > targetRGB[x]) {
					leftRGB[x] -= 1;
				}
				if (leftRGB[x] < targetRGB[x]) {
					leftRGB[x] += 1;
				}			
				if (leftRGB[x] == targetRGB[x]) {
					RGBflag += 1;				//Did we reach it? Increase flag counter
				}
				rightRGB[x] = leftRGB[x];		//Make both sides the same color
			}
			if (RGBflag == 3) {					//If all 3 reached target, we're done!
				RGBtimer = 0;					//Clear timer to finish mode
			}
			doRGB();
		}
	
	}
	
	if (comboTimer) {
		comboTimer -= 1;
		if (comboTimer == 0) {						//Time's up for Combo?
			if (tourLights[comboShot] == 0) {		//If camera icon isn't still being used for a Tour shot...
				light(photoLights[comboShot], 0);	//Turn off the Combo Shot Lamp			
			}
			if (theProgress[player] == 100) {		//CASE 3: Theater has been completed? Reset Sweet Jumps score counter
				sweetJumpBonus = 0;					//Reset score (hitting it adds value)
				sweetJump = 0;						//Reset video/SFX counter
			}			
			comboCount = 1;							//Reset the count for next time
			comboVideoFlag = 0;						//Clear flag
		}
	}

	if (ghostTimer) {							//Moving the ghost?
	
		ghostTimer -= 1;
		
		if (ghostTimer == 1) {					//Just about done?
			ghostTimer = ghostSpeed;			//Reset timer to speed
			if (GhostLocation > ghostTarget) {
				ghostSet(GhostLocation - 1);
			}
			if (GhostLocation < ghostTarget) {
				ghostSet(GhostLocation + 1);
			}
			if (GhostLocation == ghostTarget) {
				ghostTimer = 0;					//It has arrived, disable movement
			}
		}
		
	}
	
	if (kickTimer) {						//Ball needs kicked from the drain?
		swDebounce[63] = swDBTime[63];			//Keep the debounce on to prevent a re-trigger until it's gone
		kickTimer -= 1;
		
		if (kickTimer == 6000) {				//Ready to kick it?
			Coil(drainKick, drainStrength + drainTries);		//Give it a kick!
			drainTries += 2;					//Increase the power. If the ball hits Switch 4, then it loaded and this is clear. If not, it kicks harder with each re-try
			if (drainTries == 10) {
				drainTries = 0;
			}
		}
		if (kickTimer < drainPWMstart) {		//After the kick, pulse hold the coil a bit...
			kickPulse += 1;
			if (kickPulse > 75) {				//Wait appx 10 ms
				kickPulse = 0;					//Reset timer
				Coil(drainKick, 1);				//Kick for 1 ms
			}
		}
		if (kickTimer == 0) {					//Then turn off the coil
			digitalWrite(SolPin[drainKick], 0); //Make sure it's off
		}
	}		
		
	if (skillShot > 0 and run == 3) {			//This timer lets us sense a half-ass skill shot attempt
		modeTimer += 1;
		
		if (modeTimer > 100000) {				//Keep it from getting too high, like Towlie
			modeTimer = 10000;
		}
	
	}

	if (dirtyPoolTimer) {
		dirtyPoolLogic();
	}

	if (restartTimer) {
		restartTimer -= 1;	
		if (restartTimer == 1) {
			restartSeconds -= 1;
			restartTimer = longSecond;
			if (restartSeconds == 0) {								//Out of time?
				restartKill(restartMode, 0);						//Kill whatever we were trying to restart
			}
			else {
				numbers(0, numberStay | 4, 0, 0, restartSeconds - 1);				//Update the Numbers Timer.	
			}		
		}				
	}
		
	if (lightningTimer) {
		lightningTimer += 1;
		lightningFX(lightningTimer);	
	}

	if (HellSafe) {
		HellSafe -= 1;											//Decrement it
		if (HellSafe == 1 and HellBall == 10) {					//Ball didn't hit the middle Subway switch in time?	
			//Serial.println("BALL MISSING RE-TRYING");			
			hellCheck = 20;										//Set state, which means Go Back to Up, then come back down
			ElevatorSet(hellUp, 100);							//Send hellavator up
			//Set timer to Cycles it will take for hell to go back up + Cycles it'll take to come back down
			HellSafe = ((hellUp - hellDown) * 100) + ((hellUp - hellDown) * 200) + subwayTime;
		}
	}
	
	if (lightStatus) {
	
		animationTimer += 1;
		
		if (animationTimer > animationTarget) {
		
			animationTimer = 0;			
			lightCurrent += 1;

			if (lightCurrent > lightEnd) {
				if (lightStatus & lightLoop) {
					lightCurrent = lightStart;
				}
				else {
					if (scoringTimer) {					//If Psychic scoring is active, we interrupted the animation
						animatePF(119, 30, 1);			//Restart looping Psychic animation
					}
					else {
						lightStatus = 0;
					}				
				}							
			}
		}
	}
	
	if (scoringTimer) {
	
		scoringTimer -= 1;
		
		if (scoringTimer == 50000) {									//Just about done?
			video('S', 'P', 'J', allowSmall, 0, 200);					//Video for it
			playSFX(2, 'E', '2', 'A' + random(3), 200);					//Replace with DOUBLE SCORING hurry-up prompt
		}
		if (scoringTimer == 1) {										//Done?
			scoreMultiplier = 1;										//Multiplier done
			scoringTimer = 0;											//Reset timer
			video('S', 'P', 'K', allowSmall, 0, 200);					//Psychic Scoring OVER!
			playSFX(2, 'E', '4', 'A' + random(3), 200);					//Double Scoring Over prompt
			animatePF(0, 0, 0);											//Kill animations
			light(51, 7);												//Light Psychic solid (done)
		}	

	}
	
}

void tilt() {									//Disable lights / player control, let all balls fail down the drain. Continues when they're all in trough

	//Serial.println("TILT!");

	GIpf(B00000000);							//Turn off GI
		
	AutoEnable = 0;								//Disable flippers
	
	//Make sure flippers are dead!
	leftDebounce = 0;
	LFlipTime = -10;							//Make flipper re-triggerable, with debounce
	LholdTime = 0;								//Disable hold timer.
	digitalWrite(LFlipHigh, 0); 				//Turn off high power
	digitalWrite(LFlipLow, 0);  				//Switch off hold current	
		
	rightDebounce = 0;
	RFlipTime = -10;							//Make flipper re-triggerable, with debounce
	RholdTime = 0;								//Disable hold timer
	digitalWrite(RFlipHigh, 0); 				//Turn off high power
	digitalWrite(RFlipLow, 0);  				//Switch off hold current		

	ScoopTime = 0;								//Clear ball kick timers (we'll do this manually)
	LeftTimer = 0;								//If you tilt with ball in Spirit Guide collect, you won't get the award (since it's awarded once ScoopTime hits 1000 / eject)
	
	video('K', 'Z', 'Z', loopVideo, 0, 255);	//Loop tilt graphic until next ball	
	playSFX(0, 'K', 'B', '0' + random(4), 255);	//Play one of 4 TILT quotes (used to be the warning quotes)
	stopMusic();
	videoPriority(0);							//Erase video priority

	killScoreNumbers();							//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();	
	
	tiltFlag = 1;								//Set flag that we tilted

	plungeTimer = 0;							//Abort any autoplunges
	ballQueue = 0;								//Clear any queued balls for autoplunge
	
	TargetSet(TargetDown);						//Put targets down
  myservo[HellServo].write(hellDown); 		//Hellavator down
  myservo[DoorServo].write(DoorOpen); 		//Open Door
	myservo[GhostServo].write(90); 				//Center Ghost	

  Coil(Magnet, 0);              //Make sure this is off
	
	//ballClear();
	
	//DO A BALL SEARCH HERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	
	activeBalls = 0;							//Set # of active balls to 0, so if tilt during multiball, will still 

	Drain(0);
	
}

//FUNCTIONS FOR THEATER MODE 2............................
void TheaterAdvance(unsigned char showAdvance) {		//Logic to advance Theater Mode 2. If otherModes == 0 then something else is going on, adjust accordingly

	AddScore(advanceScore);
	flashCab(0, 255, 0, 100);					//Flash the GHOST BOSS color
	
	theProgress[player] += 1;
	areaProgress[player] += 1;
	
	if (theProgress[player] < 3) {										//First 3 advances?
		video('T', 48 + theProgress[player], 'A', allowSmall, 0, 255);			//Play first 3 videos, based off how far we are
		playSFX(0, 'T', theProgress[player] + 48, random(4) + 65, 255);
    
    if (showAdvance) {                                           //If other mode not active, change the lights
      for (int x = 0 ; x < theProgress[player] ; x++) {
        light(36 + x, 7);											            //Light all progress, in case we Double Advance
      }		
      pulse(theProgress[player] + 36);								    //Pulse the next one      
        
    }

	}

	//MAKE SURE THIS DOESN'T COLLIDE WITH DOCTOR GHOST MODE START, BECAUSE RIGHT NOW IT COULD
	
	if (theProgress[player] == 3) {									        //Prompt shot for Mode Start.

		playSFX(0, 'T', '3', random(4) + 65, 255);
    
		if (showAdvance) {                    //Not in a mode?
		  light(36, 7);												//Manually set them solid
		  light(37, 7);
		  light(38, 7);
		  pulse(12);													//Blink light 12 for Theater Start	
		  DoorSet(DoorOpen, 250);							//Open the door.
		  
		  if (hosProgress[player] == 3) {			//Had doctor ready?
			light(11, 0);											//Gonna have to wait!	
		  }     
		  video('T', '3', 'A', allowSmall, 0, 255);							//Play first 3 videos, based off how far we are     
		}
		else {
		  video('T', '3', 'Y', allowSmall, 0, 255);							//Need new video same as original + says "Theater Ready After Current Mode Ends"     
		  
		}
  
	}

}

void TheaterStart() {							//What happens when we shoot "Theater Ghost" when lit

	restartKill(2, 1);							//In case we got the Restart
	comboKill();
	storeLamp(player);							//Store the state of the Player's lamps
	allLamp(0);									//Turn off the lamps

	spiritGuideEnable(0);						//No spirit guide during Theater

	hellEnable(0);								//Can't do multiball in this mode
	
	modeTotal = 0;								//Reset mode points	
	AddScore(startScore);

	popLogic(3);								//Set pops to EVP
	minionEnd(0);								//Disable Minion mode, even if it's in progress

	setGhostModeRGB(255, 255, 0);				//Yellow Ghost
	setCabModeFade(0, 255, 0, 100);				//Green cab

	jackpotMultiplier = 1;						//Reset this just in case
	
	if (countGhosts() == 5) {						//Is this the last Boss Ghost to beat?
		blink(48);									//Blink that progress light
	}	
	
	pulse(17);									//Pulse Ghost Targets (they add extra time)
	pulse(18);
	pulse(19);
	pulse(39);									//Jump light
	
	ElevatorSet(hellUp, 300);					//Make sure elevator is UP
	blink(41);
	theProgress[player] = 10;					//Set flag for the mode being started
	Mode[player] = 2;							//Set mode to 2
	Advance_Enable = 0;							//Mode started, disable advancement until we are done
	TargetTimerSet(10, TargetUp, 50);			//Just in case
	
	if (minion[player] == 10) {					//In a minion battle?
		minionEnd(0);							//End mode, with flag to NOT re-enable it
	}	

	DoorSet(DoorClosed, 1);						//Shut door fast!
	light(12, 0);								//Turn off THEATER start mode light
	blink(58);									//Blink the Theater mode light.

	//VOICE CALL, GHOST APPEARS

	video('T', '4', 'A', allowSmall, 0, 255);			//Ghost reveal!
	playSFX(0, 'T', '5', 'A' + random(4), 255);		//Mode start dialog	
	killQ();									//Disable any Enqueued videos
	playMusic('B', '1');						//Boss battle music!	

	sweetJumpBonus = 0;							//Starts at ZERO. Increases with each SWEET JUMP. Resets if you hit the Ghost Targets for more time
	sweetJump = 0;

	modeTimer = 130000;							//Set high so timer doesn't start for an extra second
	countSeconds = TheaterTime;					//How many seconds to get to hit the shot
	numbers(0, numberStay | 4, 0, 0, countSeconds - 1);		//Update the Numbers Timer. We do "-1" so it'll display a zero.
	
	shotValue = (10000 * countSeconds) + 500000;			//Starting shot value 
	
	customScore('T', 'P', 'A', allowAll | loopVideo);		//Shoot Ghost custom score prompt
	numbers(8, numberScore | 2, 0, 0, player);				//Show player's score in upper left corner
	numbers(9, 2, 70, 27, shotValue);						//Shot Value
	numbers(10, 9, 88, 0, 0);								//Ball # upper right	
	
	
	strobe(26, 6);								//Strobe HOTEL LIGHTS - path 1
	strobe(36, 4);								//Strobe JUMP SHOT - combo on camera appearing or going away won't affect it
	
	KickLeft(106000, vukPower);						//Kick back ball
	//KickLeft(90000, vukPower);						//Kick back ball
	showProgress(1, player);					//Show the Main Progress lights
	
	videoModeCheck();
	
	skip = 20;									//Set theater skip mode 1
	
}

void TheaterPlay(unsigned char yesNo) {			//What happens when you shoot the strobing paths

	if (yesNo == 0) {										//Sent with with a flag that this ISN'T the shot we want?
		playSFX(0, 'T', '8', 65 + random(8), 255);			//Ghost gives you shit
		TheaterStrobe();									//Make sure correct shot is LIT
		if (theProgress[player] == 13) {					//Should we prompt to SHOOT GHOST?
			video('T', '4', 'E', allowSmall, 0, 255);		//Ghost upset, prompt to SHOOT GHOST TO FINISH	
		}
		else {
			video('T', '4', 'C', allowSmall, 0, 255);		//Ghost upset, prompt to SHOOT NEXT STROBING	
		}
		return;
	}

	AddScore((10000 * countSeconds) + 500000);		//10k per second left + 250k per correct shot
	countSeconds = TheaterTime;						//Reset timer
	
	shotValue = (10000 * countSeconds) + 500000;			//Reset shot value 
	
	numbers(0, numberStay | 4, 0, 0, countSeconds - 1);		//Update timer
	numbers(9, 2, 70, 27, shotValue);						//Update shot value
	
	if (theProgress[player] == 10) {				//First shot?
		modeTimer = 120000;							//Set high so timer doesn't start for an extra second
		ElevatorSet(hellDown, 550);					//Move elevator down
		light(41, 0);
		video('T', '7', 'A', allowSmall, 0, 255);			//Scene 1
		playSFX(0, 'T', '7', 'A', 255);				//Play dialog 1		
		killQ();									//Disable any Enqueued videos	
		light(26, 0);								//Turn OFF the HOTEL STROBE
		strobe(8, 7);								//Strobe the SPOOKY DOOR shot!
		customScore('T', 'P', 'B', allowAll | loopVideo);		//Shoot DOOR custom score prompt
		theProgress[player] = 11;					//Advance this
		DoorSet(DoorOpen, 500);						//Open door for next shot
		skip = 21;									//Second skip event
		return;
	}
	if (theProgress[player] == 11) {				//Second shot?
		modeTimer = 100000;							//Set high so timer doesn't start for an extra second
		video('T', '7', 'B', allowSmall, 0, 255);			//Scene 1
		playSFX(0, 'T', '7', 'B', 255);				//Play dialog 1		
		killQ();									//Disable any Enqueued videos	
		light(8, 0);								//Turn OFF the SPOOKY DOOR STROBE
		strobe(43, 5);								//Strobe BASEMENT SCOOP path
		customScore('T', 'P', 'C', allowAll | loopVideo);		//Shoot SCOOP custom score prompt
		theProgress[player] = 12;					//Advance this
		KickLeft(76000, vukPower);					//Kick it out slowly
		DoorSet(DoorClosed, 500);					//Close door for next shot
		skip = 22;									//Third skip event
		return;
	}
	if (theProgress[player] == 12) {				//Third shot?
		modeTimer = 80000;							//Set high so timer doesn't start for an extra second
		video('T', '7', 'C', allowSmall, 0, 255);	//Scene 1
		playSFX(0, 'T', '7', 'C', 255);				//Play dialog 1
		killQ();									//Disable any Enqueued videos	
		light(43, 0);								//Turn OFF the SPOOKY DOOR STROBE
		blink(16);									//Blink the GHOST TARGET lights
		blink(17);
		blink(18);
		blink(19);
		customScore('T', 'P', 'D', allowAll | loopVideo);		//Shoot Ghost custom score prompt
		TargetTimerSet(5000, TargetDown, 400);		//Put down the Ghost Targets very slowly		
		theProgress[player] = 13;					//Advance this
		ScoopTime = 62500;							//Kick out scoop, at a slower rate
		skip = 23;									//Fourth skip event
		return;
	}
	
	
}

void TheaterStrobe() {								//Reset whatever light SHOULD be strobing

	strobe(36, 4);								//Strobe JUMP SHOT - combo on camera appearing or going away won't affect it

	switch (theProgress[player]) {

		case 10:
			strobe(26, 6);								//Strobe HOTEL LIGHTS - path 1
		break;	
		case 11:
			strobe(8, 7);
		break;
		case 12:
			strobe(43, 5);
		break;	
		case 13:
			blink(16);									//Blink the GHOST TARGET lights
			blink(17);
			blink(18);
			blink(19);
		break;
	
	}

}

void TheaterWin() {

	loadLamp(player);												//Restore what the lamps were doing before this mode started
	comboKill();
	
	spiritGuideEnable(1);

	ghostModeRGB[0] = 0;
	ghostModeRGB[1] = 0;
	ghostModeRGB[2] = 0;
	ghostFadeTimer = 800;
	ghostFadeAmount = 200;
	setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color
	MagnetSet(1200);												//Catch ball and hold for remaining lines

	light(58, 7);													//Set THEATER LIGHT solid!
	modeTimer = 0;													//Disable timer
	killTimer(0);													//Turn off numbers	

	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();	
	
	light(36, 0);
	light(37, 0);
	light(38, 0);
	light(39, 0);
	light(12, 0);													//Theater Mode Solid!
	AddScore(winScore);

	playSFX(0, 'T', '7', 'D', 255);									//Mode win dialog

	killQ();														//Disable any Enqueued videos	
	video('T', '7', 'D', noExitFlush, 0, 255);						//Mode won, prevent numbers
	numbersPriority(0, numberFlash | 1, 255, 11, modeTotal, 233);	//Load Mode Total Points as Number	
	modeTotal = 0;													//Reset mode points		
	videoQ('T', '7', 'E', noEntryFlush | B00000011, 0, 233);		//Mode Total Video	

	sweetJumpBonus = 0;					//Reset score (hitting it adds value)
	sweetJump = 0;						//Reset video/SFX counter	
	
	playMusic('M', '2');											//Normal music

	theProgress[player] = 50;										//Sets a flag so when MAGNET finishes and releases the ball, it will totally finish the mode

}

void TheaterOver() {

	Mode[player] = 0;												//Set mode active to None
	ModeWon[player] |= 1 << 2;										//Set THEATER WON bit for this player.

	if (countGhosts() == 6) {										//This the final Ghost Boss? Light BOSSES solid!
		light(48, 7);
	}
	
	ghostsDefeated[player] += 1;									//For bonuses
	
	Advance_Enable = 1;												//Allow other modes to be started
	hellEnable(1);
	theProgress[player] = 100;										//Mode done and can't be restarted	

	if (countGhosts() == 2 or countGhosts() == 5) {	//Defeating 2 or 5 ghosts lights EXTRA BALL
	
		extraBallLight(2);							//Light extra ball, no prompt we'll do there
		//videoSFX('S', 'A', 'A', allowSmall, 0, 255, 0, 'A', 'X', 'A' + random(2), 255);	//"Extra Ball is Lit!"			
	
	}	
	
	if (videoMode[player] > 0) {									//Video mode is available?
		videoModeLite();											//Enable it, leave targets down
	}	
	else {
		TargetTimerSet(8000, TargetUp, 100);
		minionEnd(2);												//Re-enable Minion find but do NOT let it control targets since this mode needs to do that		
	}
		
	demonQualify();													//See if Demon Mode is ready
		
	//checkModePost();							//Doing this manually so we can skip the Target Logic (we're handling that!)	

	doorLogic();								//Figure out what to do with the door

	checkRoll(0);								//See if we enabled GLIR Ghost Photo Hunt during that mode

	elevatorLogic();							//Did the mode move the elevator? Re-enable it and lock lights

	//targetLogic(1);								//Where the Ghost Targets should be, up or down

	popLogic(0);								//Figure out what mode the Pops should be in
	
	showProgress(0, player);
	
}

void TheaterFail(unsigned char reasonFail) {

	loadLamp(player);												//Restore what the lamps were doing before this mode started
	comboKill();
	
	spiritGuideEnable(1);

	ghostModeRGB[0] = 0;
	ghostModeRGB[1] = 0;
	ghostModeRGB[2] = 0;
	ghostFadeTimer = 100;
	ghostFadeAmount = 100;
	setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color

	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();	
	
	sweetJumpBonus = 0;					//Reset score (hitting it adds value)
	sweetJump = 0;						//Reset video/SFX counter
	modeTimer = 0;													//Disable timer
	killTimer(0);													//Turn off numbers	

	if (ModeWon[player] & theaterBit) {								//Did we win this mode before?
		light(58, 7);												//Make Theater Mode light solid, since it HAS been won
	}
	else {
		light(58, 0);												//Haven't won it yet, turn it off
	}
	
	if (reasonFail == 0) {											//Fail via drain we pass a 1, and thus, don't do the video or speech

		modeTotal = 0;												//Reset mode points				
		Mode[player] = 0;												//Set mode active to None
		Advance_Enable = 1;												//Allow other modes to be started
		
		checkModePost();
		hellEnable(1);		
				
		if (modeRestart[player] & theaterBit) {							//Able to restart theater?
			modeRestart[player] &= ~theaterBit;							//Clear the restart bit
			playSFX(0, 'T', '9', 65 + random(4), 255);						//A-D fail quotes
			video('T', '4', 'H', allowSmall, 0, 255);					//Mode Fail, Shoot door to Restart		
			DoorSet(DoorOpen, 100);										//Make sure door is open			
			restartBegin(2, 11, 25000);									//Enable a restart! (Mode 2, for 5 seconds, starting timer value)
			theProgress[player] = 3;									//Allows you to re-start the mode
			showProgress(0, player);									//Re-load other stuff
			light(9, 0);		
			light(10, 0);
			light(11, 0);
			strobe(8, 4);												//Strobe lights under door
			playMusic('H', '2');										//Hurry Up Music!
		}
		else {
			light(12, 0);												//Turn off Theater Ghost light
			playSFX(0, 'T', '9', 65 + random(4), 255);						//A-D fail quotes
			video('T', '4', 'D', allowSmall, 0, 255);					//Mode Fail, NO RESTART PROMPT
			theProgress[player] = 0;									//Gotta start over
			pulse(36);													//Reset theater advance lights
			light(37, 0);
			light(38, 0);
			showProgress(0, player);
			playMusic('M', '2');										//Normal music		
		}
	
	}
	else {
		modeTotal = 0;												//Reset mode points				
		Mode[player] = 0;											//Set mode active to None
		Advance_Enable = 1;											//Allow other modes to be started

		if (modeRestart[player] & theaterBit) {							//Able to restart theater?
			modeRestart[player] &= ~theaterBit;							//Clear the restart bit
			theProgress[player] = 3;									//Allows you to re-start the mode
		}
		else {		
			theProgress[player] = 0;
			pulse(36);													//Reset theater advance lights
			light(37, 0);
			light(38, 0);
		}
		showProgress(0, player);
		checkModePost(); 											//Disable for testing
		hellEnable(1);		
	
	}

				//Show the lights
	
	
}
//END FUNCTIONS FOR THEATER MODE 2............................

int tourGuide(unsigned char whichBit, unsigned char whichMode, unsigned char whichLight, int nullPoints, unsigned char nullSound) {

	//Returns:
	//0 = You already got this one
	//1 = You completed this part of the tour!
	//10 = You completed this tour! (4 of 4)
	//99 = You completed ALL tours!

	if (tourBits & (1 << whichBit)) {				//Already hit this one?
		AddScore(nullPoints);						//A few points so shot logic doesn't have to worry about awarding anything
		if (nullSound) {
			playSFX(2, 'A', 'Z', 'Z', 255);			//Generic shot WHOOSH sound		
		}
		return 0;									//Return a null
	}

	//OK so we must not have hit this one yet, proceed:	
	
	light(photoLights[whichLight], 0);				//Turn out that light
	
	tourLights[whichLight] = 0;						//Clear the tour lights for combo protection
	
	tourBits |= (1 << whichBit);					//Set the bit
	tourTotal += 1;									//Increase tour total

	if (tourTotal > 4) {							//Just in case we forget to reset it for a mode
		tourTotal = 4;
	}
	
	//CHANGE TO A SOUND EFFECT!!!
	//playMusicOnce('T', '0' + tourTotal);								//Music for each advance

	if (whichMode == 8) {												//Multiball?
		stopVideo(0);	
		video('C', 'G', 'A' + random(2), noExitFlush, 0, 255); 			//Net catch left or right
		
		if (whichLight != 2) {											//Don't show number video on center shot since pops will override it
			numbers(7, numberFlash | 1, 255, 11, catchValue * 100500);	//Value multiplies every time you clear all 4
			videoQ('C', 'G', 'C', noEntryFlush | B00000011, 0, 255);	//Mode Total:		
		}
		
		AddScore(catchValue * 100500);									//And add it to the score	
		playSFX(0, 'Q', 'C', 'A' + random(5), 250);						//Sound + Heather compliment	
		if (tourTotal == 4) {
			catchValue += 1;
			if (catchValue > 255) {										//Could be possible. You never know.
				catchValue = 1;
			}															//Re-light the shots!
			tourReset(B00111010);										//Tour: Left orbit, door VUK, up middle, right orbit (excludes Hotel and Scoop)
		}
	}
	else {	
		if (tourTotal == 4) {											//Completed this tour?
    
			tourComplete[player] |= 1 << whichMode;						//Set flag that we completed the tour
			playSFX(1, 'A', 'X', 'F', 255);								//Tour complete sound
      
			Serial.println(tourComplete[player], BIN);
      
			if ((tourComplete[player] & B01111110) == B01111010) {      //There is no tour mode for Theater, so the most you can get is 5 (hence the missing 3rd LSB)	
				video('R', '0' + whichMode, 64 + tourTotal, 0, 0, 255);   //Show the correct video
				videoQ('R', '7', 'D', 0, 0, 255);                         //Double scoring for demon mode
        playSFXQ(1, 'D', 'Y', 'A' + random(6), 255);              //Add Multiplier! 
				demonMultiplier[player] += 1;							                //Add multiplier for demon mode
				showValue(10000000, 40, 1);								                //Completing all tours = 10 million        
				return 99;													                      //Completed all tours!
			}
			else {
				video('R', '0' + whichMode, 64 + tourTotal, 0, 0, 210);   //Show the correct video
				showValue(3000000, 40, 1);								                //Completing tour = 3 million
				return 10;												                        //Completed this tours!
			}		
      
		}
		else {
			video('R', '0' + whichMode, 64 + tourTotal, 0, 0, 210); 	//Show the correct video
			playSFX(1, 'A', 'X', 'E', 255);								            //Tour advance sound
			showValue(500000 * tourTotal, 40, 1);						          //500k, 1 mil, 1.5 mil, then 3 million!		
			return 1;													                        //Return that we got 1
		}		
	}
}

void tourReset(unsigned char whichLights) {		//Quickly sets the Tour Lights for a mode

	//photoLights[] = {7, 14, 23, 31, 39, 47};
	unsigned char bitChecker = B00100000;
	
	for (int x = 0 ; x < 6 ; x++) {
		if (whichLights & bitChecker) {
			blink(photoLights[x]);
			tourLights[x] = 1;					//Set that a Tour Light is here
		}
		else {
			tourLights[x] = 0;
		}
		bitChecker >>= 1;	
	}
	
	tourBits = 0;
	tourTotal = 0;
		
}

void tourClear() {								//Gets rid of the Tour Lights (mode end or fail, tilt)

	for (int x = 0 ; x < 6 ; x++) {
		light(photoLights[x], 0);				//Turn off the light
		tourLights[x] = 0;						//Clear the value so it won't interfere with combos / scoop light
	}
	
	tourBits = 0;
	tourTotal = 0;	
	
}

//FUNCTIONS FOR WAR FORT MODE 3............................
void WarAdvance(unsigned char howMany) {

	AddScore(popScore);
	flashCab(0, 255, 0, 10);					//Flash the GHOST BOSS color	
	areaProgress[player] += 1;	
	fortProgress[player] += howMany;
	
	if (fortProgress[player] > 0 and fortProgress[player] < 26) { // and centerTimer == 0) {	

    if (comboVideoFlag and middleWarBar) {                    //If a combo, and using middle to advance, don't flush the bar graphs at start
      video('W', 'A', 'Z', allowBar | allowSmall | preventRestart | noEntryFlush, 0, 250);				//Advance video	
    }
    else {
      video('W', 'A', 'Z', allowBar | allowSmall | preventRestart, 0, 250);				//Advance video	    
    }
  
		video('W', 'A', 'Z', allowBar | allowSmall | preventRestart, 0, 250);				//Advance video	
		showProgressBar(4, 3, 12, 26, fortProgress[player] * 4, 4);
		showProgressBar(5, 10, 12, 27, fortProgress[player] * 4, 2);	
	}
	
	if (fortProgress[player] == 8) {
		playSFX(0, 'W', '1', random(4) + 65, 250); //Advance sound 1				
		return;
	}

	if (fortProgress[player] == 16) {
		playSFX(0, 'W', '2', random(4) + 65, 250); //Advance sound 2					
		return;
	}				
	
	if (fortProgress[player] >= 26) {			//Did we fill the bar? Prompt for Mode Start!
		killQ();
		stopVideo(0);
		video('W', '0', '0', 0, 0, 255);		//Prompt for Army Ghost Lit		
		playSFX(0, 'W', '3', random(4) + 65, 250); //Prompt for Mode Start		
		//centerTimer = 25000;					//Prevents pop bumper jackpot from overiding prompt video
		fortProgress[player] = 50;				//50 indicates Mode is ready to start.				
		popLogic(3);							//EVP pops	
		spiritGuideEnable(0);		
		showScoopLights();						//Update the Scoop Lights
		
		//pulse(44);								//Pulse the ARMY GHOST start light			
		//light(43, 0);							//Turn off PHOTO HUNT start. If eligible, it will light after mode over
		//light(46, 0);							//Turn off SPIRIT GUIDE. If eligible, it will re-light during mode
		return;
	}

	popToggle();	
	//playSFX(0, 'W', 'Z', random(10) + 65, 100);	//Else, play the normal War Advance pop bumper sounds
	stereoSFX(1, 'W', 'Z', random(10) + 65, 100, leftVolume, rightVolume);
	
}

void WarStart() {

	light(44, 0);								//Turn off blinking ARMY GHOST light before storing lamp state
	
	comboKill();	
	storeLamp(player);							//Store the state of the Player's lamps	
	allLamp(0);									//Turn off the lamps
	spiritGuideEnable(1);						//Spirit Guide available during mode. It will turn OFF until you start War Fort, turn ON after you make the shot to start War Fort

	modeTotal = 0;								//Reset mode points		

	AddScore(startScore);							//One mil just for starting.
	
	comboKill();	
	minionEnd(0);								//Disable Minion mode, even if it's in progress

	TargetSet(TargetDown);						//Put them down so we'll notice them come UP
	setGhostModeRGB(255, 0, 255);					//Magenta 
	
	setCabModeFade(0, 255, 0, 200);				//cabinet color GREEN

	popLogic(3);								//Set pops to EVP
	
	tourReset(B00101110);						//Tour: Left orbit, up middle, hotel path, right orbit (excludes Door and Scoop)
												//Door is used for CONFEDERATE GOLD!
												//Scoop = Spirit Guide

	if (countGhosts() == 5) {						//Is this the last Boss Ghost to beat?
		blink(48);									//Blink that progress light
	}												
												
	light(44, 7);								//Turn WAR FORT start light SOLID
	blink(59);									//Blink the Mode Light during battle.
	pulse(14);									//Pulse Door Camera (secret GOLD MODE!)
	
	Advance_Enable = 0;							//Mode started, disable advancement until we are done

	modeTimer = 0;								//We'll use this if player Goes for the Gold!
	goldHits = 0;	
	goldTotal = 0;								//Total Gold score

	Mode[player] = 4;							//War Fort Mode officially started!
	gTargets[0] = 0;							//Reset the 3 Ghost target status
	gTargets[1] = 0;
	gTargets[2] = 0;
	light(17, 0);
	light(18, 0);
	light(19, 0);

	goldTimer = 0;
	modeTimer = 0;
	
	fortProgress[player] = 59;					//Flag to BLINK the soldiers lights upon Scoop Kick. Then it switches to 60, mode begun!
	soldierUp = B00000111;						//Set all soldiers to be up
	warHits = 0;								//How many times we've hit the War ghost
	ghostLook = 1;								//Allow ghost to look around again	
			
	//VOICE CALL, GHOST APPEARS
	int whichIntro = random(3);
	playSFX(0, 'W', '4', whichIntro + 65, 255);	//Mode start dialog
	video('W', '0', whichIntro + 49, allowSmall, 0, 255);//Video that matches

	playMusic('B', '1');						//Boss battle music!

	hellEnable(1);								//You can lock balls and get MB stacked on this mode
	
	doorLogic();								//See what the door should do
	
	TargetTimerSet(85000, TargetUp, 50);		//Bring them up in about 8 seconds
	ScoopTime = 120000;
	
	showProgress(1, player);					//Show the progress, Active Mode style
	
	ghostAction = 320000;
		
	videoModeCheck();	
	
	customScore('W', 'A', 64 + soldierUp, allowAll | loopVideo);		//Shoot score with targets in front
	numbers(8, numberScore | 2, 0, 0, player);							//Show player's score in upper left corner
	numbers(9, 9, 88, 0, 0);											//Ball # upper right
	
	skip = 40;
	
}

void WarFight() {

	playSFX(0, 'W', '6', 'A' + random(3), 255);	//Soldier hit noise + "Defense are down let's get this ghost!"
	modeTimer = 0;								//Reset timer for exorcist quotes
	
	customScore('W', 'C', '0', allowAll | loopVideo);		//Shoot score with targets in front
	numbers(8, numberScore | 2, 0, 0, player);							//Show player's score in upper left corner
	numbers(9, 0, 0, 0, 0);												//Cancel #9
	
	fortProgress[player] = 70;					//Now we are fighting the ghost himself!
	pulse(16);									//Pulse the MAKE CONTACT light
	TargetSet(TargetDown);						//Put down the targets
	winMusicPlay();						//Play annoying Ghost Squad theme!
	
	jackpotMultiplier = 1;						//Reset this just in case	
	
}

void WarLogic() {

	if (ScoopTime == 0) {							//Don't count while the ball is in the scoop

		if (fortProgress[player] == 60) {			//Trying to knock down soldiers?		
			modeTimer += 1;
			
			if (modeTimer == 120000) {
				int x = random(10);
				if (x < 5) {
					playSFX(0, 'W', 'A', '0' + random(10), 200);	//Random team leader prompts
				}
				else {
					playSFX(2, 'L', 'G', '0' + random(8), 200);		//Random lightning	
					lightningStart(50000);		
				}			
				modeTimer = 0;
			}		
		}
		
		if (fortProgress[player] > 69 and fortProgress[player] < 100) {			//Fighting the Army Ghost?		
			modeTimer += 1;
			
			if (modeTimer == 120000) {
				lightningStart(1);			//Do some lightning!
				int x = random(10);
				if (x < 5) {
					playSFX(0, 'W', 'B', '0' + random(10), 100);	//Random team leader prompts
				}
				else {
					playSFX(2, 'L', 'G', '0' + random(8), 100);	//Random lightning	
					lightningStart(50000);	
				}				
			}
			if (modeTimer == 150000) {
				modeTimer = 0;
			}
		}
		
	}
	
}

void WarTrap() {

	ghostLook = 0;
	ghostBored = 0;												//Prevents his look action from happening

	fortProgress[player] += 1;
	
	if (fortProgress[player] == 71) {							//First hit where he throws it back?
		AddScore(EVP_Jackpot[player]);
		light(19, 0);											//Turn off Light 3 - his "health bar"
		int whichBallWhack = random(4);							//Taunts 1-4
		playSFX(0, 'W', '7', whichBallWhack + 65, 255);			//Play SFX
		video('W', '7', whichBallWhack + 65, allowSmall, 0, 255);		//Ghost hit, throws back ball
		customScore('W', 'C', '1', allowAll | loopVideo);		//Shoot score with targets in front
		//videoQ('W', 'B', '1', allowSmall, 0, 200);						//Ghost ready to fight!
		MagnetSet(300);											//Catch ball.			
		ghostFlash(50);
		ghostAction = 100000;								//Set WHACK routine, turn back towards front			
	}
	if (fortProgress[player] == 72) {							//Second hit where he throws it back?
		AddScore(EVP_Jackpot[player]);
		light(18, 0);											//Turn off Light 2 - his "health bar"
		int whichBallWhack = random(4);							//Taunts 5-8
		playSFX(0, 'W', '7', whichBallWhack + 69, 255);			//Play SFX
		video('W', '7', whichBallWhack + 69, allowSmall, 0, 255);		//Ghost hit, throws back ball
		customScore('W', 'C', '2', allowAll | loopVideo);		//Shoot score with targets in front
		//videoQ('W', 'B', '2', allowSmall, 0, 200);
		MagnetSet(300);											//Catch ball.			
		ghostFlash(50);
		ghostAction = 100000;								//Set WHACK routine, turn back towards front     
	}
	if (fortProgress[player] == 73) {									//Third hit?
		if (multiBall & multiballHell) {								//If MB active, give points but don't end mode until second ball is gone
			fortProgress[player] = 72;									  //Make this loop		
			AddScore(EVP_Jackpot[player]);								//You can get a lot more jackpots this way!
			light(18, 0);												          //Turn off Light 2 - his "health bar"
			int whichBallWhack = random(8);								//Taunts 5-8
			playSFX(0, 'W', '7', whichBallWhack + 65, 255);				//Play SFX
			video('W', '7', whichBallWhack + 65, allowSmall, 0, 255);	//Ghost hit, throws back ball
			customScore('W', 'C', 'Z', allowAll | loopVideo);			//Shoot score with targets in front
			sendJackpot(0);												        //Update jackpot value
			numbers(9, numberScore | 2, 72, 27, 0);						//Use Score #0 to display the Jackpot Value bottom off to right
			MagnetSet(300);												        //Catch ball.			
			ghostFlash(50);
			ghostAction = 100000;										        //Set WHACK routine, turn back towards front
		}
		else {															              //If we aren't in a stacked MB, third hit wins mode
			MagnetSet(500);												          //Catch ball.
			WarWin();	
		}
	}			
}

void WarGoldStart() {

	goldHits += 1;							//Increase # of Gold Hits
	
	if (goldHits == 1) {
		video('W', 'G', 'A', allowSmall, 0, 255); 			//2 HITS TO GO	
		playSFX(0, 'W', 'G', 'A' + random(4), 255);
		AddScore(50000);
		DoorLocation = DoorClosed - 10;				//Put it to be slightly opened
		myservo[DoorServo].write(DoorLocation);		//Send that value to the servo
		DoorSet(DoorClosed, 1000);					//Then make it go back closed
		ghostMove(10, 10);							//Ghost looks at door.
		ghostBored = 5000 + random(15000);			//Set bored timer.
	}
	
	if (goldHits == 2) {
		video('W', 'G', 'B', allowSmall, 0, 255); 			//1 HIT TO GO	
		playSFX(0, 'W', 'G', 'E' + random(4), 255);
		AddScore(50000);
		DoorLocation = DoorClosed - 20;				//Put it to be slightly opened
		myservo[DoorServo].write(DoorLocation);		//Send that value to the servo
		DoorSet(DoorClosed, 1000);					//Then make it go back closed
		ghostMove(10, 10);							//Ghost looks at door.
		ghostBored = 5000 + random(15000);			//Set bored timer.		
	}
	
	if (goldHits == 3) {							//Gold Mode Start!
		AddScore(100000);
		goldHits = 10;								//Set flag that we're collecting gold 
		video('W', 'G', 'C', allowSmall, 0, 255); 	//Gold Mode Start!
		playSFX(0, 'W', 'G', 'I' + random(4), 255);	//Mode start dialog	
		DoorSet(DoorOpen, 50);						//Open the door		
		light(14, 0);								//Turn off blinking camera
		strobe(8, 7);								//Strobe the DOOR SHOT		
		countSeconds = GoldTime;					//You've got 20 seconds to get a lot of gold!
		goldTotal = 0;								//Keep track of score
		goldTimer = 30000;							//Seconds countdown timer. Start a little higher to give player a chance
		ghostAction = 206000;						//Guarding door
		numbers(0, numberStay | 4, 0, 0, countSeconds - 1);		//Update display
	}	
		
}

void WarGoldLogic() {

		goldTimer -= 1;
		
		if (goldTimer == 1) {								//Just about done?
			goldTimer = longSecond;								//Reset Mode Timer
			countSeconds -= 1;								//Decrease seconds counter
			
			if (countSeconds) {								//If Not Zero...
				numbers(0, numberStay | 4, 0, 0, countSeconds - 1);		//Update display
				if (countSeconds > 1 and countSeconds < 7) {	//Count down 5 4 3 2 1
					playSFX(2, 'A', 'M', 47 + countSeconds, 1);
				}
				else {
					playSFX(2, 'Y', 'Z', 'Z', 1);				//Beeps
				}
			}
			else {											//Time's up!
				WarGoldEnd();				
			}
		
		}

}

void WarGoldEnd() {

	DoorSet(DoorClosed, 5);						//Close the door
	killTimer(0);								//Turn off timer numbers
	light(8, 0);								//Turn off strobe
	ghostAction = 0;
	
	
	if (goldTotal) {								//Did player collect some?
		video('W', 'G', 'G', allowSmall, 0, 255); 	//Gold Mode Win!
		showValue(goldTotal, 40, 0);				//Flash the total points scored via Gold (don't add it to score since it has been already!)
		playSFX(0, 'W', 'G', 'U' + random(6), 255);	//Mode end dialog		
		goldHits = 100;								//Set flag so mode can't be re-started		
		light(14, 0);								//Camera OFF we're done
	}
	else {
		video('W', 'G', 'H', allowSmall, 0, 255); 			//Gold Mode Fail!
		playSFX(0, 'W', 'G', '4' + random(4), 255);		//Mode end dialog
		goldHits = 0;								//Set flag so mode CAN be re-started!
		blink(14);									//Blink camera for re-start
	}
	
	ghostAction = 319999;
	
}

void WarWin() {

	if (multiBall) {							//Was a MB stacked?
		multiBallEnd(1);						//End it, with flag that it's ending along with a mode
	}

	tourClear();	
	
	loadLamp(player);								//Load the original lamp state back in
	spiritGuideEnable(1);
	comboKill();
	
	killNumbers();							//Turn off numbers	
	
	if (goldHits < 100) {
		goldHits = 0;								//Enable Gold for next time if we didn't get it
	}
							
	AddScore(winScore);

	ghostAction = 20000;
	ghostModeRGB[0] = 0;
	ghostModeRGB[1] = 0;
	ghostModeRGB[2] = 0;
	ghostFadeTimer = 200;
	ghostFadeAmount = 200;
	setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color
	
	light(59, 7);							//War Fort solid = Mode Won!
	light(16, 0);							//Turn off MAKE CONTACT light

	light(17, 0);							//Clear the lights for a bit
	light(18, 0);
	light(19, 0);
	
	ghostLook = 1;													//Ghost will now look around again.
	ghostAction = 0;
	ghostMove(90, 50);	

	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();		
	
	killQ();													//Disable any Enqueued videos	
	video('W', '9', 'A', noExitFlush, 0, 255); 					//Play Death Video
	numbersPriority(0, numberFlash | 1, 255, 11, modeTotal, 233);			//Load Mode Total Points	
	modeTotal = 0;													//Reset mode points		
	videoQ('W', '9', 'B', noEntryFlush | B00000011, 0, 233);	//Mode Total:	
	playSFX(0, 'W', '8', random(4) + 65, 255);	//Mode end dialog	
			
	fortProgress[player] = 99;

	playMusic('M', '2');							//Normal music
			
	if (videoMode[player] == 0) {					//Video mode is available?
		TargetTimerSet(55000, TargetUp, 50);		//Put targets back up 60000 but not so fast ball is caught	
	}	
	
}

void WarFail() {

	tourClear();	

	loadLamp(player);								//Load the original lamp state back in

	spiritGuideEnable(1);
	comboKill();
	
	killNumbers();							//Turn off numbers	
	if (goldHits < 100) {
		goldHits = 0;								//Enable Gold for next time if we didn't get it
	}	

	if (ModeWon[player] & warBit) {								//Did we win this mode before?
		light(59, 7);												//Make light solid, since it HAS been won
	}
	else {
		light(59, 0);												//Haven't won it yet, turn it off
	}

	ghostModeRGB[0] = 0;
	ghostModeRGB[1] = 0;
	ghostModeRGB[2] = 0;
	ghostFadeTimer = 100;										//Fade out ghost
	ghostFadeAmount = 100;
	setCabModeFade(defaultR, defaultG, defaultB, 100);				//Reset cabinet color

	killScoreNumbers();												//Disable any custom score numbers (so they won't pop up next time we build a custom score display)
	killCustomScore();	
	
	light(16, 0);							//Turn off "Make Contact"
	light(17, 0);
	light(18, 0);	
	light(19, 0);


	ghostLook = 1;							//Ghost will now look around again.
	ghostAction = 0;
	ghostMove(90, 50);
	
	modeTotal = 0;							//Reset mode points			
	Mode[player] = 0;						//Set mode active to None

	//fortProgress[player] = 50;				//50 indicates Mode is ready to start. You can re-start the Ghost Whore fight

	if (modeRestart[player] & warBit) {							//Able to restart War Fort?
		modeRestart[player] &= ~warBit;							//Clear the restart bit	
		fortProgress[player] = 50;									//Mode start light re-lit
		pulse(44);													//Pulse the ARMY GHOST start light	
		popLogic(3);												//Set pops to EVP
		showProgress(0, player);
	}
	else {															//End mode, and let the ball drain
		light(44, 0);												//Make sure Army Ghost light is OFF
		dirtyPoolMode(1);											//Don't want to trap balls anymore
		fortProgress[player] = 0;									//Gotta start over
		
		if (barProgress[player] < 50) {								//Haven't completed the Bar yet?
			popLogic(2);											//Set pops to advance Bar
		}
		else {
			popLogic(1);											//Else, have them re-advance War Fort until we get it
		}
		
		showProgress(0, player);
	}	
	
	Advance_Enable = 1;
	checkModePost();

	for (int x = 0 ; x < 6 ; x++) {					//Make sure the MB lights are off
		light(26 + x, 0);
	}	
	
	hellEnable(1);
	showProgress(0, player);					//Show the progress, Active Mode style	
		
}

void WarOver() {

	ghostsDefeated[player] += 1;			//For bonuses
	Advance_Enable = 1;						//Allow other modes to be started			
	Mode[player] = 0;						//Set mode active to None
	fortProgress[player] = 100;				//Flag that reminds us this mode has been won
	ModeWon[player] |= 1 << 4;				//Set WAR FORT WON bit for this player.	

	if (videoMode[player] > 0) {									//Video mode is available?
		blink(17);
		blink(18);
		blink(19);
		videoMode[player] = 1;										//Set to active
		loopCatch = catchBall;										//Flag that we want to catch the ball in the loop
	}	
	
	if (countGhosts() == 6) {										//This the final Ghost Boss? Light BOSSES solid!
		light(48, 7);
	}

	minionEnd(2);								//Re-enable Minion find but do NOT let it control targets since this mode needs to do that

	//Manually do checkModePost logic, omitting Target Logic

	doorLogic();								//Figure out what to do with the door
	elevatorLogic();							//Did the mode move the elevator? Re-enable it and lock lights
	popLogic(0);								//Figure out what mode pops should be in

	if (countGhosts() == 2 or countGhosts() == 5) {	//Defeating 2 or 5 ghosts lights EXTRA BALL
	
		extraBallLight(2);							//Light extra ball, no prompt we'll do there
		//videoSFX('S', 'A', 'A', allowSmall, 0, 255, 0, 'A', 'X', 'A' + random(2), 255);	//"Extra Ball is Lit!"			
	
	}	
	
	demonQualify();									//See if Demon Mode is ready
		
	for (int x = 0 ; x < 6 ; x++) {					//Make sure the MB lights are off
		light(26 + x, 0);
	}		
	
	hellEnable(1);
		
	showProgress(0, player);						//Show the progress, Active Mode style	
			
}

void winMusicPlay() {               //Play whatever WIN SONG the user chose to hear in the game's Main Menu
 
  //winMusic
 
 	playMusic('W', '@' + winMusic);		//Play the selected music	
  
  
}

//END FUNCTIONS FOR WAR FORT MODE 3............................

void videoModeLite() {					//Allows player to trap ball under ghost to start Video Mode

	TargetTimerSet(10, TargetDown, 1);
	blink(17);
	blink(18);
	blink(19);
	videoMode[player] = 1;										//Set to active
	loopCatch = catchBall;										//Flag that we want to catch the ball in the loop
		
}

void videoModeCheck() {					//See if video mode ready and if so, pause it until mode is complete

	if (videoMode[player] == 1) {
		videoMode[player] = 10;
		loopCatch = 0;				
	}

}


//LIGHT AND SWITCH FUNCTIONS..............................

int SwitchPop(unsigned char switchGet) {						//Special version of Switch for the pops. In case of ball search, prevents pops from false triggering a switch hit

	if ((switchStatus[switchGet] == swRampDBTime[switchGet]) and (swDebounce[switchGet] == 0)) {			//Has switch been on for its minimum time?
		swDebounce[switchGet] = swDBTime[switchGet];													//Set switch timer to its standard debounce from the table

    if (switchDead < deadTop) {     //Pop switches should only count toward finding a ball if a ball search isn't active (since they can self-trigger from vibration)
      switchDead = 0;
      searchAttempts = 0;																				//Reset # of searches
      
      if (chaseBall == 10) {							//Ball was lost, now it's found, apparently
        chaseBall = 0;								//Clear flag
      }  
      
    }      

		return 1;																						//Return value of switch bit. The only way 1 will be returned is if Debounce has reset. 
	}
	else {
		return 0;										//If timer not yet reset, return a 0.	
	}	

}


int Switch(unsigned char switchGet) {						//Read a matrix switch. If switch is on and debounce is off, returns a 1, else 0

	if ((switchStatus[switchGet] == swRampDBTime[switchGet]) and (swDebounce[switchGet] == 0)) {			//Has switch been on for its minimum time?
		swDebounce[switchGet] = swDBTime[switchGet];													//Set switch timer to its standard debounce from the table
		
    switchDead = 0;										//A switch was hit, reset fail timer           
		searchAttempts = 0;																				//Reset # of searches
    
		if (chaseBall == 10) {							//Ball was lost, now it's found, apparently
			chaseBall = 0;								//Clear flag
		}
		return 1;																						//Return value of switch bit. The only way 1 will be returned is if Debounce has reset. 
	}
	else {
		return 0;										//If timer not yet reset, return a 0.	
	}	

}

int cabSwitch(unsigned char switchGet) {				//Read a dedicated switch. If switch is on and debounce is off, returns a 1, else 0

	if (cabStatus[switchGet] == cabRampDBTime[switchGet] and cabDebounce[switchGet] == 0) {				//Has switch been on for its minimum time, and has debounce reset?
		cabDebounce[switchGet] = cabDBTime[switchGet];													//Set switch timer to its standard debounce from the table
		return 1;																			//Return value of switch bit. The only way 1 will be returned is if Debounce has reset. 
	}
	else {
		return 0;										//If timer not yet reset, return a 0.	
	}	

}


void switchDebounce(unsigned char whichSwitch) {				//Manually enables a switch's debounce so it doesn't double-fire

	swDebounce[whichSwitch] = swDBTime[whichSwitch];

}

void switchDebounceClear(unsigned char startingX, unsigned char endingX) {	//Manually clears the debounce on a range of switches. Use in situatiosn where the anti-machinegunning code would cause balls to sit un-ejected

	for (int x = startingX ; x < endingX + 1 ; x++) {
		swDebounce[x] = 0;
		switchStatus[x] = 0;
	}

}

void switchTest() {								//Shows the status of the switch matrix for terminal viewing

	Serial.print(cabinet, BIN); 			Serial.print("\t");
	
	Serial.print("-\t");					//Separator and another tab spacing
	
	Serial.print(switches[7], BIN); 		Serial.print("\t");
	Serial.print(switches[6], BIN); 		Serial.print("\t");		
	Serial.print(switches[5], BIN); 		Serial.print("\t");
	Serial.print(switches[4], BIN); 		Serial.print("\t");
	Serial.print(switches[3], BIN); 		Serial.print("\t");
	Serial.print(switches[2], BIN); 		Serial.print("\t");
	Serial.print(switches[1], BIN); 		Serial.print("\t");
	Serial.print(switches[0], BIN); 		Serial.print("\t");
	Serial.println(" ");

}

void switchBinary() {							//Returns the status of the switch matrix in raw binary data

	Serial.print("[sw");
	
	Serial.write(cabinet >> 8);
	Serial.write(cabinet & 0xFF);

	for (int x = 0 ; x < 8 ; x++) {
	
		Serial.write(switches[x]);
	
	}
	
	Serial.write("/sw]");

}

void solenoidsOff() {

	for (int x = 0 ; x < 24 ; x++) {    //Set all solenoid to OFF.
		digitalWrite(SolPin[x], 0);	
	}

}

//------------------------------------------------------------------------------

void setGhostModeRGB(unsigned char RedG, unsigned char GreenG, unsigned char BlueG) {

	ghostModeRGB[0] = RedG;
	ghostModeRGB[1] = GreenG;
	ghostModeRGB[2] = BlueG;
	
	ghostRGB[0] = RedG;
	ghostRGB[1] = GreenG;
	ghostRGB[2] = BlueG;
	
	ghostColor(RedG, GreenG, BlueG);

}

void setFadeRGB(unsigned char RedG, unsigned char GreenG, unsigned char BlueG, unsigned long whatTime) {	//Fades from Black into this color, at X speed

	ghostModeRGB[0] = RedG;
	ghostModeRGB[1] = GreenG;
	ghostModeRGB[2] = BlueG;
	
	ghostRGB[0] = 0;
	ghostRGB[1] = 0;
	ghostRGB[2] = 0;

	ghostFadeTimer = whatTime;
	ghostFadeAmount = whatTime;		

}

void setCabMode(unsigned char lR, unsigned char lG, unsigned char lB) {		//Set the current cabinet mode color, cabinet immediately turns this color (game start, ball end, etc)

	cabModeRGB[0] = lR;														//Store colors in memory
	cabModeRGB[1] = lG;
	cabModeRGB[2] = lB;

	cabColor(cabModeRGB[0], cabModeRGB[1], cabModeRGB[2], cabModeRGB[0], cabModeRGB[1], cabModeRGB[2]);
	
	doRGB();
	
}

void setCabModeFade(unsigned char lR, unsigned char lG, unsigned char lB, unsigned short theSpeed) {		//Set the current cabinet mode color and fades to it at a certain speed (good for mode starts and ends)

	cabModeRGB[0] = lR;														//Store colors in memory
	cabModeRGB[1] = lG;
	cabModeRGB[2] = lB;

	RGBspeed = theSpeed;
	RGBtimer = RGBspeed;							//How quickly it should change

	targetRGB[0] = cabModeRGB[0];						//Fade to mode colors
	targetRGB[1] = cabModeRGB[1];
	targetRGB[2] = cabModeRGB[2];
		
}

void flashCab(unsigned char lR, unsigned char lG, unsigned char lB, unsigned char flashSpeed) { 			//Flash cab to this color, then fade back to normal mode color

	cabColor(lR, lG, lB, lR, lG, lB);											//Flash of color, sets current color to this
	
	RGBspeed = flashSpeed;														//RGB timer will fade back to default mode color
	RGBtimer = RGBspeed;														//How quickly it should change

	targetRGB[0] = cabModeRGB[0];												//Tell system to fade back to normal mode cabinet colors
	targetRGB[1] = cabModeRGB[1];
	targetRGB[2] = cabModeRGB[2];

}

void cabColor(unsigned char lR, unsigned char lG, unsigned char lB, unsigned char rR, unsigned char rG, unsigned char rB) {		//Set cabinet lights directly to a certain color. Doesn't store value

	leftRGB[0] = lR;
	leftRGB[1] = lG;
	leftRGB[2] = lB;
	rightRGB[0] = rR;
	rightRGB[1] = rG;
	rightRGB[2] = rB;	

}    

void cabLeft(unsigned char lR, unsigned char lG, unsigned char lB) {	//Sets current left cab color to this value

	leftRGB[0] = lR;
	leftRGB[1] = lG;
	leftRGB[2] = lB;

	//doRGB();
	
}    

void cabRight(unsigned char rR, unsigned char rG, unsigned char rB) {	//Sets current right cab color to this value

	rightRGB[0] = rR;
	rightRGB[1] = rG;
	rightRGB[2] = rB;	

	//doRGB();
	
} 

void setCabColor(unsigned char cR, unsigned char cG, unsigned char cB, unsigned short theSpeed) {

	RGBspeed = theSpeed;
	RGBtimer = RGBspeed;							//How quickly it should change

	targetRGB[0] = cR;
	targetRGB[1] = cG;
	targetRGB[2] = cB;

}

void doRGB() {									//Sends cabinet and ghost RGB data out. We only do this when we have to

	//Do LEFT CABINET COLOR
	RGBByte(leftRGB[0]);						//Send out Red data
	RGBByte(leftRGB[1]);						//Send out Green data		
	RGBByte(leftRGB[2]);						//Send out Blue data	
	
	//Do RIGHT CABINET COLOR
	RGBByte(rightRGB[0]);						//Send out Red data
	RGBByte(rightRGB[1]);						//Send out Green data		
	RGBByte(rightRGB[2]);						//Send out Blue data	
  
	//Do GHOST COLORS
	slowRGBByte(ghostRGB[0]);						//Send out Red data	
	slowRGBByte(ghostRGB[rgbSwap[rgbType]]);		//Send out Green or Blue data (rev 2 board compatible)		
	slowRGBByte(ghostRGB[rgbSwap[rgbType + 1]]);	//Send out Blue or Green data		
	
	LATECLR = RGBClockBit;						//Pull clock low to put strip into reset/post mode
		
	//digitalWrite(RGBClock, 0); 					//Pull clock low to put strip into reset/post mode

}

void slowRGBByte(unsigned char RGBvalue) {  //Can't go as fast because of cable length

	unsigned char LEDmask = B10000000;				//Set starting masking bit to load in MSB first

	for (int gg = 0; gg < 8; gg++) {				//Send out 8 bits serially

		digitalWrite(RGBClock, 0); 				//Only change data when clock is low

 		if(RGBvalue & LEDmask) {					//A bit is there? 
			LATESET = RGBDataBit;           //Set						
		}	
		else {
			LATECLR = RGBDataBit;           //Else, clear
		}   
    
    //digitalWrite(RGBData, RGBvalue & LEDmask);

		digitalWrite(RGBClock, 1); 				//Data is latched when clock goes high
		
		LEDmask >>= 1;
		
	} 	

}

void RGBByte(unsigned char RGBvalue) {

	unsigned char LEDmask = B10000000;				//Set starting masking bit to load in MSB first
	
	for (int gg = 0; gg < 8; gg++) {				//Send out 8 bits serially
			
		LATECLR = RGBClockBit;						//Only change data when clock is low

		if(RGBvalue & LEDmask) {					//A bit is there? 
			LATESET = RGBDataBit;           //Set						
		}	
		else {
			LATECLR = RGBDataBit;           //Else, clear
		}

		LATESET = RGBClockBit;						//Set clock HIGH to latch the current bit
		
		LEDmask >>= 1;								    //Check the next bit
		
	} 	

}	


//------------------------------------------------------------------------------

void animatePF(unsigned short startingFrame, unsigned short totalFrames, unsigned char repeatLights) {

	if (startingFrame == 0 and totalFrames == 0) {			//Kill animation?
		lightStatus = 0;									//Clear status flag and return
		return;
	}
	else {
		lightStatus = lightAnimate | (repeatLights << 6);		//Set the animate bit, plus repeat flag if set
	}
	
	lightStart = startingFrame;								//Set starting frame
	lightCurrent = startingFrame;							//Set current position (at start)
	lightEnd =	startingFrame + totalFrames; 				//Calculate end position now to save a step later

}

void blink(unsigned char whichLamp) {

	if (lampState[whichLamp] == 3) { 						 //Was this light strobing?
		for (int x = whichLamp ; x < whichLamp + strobeAmount[whichLamp] ; x++) {
				lamp[x] = 0;								 //Clear all strobing lights.					
		}		
	}

	lampState[whichLamp] = 1;						 						

}

void pulse(unsigned char whichLamp) {

	if (lampState[whichLamp] == 3) { 						 //Was this light strobing?
		for (int x = whichLamp ; x < whichLamp + strobeAmount[whichLamp] ; x++) {
				lamp[x] = 0;								 //Clear all strobing lights.
				lampState[x] = 0;
		}		
	}

	lampState[whichLamp] = 2;						 						

}

void light(unsigned char whichLamp, unsigned char howBright) {

	if (lampState[whichLamp] == 3) { 						 //Was this light strobing?
		for (int x = whichLamp ; x < whichLamp + strobeAmount[whichLamp] ; x++) {
				lamp[x] = 0;								 //Clear all strobing lights above it				
				lampState[x] = 0;
		}		
	}	

	if (howBright) {										//Any light at all?
		lampState[whichLamp] = 10;							//Normal lamp state, will NOT OR with animation
	}
	else {
		lampState[whichLamp] = 0;							//No light (OK to OR with animation)
	}
	
	lamp[whichLamp] = howBright;

}

void strobe(unsigned char whichLamp, unsigned char howMany) {

	lampState[whichLamp] = 3;						 						
	
	strobeAmount[whichLamp] = howMany;	 			 						//Set total number of lights to strobe (includes starting light)			
		
	for (int x = whichLamp + 1 ; x < whichLamp + strobeAmount[whichLamp] ; x++) {
			lampState[x] = 33;								 						//Clear lamp states of strobing lights. Example, if one was set to blink, strobe overwrites it.			
	}		


}

void storeLamp(unsigned char whichPlayer) {							//Stores current lamp values into specified player's lamp memory

	int lampPointer = (whichPlayer - 1) * 64;						//Start at 0, 64, 128, 192

	for (int x = 0 ; x < 64 ; x++) {
		lampPlayers[lampPointer] = lamp[x];
		statePlayers[lampPointer] = lampState[x];
		strobePlayers[lampPointer] = strobeAmount[x];		
		lampPointer += 1;
	}
	
}

void loadLamp(unsigned char whichPlayer) {							//Load specified player's lamp memory into current display

	int lampPointer = (whichPlayer - 1) * 64;						//Start at 0, 64, 128, 192

	for (int x = 0 ; x < 64 ; x++) {
		lamp[x] = lampPlayers[lampPointer];
		lampState[x] = statePlayers[lampPointer];
		strobeAmount[x] = strobePlayers[lampPointer];		
		lampPointer += 1;
	}

	spookCheck();
	
}

void allLamp(unsigned char allValue) {								//Turns off strobes, blinks, pulses. Sets all lamps to single value.

	for (int x = 0 ; x < 64 ; x++) {
		lamp[x] = allValue;
		if (allValue) {
			lampState[x] = 10;
		}
		else {
			lampState[x] = 0;
		}
		strobeAmount[x] = 0;		
	}

	spookCheck();													//See what Spook Again light should be doing
	
}

void updateRollovers() {	//Call this to update the GLIR and ORB lights

		if (orb[player] & B00100100) {	//O lit?
			light(32, 7);
		}
		else {
			light(32, 0);
		}
		if (orb[player] & B00010010) {	//R lit?
			light(33, 7);
		}
		else {
			light(33, 0);
		}
		if (orb[player] & B00001001) {	//B lit?
			light(34, 7);
		}
		else {
			light(34, 0);
		}
		if (rollOvers[player] & B10001000) {	//G lit?
			light(52, 7);
		}
		else {
			light(52, 0);
		}
		if (rollOvers[player] & B01000100) {	//L lit?
			light(53, 7);
		}
		else {
			light(53, 0);
		}
		if (rollOvers[player] & B00100010) {	//I lit?
			light(54, 7);
		}
		else {
			light(54, 0);
		}
		if (rollOvers[player] & B00010001) {	//R lit?
			light(55, 7);
		}
		else {
			light(55, 0);
		}
		

}

void Coil(unsigned char WhichCoil, unsigned long HowLong) {

	if (HowLong > 255) {										//Maxium pulse 255ms
		HowLong = 255;
	}

	HowLong *= 40000;											 //Convert HowLong in ms into the 40MHz system counter.

	digitalWrite(SolPin[WhichCoil], 1);                        	 //Trigger specified solenoid        

	SolTimer[WhichCoil] = ReadCoreTimer() + HowLong; 			 //Calculate when it should be turned off
 
	if (SolTimer[WhichCoil] == 0 or SolTimer[WhichCoil] > 4294947294) {	//If timer rolls over to 0, or is within 20,001 cycles of the core timer count...
	
		SolTimer[WhichCoil] = 1;								//Roll the timer back to 1 to be safe
	
	}
 
}

void GIbgSet(unsigned char whichBit, unsigned char whatValue) {
  
   if (whatValue) {                     //Set the bit (and start from bit 8, not bit 0 since the BG uses the upper byte of the GI word)    
      GIword |= (0x100 << whichBit); 
   }
   else {
      GIword &= ~(0x100 << whichBit);         
   }
  
}

void GIbg(unsigned short theValue) {

	GIword &= 0xFF;			        //Clear top byte, preserve lower byte
	
	GIword |= theValue << 8;		//Set top type to incoming

}

void GIpf(unsigned short theValue) {

	GIword &= 0xFF << 8;			  //Preserve upper byte, clear lower
	
	GIword |= theValue;					//Set lower byte to incoming

}

void defaultSettings() {

	//EEPROM 0 = Version number & checksum
	
	//EEPROM 1:
	freePlay = 1;
	coinsPerCredit = 1;
	ballsPerGame = 4;					//Is always 1 higher than actual
	allowExtraBalls = 1;				//Allow extra balls
	
	//EEPROM 2:	
	tiltLimit = 3;						//On third bump, you tilt (2 warnings)
	spotProgress = 0;					//Fort / Bar start at 0 pops
	saveStart = 5;						//Default of 5 seconds 8-22-14 fix

	//EEPROM 3:
	allowMatch = 1;						//Usually allow matches
	videoSpeedStart = 4;				//4 cycles per video frame advance (goes down to 1 during mode)
	sfxDefault = 25;					//Default mixing levels	
	musicDefault = 20;					//Default mixing levels	

	//EEPROM 4:
	//Games played, is NOT reset when you set Default Settings
	
	//EEPROM 5:
	replayValue = 50000000;				//Point at which player gets a replay default 50 mil

	//EEPROM 6:
	tournament = 0;						//Default is OFF
	allowReplay = 1;					//Default is to give them out
	EVP_EBsetting = 10;					//10 EVP's give extra ball (and the target is increased by this much each time)
	comboSeconds = 6;					//Default 6 seconds to collect a combo
	
	//EEPROM 7:	
	videoModeEnable = 1;				//Fine, enable the damn video mode. Sheesh.
	zeroPointBall = 1;					//If no points scored on that ball, give ball back
	scoopSaveStart = 1510;				//Default 1.5 seconds for scoop eject ball save timer. We add 10 so in the menu we can subtract 10 and make it look like it goes to zero.
	
	//EEPROM 8:
	//rgbType should NOT be set here! It should only change at the factory or if user specifically changes it in the menu.
	deadTopSeconds = deadTopDefault;	//Default # of seconds before ball search begins
	searchTimer = searchTimerDefault;
	
	//EEPROM 9:
	//flipperAttract  It should only change at the factory or if user specifically changes it in the menu.
	creditDot = 0;
  magEnglish = 0;
  winMusic = 1;               //New music
  
	//EEPROM 20:	Like #8, RGB settings, this should only be set when new code detects no settings are in EEPROM (either a blank flash or code update) or if a user manually changes it
	
	//TargetDown = TargetDownDefault;				//Set these to defaults on load
	//TargetUp = TargetUpDefault;
	//hellUp =  hellUpDefault;
	//hellDown = hellDownDefault;
	
	//EEPROM 21:	
	//DoorOpen = DoorOpenDefault;
	//DoorClosed = DoorClosedDefault;	

  //EEPROM 22:
  tiltTenths = 6;             //6/10ths of a second
  middleWarBar = 0;           //Middle shot does NOT advance pops  
  scoopSaveWhen = 0;          //Default is to always allow the scoop save to work 1 = doesn't work in multiball
  orbSlings = 20;             //Default # of sling hits it takes to spot an ORB letter
	
  //EEPROM 23:  
  pulsesPerCoin = 3;          //Default is 75 cents per play, or 3 plays for $2.00
  pulsesPerCredit = 8;
  ghostBurstCallout = 1;      
	coinDoorDetect = 0;					//Default is to NOT warn when coin door open (and prevent ball drain)

  
	for (int x = 0 ; x < 8 ; x++) {		//Copy coil defaults
		coilSettings[x] = coilDefaults[x];	
	}
	

	//nameGame("0123456789ABCDEF");		//For reference
	nameGame("AMH - SPOOKY PIN");		//Name the game on EEPROM! (so display will show it on boot, 16 characters max including spaces)
	
}

void loadSettings() {					//Get default game settings from EEPROM

	boolean reSaveSettings = false;		//If we load a non-existent memory location (due to updates) set flag to re-save EEPROM settings before continuing

	unsigned long x = 0;				//Used to extract values
	
	x = readEEPROM(0);					//Read the checksum byte and version number

	//Serial.println(x, HEX);				//Print the checksum + version # in hex for reference
	
	if (x != ((versionNumber << 24) | 0xBAFA)) {		//version#, null, BA, FA
	
		gamesPlayed = readEEPROM(4);				//Get # of games played before we write default values (so we don't write over it, user can choose to reset it)
	
		Serial.print("New code detected, storing new game defaults...");	
		
		defaultSettings();							//If checksum not there, or if this code is newer than what's on the machine, get default settings
		saveSettings(0);								//And then save them to EEPROM
		
		Serial.println(" done!");				
		Serial.println("-------------------------------");					
		return;
		
	}
	
	x = readEEPROM(1);
			
	freePlay = x >> 24;
	coinsPerCredit = (x >> 16) & 0xFF;
	ballsPerGame = (x >> 8) & 0xFF;
	allowExtraBalls = x & 0xFF;

	x = readEEPROM(2);

	tiltLimit = x >> 24;
	spotProgress = (x >> 16) & 0xFF;
	saveStart = x & 0xFFFF;							//Tried to put up to 90,000 in a 16 bit number, Oops! Gonna just make it 1-9 (seconds) X cycleSecond. Still in 16 bit number for compatibility
		
	x = readEEPROM(3);

	allowMatch = x >> 24;
	videoSpeedStart = (x >> 16) & 0xFF;
	sfxDefault = (x >> 8) & 0xFF;
	musicDefault = x & 0xFF;
	
	gamesPlayed = readEEPROM(4);
	replayValue = readEEPROM(5);

	x = readEEPROM(6);

	tournament = x >> 24;
	allowReplay = (x >> 16) & 0xFF;
	EVP_EBsetting = (x >> 8) & 0xFF;
	comboSeconds = x & 0xFF;

	x = readEEPROM(7);
	
	videoModeEnable = x >> 24;
	zeroPointBall = (x >> 16) & 0xFF;
	scoopSaveStart = x & 0xFFFF;									//0-65535 milliseconds	
	
	x = readEEPROM(8);
	
	rgbType = x >> 24;
	deadTopSeconds = (x >> 16) & 0xFF;
	searchTimer = x & 0xFFFF;

	x = readEEPROM(9);
	
	flipperAttract = x >> 24;
	creditDot = (x >> 16) & 0xFF;
  magEnglish = (x >> 8) & 0xFF;
  
	//EEPROM 10-17 used for coil settings
	
	x = readEEPROM(20);	
	
	TargetDown = x >> 24;
	TargetUp = (x >> 16) & 0xFF;
	hellUp = (x >> 8) & 0xFF;
	hellDown = x & 0xFF;

	x = readEEPROM(21);	

	DoorOpen = x >> 24;
	DoorClosed = (x >> 16) & 0xFF;
  winMusic = (x >> 8) & 0xFF;
    
	x = readEEPROM(22);	  
  
  tiltTenths = x >> 24;
  middleWarBar = (x >> 16) & 0xFF;
  scoopSaveWhen = (x >> 8) & 0xFF;
  orbSlings = x & 0xFF;
  
	x = readEEPROM(23);	  
  
  pulsesPerCoin = x >> 24;
  pulsesPerCredit = (x >> 16) & 0xFF;
  ghostBurstCallout = (x >> 8) & 0xFF;
  coinDoorDetect = x & 0xFF;  

  //If a new setting is added in EEPROM, an existing game (pre-update) will have FFFFFFFF there. Check if invalid setting loaded, set default, and re-save to EEPROM
  
	if (TargetDown > TargetDownDefault or TargetUp < TargetUpDefault or hellUp > hellUpDefault or hellDown < hellDownDefault or DoorOpen < DoorOpenDefault or DoorClosed > DoorClosedDefault ) {	//If ANY servo setting is loaded out of range, assume no EEPROM data and set defaults		
		TargetDown = TargetDownDefault;								//Set defaults. Note that these are NOT reset when "Set Default Settings" is used in the menu
		TargetUp = TargetUpDefault;
		hellUp =  hellUpDefault;
		hellDown = hellDownDefault;
		DoorOpen = DoorOpenDefault;
		DoorClosed = DoorClosedDefault;
		reSaveSettings = true;										//Flag to re-write default values
	}	
		
	if (rgbType != 0 and rgbType != 1) {							//No valid setting found?
		rgbType = 0;												            //Set to Rev 1 (older Ghost RGB boards)
		reSaveSettings = true;										      //Flag to save new settings	
	}
		
	if (EVP_EBsetting == 0 or EVP_EBsetting > 30) {					//Updated game where this data doesn't exist?
		EVP_EBsetting = 10;											             //Set default of 10
		reSaveSettings = true;
	}
	
	if (comboSeconds == 0 or comboSeconds > 15) {					//Updated game where this data doesn't exist?
		comboSeconds = 6;											              //Default of 6 seconds
		reSaveSettings = true;		
	}

	if (scoopSaveStart == 0 or scoopSaveStart > 5010) {				//Updated game where this data doesn't exist?
		scoopSaveStart = 1510;										              //Default of 1.5 seconds
		reSaveSettings = true;
	}

	if (saveStart > 9000) {											//Found old settings using 10000-90000? 				8-22-14 fix
		saveStart = 5;												    //Set to default using new 1-9 seconds				
		reSaveSettings = true; 
	}

	if (flipperAttract != 0 and flipperAttract != 1) {				//No setting for this?
		flipperAttract = 1;											//The default is to allow flipper prompts
		reSaveSettings = true;		
	}

	if (deadTopSeconds < 5 or deadTopSeconds > 20 or searchTimer < 2000 or searchTimer > 6000) {					//No setting for DeadTopSeconds or Search Timer found?	
		deadTopSeconds = deadTopDefault;							          //Default # of seconds before ball search begins
    deadTop = deadTopSeconds * cycleSecond;                 //Calculate what it should be
		searchTimer = searchTimerDefault;							          //Default intensity	
		reSaveSettings = true;	
	}
  
	if (creditDot > 1) {						                        //No setting for this?		
		creditDot = 0;
		reSaveSettings = true;			
	}

  if (tiltTenths > 15 or tiltTenths < 5) {
    tiltTenths = 6;                               //Default is 6/10th of a second   
		reSaveSettings = true;	        
  }

  if (middleWarBar > 5) {
    middleWarBar = 0;
		reSaveSettings = true;   
  }

  if (scoopSaveWhen > 1) {
    scoopSaveWhen = 0;
    reSaveSettings = true;    
  }

  if (orbSlings < 20 or orbSlings > 100) {
    orbSlings = 20;
    reSaveSettings = true;    
  }

  if (magEnglish > 3) {
    magEnglish = 0;
    reSaveSettings = true;    
  }
  
  if (winMusic < 1 or winMusic > 6) {
    winMusic = 1;
    reSaveSettings = true; 
  }
  
  if (pulsesPerCoin < 1 or pulsesPerCoin > 99 or pulsesPerCredit < 1 or pulsesPerCredit > 99 or ghostBurstCallout > 1) {
    pulsesPerCoin = 3;                              //Default is 75 cents per play, or 3 plays for $2.00
    pulsesPerCredit = 8;
    ghostBurstCallout = 1;
    reSaveSettings = true;  
  }

  if (coinDoorDetect > 1) {   
    coinDoorDetect = 0;
    reSaveSettings = true;   
  }
 
  if (sfxDefault > 35 or musicDefault > 35) {     //New settings are more limited
    
    sfxDefault = 25;
    musicDefault = 20;
    reSaveSettings = true;   
  }
 
  cabDBTime[8] = tiltTenths * 1200;               //Set the debounce 
	
	//Get custom coil settings...
	
	coilSettings[0] = readEEPROM(10);								//Get flipper power
	coilSettings[1] = readEEPROM(11);								//Get slings power
	coilSettings[2] = readEEPROM(12);								//Get pops power
	coilSettings[3] = readEEPROM(13);								//Get left VUK power
	coilSettings[4] = readEEPROM(14);								//Get right scoop power
	coilSettings[5] = readEEPROM(15);								//Get autolauncher power
	coilSettings[6] = readEEPROM(16);								//Get ball loader power
	coilSettings[7] = readEEPROM(17);								//Get drain kick power
	
	calculateCoils();												  //...and convert them to actual cycle timer counts
	
	ballsPlayed = readEEPROM(64);
	totalBallTime = readEEPROM(65);
	extraBallGet = readEEPROM(66);
	replayGet = readEEPROM(67);
	matchGet = readEEPROM(68);
	coinsInserted = readEEPROM(69);

	sfxVolume[0] = sfxDefault;
	sfxVolume[1] = sfxDefault;
	volumeSFX(0, sfxVolume[0], sfxVolume[1]);		
	volumeSFX(1, sfxVolume[0], sfxVolume[1]);		
	volumeSFX(2, sfxVolume[0], sfxVolume[1]);	
	
	musicVolume[0] = musicDefault;
	musicVolume[1] = musicDefault;
	volumeSFX(3, musicVolume[0], musicVolume[1]);  
  
	if (reSaveSettings == true) {											//Did we find blank entries? Re-save EEPROM with new default values	
		Serial.print("New settings found, re-writing EEPROM values...");
		saveSettings(0);
		Serial.println(" done!");				
		Serial.println("-------------------------------");				
	}
	
}

void saveSettings(unsigned char messageFlag) {					//Save default game settings to EEPROM

	if (messageFlag) {
		graphicsMode(10, clearScreen);
		text(3, 1, "SAVING  TO");			
		text(3, 2, "  EEPROM");	
		graphicsMode(10, loadScreen);				
	}

	writeEEPROM(0, versionNumber << 24 | 0xBAFA);				//Checksum that says Yes, settings have been saved	
	//writeEEPROM(0, 0xBAFA);									//Checksum that says Yes, settings have been saved
	
	//Write game settings
	writeEEPROM(1, freePlay << 24 | coinsPerCredit << 16 | ballsPerGame << 8 | allowExtraBalls);
	writeEEPROM(2, tiltLimit << 24 | spotProgress << 16 | saveStart);	
	writeEEPROM(3, allowMatch << 24 | videoSpeedStart << 16 | sfxDefault << 8 | musicDefault);
	
	//EEPROM location 4, "Games Played", set by SaveStats
	
	writeEEPROM(5, replayValue);
	writeEEPROM(6, tournament << 24 | allowReplay << 16 | EVP_EBsetting << 8 | comboSeconds);
	writeEEPROM(7, videoModeEnable << 24 | zeroPointBall << 16 | scoopSaveStart);
	writeEEPROM(8, rgbType << 24 | deadTopSeconds << 16 | searchTimer);
  writeEEPROM(9, flipperAttract << 24 | creditDot << 16 | magEnglish << 8);
	
	//Write the coil settings to EEPROM
	writeEEPROM(10, coilSettings[0]);	//Flippers		
	writeEEPROM(11, coilSettings[1]);	//Slings	
	writeEEPROM(12, coilSettings[2]);	//Pops
	writeEEPROM(13, coilSettings[3]);	//Left VUK
	writeEEPROM(14, coilSettings[4]);	//Right Scoop
	writeEEPROM(15, coilSettings[5]);	//Autolauncher	
	writeEEPROM(16, coilSettings[6]);	//Ball Loader
	writeEEPROM(17, coilSettings[7]);	//Drain Kicker	

	//Write Servo Defaults to EEPROM
	
	writeEEPROM(20, TargetDown << 24 | TargetUp << 16 | hellUp << 8 | hellDown);		
	writeEEPROM(21, DoorOpen << 24 | DoorClosed << 16 | winMusic << 8);	
  writeEEPROM(22, tiltTenths << 24 | middleWarBar << 16 | scoopSaveWhen << 8 | orbSlings);
  writeEEPROM(23, pulsesPerCoin << 24 | pulsesPerCredit << 16 | ghostBurstCallout << 8 | coinDoorDetect);
  
	//saveAudits();						//Different routine for this since it's written a lot more often
	
}

void saveCreditDot() {
  
  writeEEPROM(9, flipperAttract << 24 | creditDot << 16 | magEnglish << 8);
  
}

void saveAudits() {								//Only saved at the end of a game

	writeEEPROM(4, gamesPlayed);
  
  saveCreditDot();       //Save this one every game in case the Credit Dot status changed (ball found, etc)
    
	writeEEPROM(64, ballsPlayed);				//Counts balls played to compute average ball time
	writeEEPROM(65, totalBallTime);				//Total seconds a ball is in play. Divide by ballsPlayed to get average
	writeEEPROM(66, extraBallGet);				//How many extra balls have been earned
	writeEEPROM(67, replayGet);					//How many replays have been earned
	writeEEPROM(68, matchGet);					//How many matches succeeded
	writeEEPROM(69, coinsInserted);				//How many coins stuck into machine
	
}

void clearAudits() {				//Sets them all to ZEROS, like my salesmen

	gamesPlayed = 0;				//Total games played since last reset
	ballsPlayed = 0;				//Counts balls played to compute average ball time
	totalBallTime = 0;				//Total seconds a ball is in play. Divide by ballsPlayed to get average
	extraBallGet = 0;				//How many extra balls have been earned
	replayGet = 0;					//How many replays have been earned
	matchGet = 0;					//How many matches succeeded
	coinsInserted = 0;				//No more money!
	//FUTURE CRAP HERE
	
}


void nameGame(const char *str) {			//Writes the 16 character game name to EEPROM. MUST be exactly 16 characters! Example: nameGame("0123456789ABCDEF");

	unsigned long nameOut = 0;
	
	for (int x = 0 ; x < 4 ; x++) {			//Sending 4 longs, 4 bytes each = 16 character game name	
	
		nameOut = 0;
		
		for (int xx = 0 ; xx < 4 ; xx++) {	//Build a long out of 4 bytes from input string
		
			nameOut <<= 8;					//Shift nameOut one byte left to make room
			nameOut |= *str++;				//Load a character in LSB
					
		}
		
		writeEEPROM(128 + x, nameOut);		//Send the long we built to the EEPROM
	
	}
	
}

void printName() {							//Finds the game name on the EEPROM and spits it out via the Serial Port (used for programmer identification)

	unsigned long nameOut = 0;

	for (int x = 0 ; x < 4 ; x++) {			//Sending 4 longs, 4 bytes each = 16 character game name	
	
		nameOut = readEEPROM(128 + x);		//Read in a long that will contain 4 character bytes
		
		Serial.write((nameOut >> 24) & 0xFF);
		Serial.write((nameOut >> 16) & 0xFF);
		Serial.write((nameOut >> 8) & 0xFF);
		Serial.write(nameOut & 0xFF);
		
	}

}

void printInitials() {						//Finds the game name on the EEPROM and prints out first 3 characters (the initials)

	unsigned long nameOut = 0;

	nameOut = readEEPROM(128);				//Read in a long that will contain the first 4 character bytes of the game name
		
	Serial.write((nameOut >> 24) & 0xFF);
	Serial.write((nameOut >> 16) & 0xFF);
	Serial.write((nameOut >> 8) & 0xFF);
	Serial.write(",");

}

void printVersion() {							//Finds the game name on the EEPROM and spits it out via the Serial Port (used for programmer identification)

	if (versionNumber > 99) {
	
		Serial.print(versionNumber);
		return;
	
	}
	
	if (versionNumber > 9) {
	
		Serial.print("0");
		Serial.print(versionNumber);
		return;
	
	}

	Serial.print("00");					//Two leading zeros
	Serial.print(versionNumber);

}


void calculateCoils() {					//Set the actual coil timings based off our 0-9 numbers

	FlipPower = (coilSettings[0] * 30) + 1; //30;			//FLIPPERS Gives a range from 1 to 271
	SlingPower = coilSettings[1] + 6;						//SLINGS Gives a range from 6 to 15
	PopPower = coilSettings[2] + 6;							//POPS Gives a range from 6 to 15
	vukPower = coilSettings[3] + 1;							//LEFT VUK Gives a range from 1 to 10	
	scoopPower = (coilSettings[4] * 2) + 12;				//RIGHT SCOOP Gives a range from 12 to 30	
	//plungerStrength = (coilSettings[5] * 2) + 12;			//AUTOLAUCHER Gives a range from 12 to 30	  
	plungerStrength = (coilSettings[5] * 3) + 15;			//AUTOLAUCHER Gives a range from 15 to 42
	loadStrength = (coilSettings[6] * 2) + 1;				//NOW range from 1 to 19 	OLD-> //Ball Loader gives a range from 1 to 10	
  
	//drainStrength = coilSettings[7] + 6;					//Drain strength gives a range from 6 to 15
	drainStrength = (coilSettings[7] * 2) + 7;					//NEW Drain strength gives a range from 7 to 25
	
	drainPWMstart = 6000 - (drainStrength * (cycleSecond / 1000));			//When to switch from high power kick to low pulse hold on drain kick
	
}									

void loadHighScores() {							//Loads all high scores from EEPROM (at start of game, end of game)

//EEPROM LOCATIONS
//0 = Checksum 0							//If does not equal 42, set Generic Scores (double check)
//0 = Checksum 1							//If does not equal 42, set Generic Scores (double check)

	if (readEEPROM(8189) != 42 or readEEPROM(8190) != 42) {	//No scores set?
		setDefaultScores();					//Set generic ones
	}
		
	//readEEPROM(8189);						//Dummy read to flush garbage
	//readEEPROM(8190);						//Dummy read to flush garbage
	
	for (int x = 0 ; x < 5 ; x++) {
		getHighScore(x);					//Retrieve each of the 5 high scores and put them into RAM	
	}

}

void setDefaultScores() {					//Set the generic default scores (machine reset)

//DATA FORMAT:
//SCORE (Big Endian 4 bytes) Initials (ASCII 3 bytes) Example: 255 255 255 255 66 69 78

	writeEEPROM(8189, 42);
	writeEEPROM(8190, 42);
	
	// setHighScore(0, 100000, 'A', 'A', 'A');
	// setHighScore(1, 80000, 'B', 'B', 'B');
	// setHighScore(2, 60000, 'C', 'C', 'C');
	// setHighScore(3, 40000, 'D', 'D', 'D');	
	// setHighScore(4, 20000, 'E', 'E', 'E');
	
	setHighScore(0, 20000000, 'B', 'U', 'G');
	setHighScore(1, 17000000, 'C', 'O', 'W');
	setHighScore(2, 15000000, 'B', 'F', 'K');
	setHighScore(3, 12000000, 'P', 'E', 'D');	
	setHighScore(4, 10000000, 'B', 'J', 'H');

}

void setDefaultScoresTest() {					//Set the test default scores (machine reset)

//DATA FORMAT:
//SCORE (Big Endian 4 bytes) Initials (ASCII 3 bytes) Example: 255 255 255 255 66 69 78

	writeEEPROM(8189, 42);
	writeEEPROM(8190, 42);
	
	setHighScore(0, 100000, 'A', 'A', 'A');
	setHighScore(1, 80000, 'B', 'B', 'B');
	setHighScore(2, 60000, 'C', 'C', 'C');
	setHighScore(3, 40000, 'D', 'D', 'D');	
	setHighScore(4, 20000, 'E', 'E', 'E');
	
	// setHighScore(0, 20000000, 'B', 'U', 'G');
	// setHighScore(1, 17000000, 'C', 'O', 'W');
	// setHighScore(2, 15000000, 'B', 'F', 'K');
	// setHighScore(3, 12000000, 'P', 'E', 'D');	
	// setHighScore(4, 10000000, 'B', 'J', 'H');

}


void setHighScore(int whichPosition, unsigned long theScore, unsigned char char0, unsigned char char1, unsigned char char2) {	//Puts high score on EEPROM

	whichPosition = (whichPosition * 2) + 8179;

	writeEEPROM(whichPosition, theScore);											//2 longs per entry. First is the score
	//delay(50);
	writeEEPROM(whichPosition + 1, (char0 << 24) | (char1 << 16) | (char2 << 8));	//Second long contains the 3 initials
	//delay(50);	
		
}

void getHighScore(unsigned char whichPosition) {	//Puts high score on EEPROM

	unsigned short memLocation = (whichPosition * 2) + 8179;
	
	highScores[whichPosition] = readEEPROM(memLocation);
		
	unsigned long theName = readEEPROM(memLocation + 1);
	
	topPlayers[(whichPosition * 3) + 0] = (theName >> 24) & B11111111;
	topPlayers[(whichPosition * 3) + 1] = (theName >> 16) & B11111111;
	topPlayers[(whichPosition * 3) + 2] = (theName >> 8) & B11111111;	

}

void houseKeeping() {					//Run this routine all the time. It does lighting, checks cabinet switches, and enables solenoids

	boolean strobeFlag = 0;					//Whether or not we should move the strobing lights on this cycle

	blinkTimer += lightSpeed;
	
	if (blinkTimer > blinkSpeed1) {	
		blinkTimer = 0;	
	}

	strobeTimer += lightSpeed;
	
	if (strobeTimer > strobeSpeed) {	
		strobeTimer = 0;
		strobeFlag = 1;								//Set strobe flag.
	}
	
	pulseTimer += lightSpeed;
	
	if (pulseTimer > pulseSpeed) {
		pulseTimer = 0;
		if (pulseDir == 0) {
			pulseLevel += 1;
			if (pulseLevel > 8) {
				pulseDir = 1;				
			}
		}
		if (pulseDir == 1) {
			pulseLevel -= 1;
			if (pulseLevel < 1) {
				pulseDir = 0;				
			}
		}
			
	}

	digitalWrite(solenable, 1);			//Pulse enable line for solenoids
	digitalWrite(solenable, 0);  
	
	tempCabinet = 0;					//Clear variable so we can shift bits into it

	tempGIout = GIword;				//Copy of the GI output data
	
	for (int x = 0 ; x < 64 ; x++) {	//Cycle through lights, cab switches and solenoids
	
		if (x < 16) {					//In value range to clock Cabinet Data bits?
		
			//Get dedicated switch data
			tempCabinet <<= 1;
			digitalWrite(GIdata, tempGIout & 1);				//Shift out data LSB first, Ben style!
			tempGIout >>= 1;
			digitalWrite(cclock, 1); 							//Pulse clock
			digitalWrite(cclock, 0);
			tempCabinet |= !digitalRead(cdatain);   			// read the input pin and invert it (1 = on, 0 = off)

			//Check the exisiting frame of Cabinet Bits against the debounce
			boolean bitState = bitRead(cabinet, x);					//Just do this once
		
			if (cabDebounce[x] and bitState == 0) {				//Is that debounce active and button's been released?
				cabDebounce[x] -= 1;							//Decrement it!		
			}
			
			if (bitState) {										//Check the dedicated switches for a hit
				cabStatus[x] += 1;								//Increment the counter if the switch
				if (cabStatus[x] > cabRampDBTime[x]) {			//Did it reach its ramp up debounce limit?
					cabStatus[x] = cabRampDBTime[x];			//Keep it there until it's sensed and then debounce begins
				}
			}
			else {
				cabStatus[x] = 0;								//No matter what, switch goes off (debounce still is in effect)
			}
			
		}
		
		//Figure out which switch we're on, bitwise
		xColumn = x >> 3; 								//xColumn = switchGet / 8;
		xBit = x - (xColumn << 3); 						//xBit = switchGet - (xColumn * 8);

		boolean bitState2 = bitRead(switches[xColumn], xBit);	//Check switch matrix bit
		
		if (bitState2) {								//Switch closed? (active)
			switchStatus[x] += 1;						//Increment the counter if the switch
			if (switchStatus[x] > swRampDBTime[x]) {	//Did it reach its ramp up debounce limit?
				switchStatus[x] = swRampDBTime[x];		//Keep it there
			}
		}
		else {											//Switch is off?		
			switchStatus[x] = 0;						//No matter what, switch goes off (debounce still is in effect)
		}
		
		if (swDebounce[x]) {							//Is that debounce active?
			
			if (swClearDB[x]) {		//This switch must clear (be open) before allowing a re-trigger? If TILT active, don't check this even if coil is flagged
				if (bitState2 == 0) {					//If switch has re-opened, THEN decrement debounce timer (so it must be open X amount of time before re-trigger)
					swDebounce[x] -= 1;
				}
			}
			else {
				swDebounce[x] -= 1;
			}
		
		}


		if (lampState[x] == 0)	{						//Light is off?
		
			if (lightStatus) {										//Animations active?
				lamp[x] = lightShow[(lightCurrent << 6) + x];		//64 bytes per frame	
			}
			else {
				lamp[x] = 0;							//This adds a step, but ensures unused lights go OUT when an animation finishes
			}
			
		}
		
		if (lampState[x] == 1)	{						//Light set to blink?
	
			if (blinkTimer < blinkSpeed0) {			
				lamp[x] = 8;			//Light on
			}
			if (blinkTimer > blinkSpeed0) {			
				lamp[x] = 0;			//Light on			
			}
	
		}

		if (lampState[x] == 2)  {						//Light set to pulsate? (0-8, 7-0)
			lamp[x] = pulseLevel;				
		}
		
		if (lampState[x] == 3)	{						//Light set to strobe?

			if (strobeFlag) {		//Did we roll over timer, and ready to strobe?
			
				strobePos[x] += 1;
				
				if (strobePos[x] == strobeAmount[x]) { //(lampState[x] >> 2) - 1) {
					strobePos[x] = 0;				
				}
			
			}
		
			lamp[x + strobePos[x]] = 8;					//Set current strobe light to ON
			//lampState[x + strobePos[x]] = 10;			//Set current light's state to ON
			
			if (strobePos[x] == 0) {
				lamp[x + strobeAmount[x] - 1] = 0;		//Erase last strobe
				//lampState[x + strobeAmount[x] - 1] = 10;		//Set current light's state to OFF
			}
			else {
				lamp[x + (strobePos[x] - 1)] = 0;		//Erase last strobe
				//lampState[x + (strobePos[x] - 1)] = 10;	//Set current light's state to OFF
			}

		}	
	
	}

  //LATGCLR = cLatchBit;              //Pull latch low to load values
  //LATGSET = cLatchBit;              //Reset load   
  
	digitalWrite(clatch, 0); 				//Pull latch low to load values
	digitalWrite(clatch, 1); 				//Reset load    
  
	cabinet = tempCabinet;					//Copy what we got into the actual variable (masking off the bottom)		
	
}


//-------------AV COMMUNICATIONS FUNCTIONS......................

void playSFX(unsigned char whichChannel, unsigned char folder, unsigned char clip0, unsigned char clip1, unsigned char priority) { //0x01

	dataOut[0] = whichChannel;
	dataOut[1] = folder;	
	dataOut[2] = clip0;
	dataOut[3] = clip1;
	dataOut[4] = priority;
	
	sendData(0x01);

}

void playSFXQ(unsigned char whichChannel, unsigned char folder, unsigned char clip0, unsigned char clip1, unsigned char priority) { //0x08	//Sets a flag so this sound plays after current one (in same channel) finishes

	dataOut[0] = whichChannel;
	dataOut[1] = folder;	
	dataOut[2] = clip0;
	dataOut[3] = clip1;
	dataOut[4] = priority;
	
	sendData(0x08);

}

void stereoSFX(unsigned char whichChannel, unsigned char folder, unsigned char clip0, unsigned char clip1, unsigned char priority, unsigned char leftValue, unsigned char rightValue) {	//0x0D

	//Does a "one shot" sound FX at specified stereo pan setting. When sound terminates or replaced, volume levels return to normal

	dataOut[0] = whichChannel;
	dataOut[1] = folder;
	dataOut[2] = clip0;
	dataOut[3] = clip1;
	dataOut[4] = priority;
	dataOut[5] = leftValue;
	dataOut[6] = rightValue;
	
	sendData(0x0D);

}

void video(unsigned char v1, unsigned char v2, unsigned char v3, unsigned char vidAttributes, unsigned char progressBar, unsigned char vP) { //0x02

	if (comboVideoFlag) {						//If the "Combo!" video is playing, enqueue this next file instead
		videoQ(v1, v2, v3, vidAttributes, progressBar, vP);	
		comboVideoFlag = 0;
		return;								//Then abort out of this function
	}

	dataOut[0] = v1;
	dataOut[1] = v2;
	dataOut[2] = v3;
	dataOut[3] = vidAttributes;
	dataOut[4] = progressBar;
	dataOut[5] = vP;
	
	sendData(0x02);

	//Video Attribute Bit Settings:
	//0 = No numbers allowed
	//B00000001 = Small numbers allowed (corners, most allow it for timers)											
	//B00000010 = Large numbers allowed (most will block these)
	//B00000011 = All numbers allowed (probably not used much)
	//B10000000 = Video will loop itself
											
}

void videoCombo(unsigned char v1, unsigned char v2, unsigned char v3, unsigned char vidAttributes, unsigned char progressBar, unsigned char vP) { //0x02

	dataOut[0] = v1;
	dataOut[1] = v2;
	dataOut[2] = v3;
	dataOut[3] = vidAttributes;
	dataOut[4] = progressBar;
	dataOut[5] = vP;
	
	sendData(0x02);

	//Video Attribute Bit Settings:
	//0 = No numbers allowed
	//B00000001 = Small numbers allowed (corners, most allow it for timers)											
	//B00000010 = Large numbers allowed (most will block these)
	//B00000011 = All numbers allowed (probably not used much)
	//B10000000 = Video will loop itself
											
}

void videoQ(unsigned char v1, unsigned char v2, unsigned char v3, unsigned char vidAttributes, unsigned char progressBar, unsigned char vP) { //0x06

	dataOut[0] = v1;
	dataOut[1] = v2;
	dataOut[2] = v3;
	dataOut[3] = vidAttributes;
	dataOut[4] = progressBar;
	dataOut[5] = vP;
	
	sendData(0x06);

}

void customScore(unsigned char v1, unsigned char v2, unsigned char v3, unsigned char vidAttributes) { //0x11	Sets up a custom score display to use as a default during modes

	//Changes default score display to a looping video using numbers 8-11 as the score and other data
	//Send 0,0,0,0 to disable

	dataOut[0] = v1;
	dataOut[1] = v2;
	dataOut[2] = v3;
	dataOut[3] = vidAttributes;
	
	sendData(0x11);

	//Video Attribute Bit Settings:
	//0 = No numbers allowed
	//B00000001 = Small numbers allowed (corners, most allow it for timers)											
	//B00000010 = Large numbers allowed (most will block these)
	//B00000011 = All numbers allowed (probably not used much)
	//B10000000 = Video will loop itself
											
}

void killCustomScore() {

	customScore(0, 0, 0, 0);

}

void killQ() {								//Kills queued videos (including videos with synced sound or numbers) for instances such as ball drains

	videoQ(0, 0, 0, 0, 0, 0);			//Command to kill any queued videos

}

void videoPriority(unsigned char newPriority) { //Manually sets a new priority, such as 0, allowing us to load a new low-priority video such as Skill Shot Loop

	video(255, 0, 0, 0, 0, newPriority);

}

void videoSFX(unsigned char v1, unsigned char v2, unsigned char v3, unsigned char vidAttributes, unsigned char progressBar, unsigned char vP, unsigned char whichChannel, unsigned char folder, unsigned char clip0, unsigned char clip1, unsigned char priority) {

//Enqueues a video synced with a sound that will play after the current VIDEO and SOUND finishes.
//Example: Ghost boss defeated, and you want to remind players that GLIR is lit.
//Play the GHOST DEFEAT video and sound, then videoSoundQ the GLIR prompt
//Once the currently playing video AND sound finishes, enqueued clips play
//Reason for this is sound clips often play longer than video

	dataOut[0] = v1;
	dataOut[1] = v2;
	dataOut[2] = v3;
	dataOut[3] = vidAttributes;
	dataOut[4] = progressBar;
	dataOut[5] = vP;

	dataOut[6] = whichChannel;
	dataOut[7] = folder;	
	dataOut[8] = clip0;
	dataOut[9] = clip1;
	dataOut[10] = priority;
	
	sendData(0x06);

}

void videoControl(unsigned char whatCommand) {	//0x05			//Fine control of video. Backwards, pause, step forward

	dataOut[0] = whatCommand;
	dataOut[1] = 1;				//Which number we're setting
	dataOut[2] = 2;					//Attributes for sprite. 	
	dataOut[3] = 3;						//Position
	dataOut[4] = 4;
	dataOut[5] = 5;
	dataOut[6] = 6;
	dataOut[7] = 7;
	dataOut[8] = 8;
	
	dataOut[15] = 0x05;											//Byte exchange flag (not really required but nice to have)

	for (int x = 0 ; x < 16 ; x++) {							//How many bytes we want to send
	
		dataIn[x] = 0;											//Clear the current dataIn byte
	
		for(int g = 0; g < 8; g++) {    
			digitalWrite(SDO, dataOut[x] & B00000001); 			//Assert the bit 	
			digitalWrite(CLK, 1);								//Pulse the clock
			digitalWrite(CLK, 0);
			dataIn[x] |= digitalRead(SDI) << g;					//Build the incoming data bytes				
			dataOut[x] >>= 1;									//Shift the bits to get the next bit ready. This also auto-deletes the variables!	
		}
	}

}

void stopVideo(unsigned char doWhat) {	//0 Stop (1 or resume?) playing video

	//0 = Stop video
	// 1 = Resume video from where we left off, and finish/loop it (Not implemented yet)

	video(doWhat, 0, 0, 0, 0, 0);

}

void characterSprite(unsigned char whichNumber, unsigned char sprAtt, unsigned char sprX, unsigned char sprY, unsigned long sprHeight, unsigned long sprValue) { //0x04

	dataOut[0] = 3;							//Which graphic type it is (Character Sprite)
	dataOut[1] = whichNumber;				//Which number we're setting
	dataOut[2] = sprAtt;					//Attributes for sprite. 	
	dataOut[3] = sprX;						//Position
	dataOut[4] = sprY;
	dataOut[5] = sprValue;
	dataOut[6] = 0;
	dataOut[7] = 0;
	dataOut[8] = sprHeight;

	dataOut[15] = 0x04;											//Byte exchange flag (not really required but nice to have)

	for (int x = 0 ; x < 16 ; x++) {							//How many bytes we want to send
	
		dataIn[x] = 0;											//Clear the current dataIn byte
	
		for(int g = 0; g < 8; g++) {    
			digitalWrite(SDO, dataOut[x] & B00000001); 			//Assert the bit 	
			digitalWrite(CLK, 1);								//Pulse the clock
			digitalWrite(CLK, 0);
			dataIn[x] |= digitalRead(SDI) << g;					//Build the incoming data bytes				
			dataOut[x] >>= 1;									//Shift the bits to get the next bit ready. This also auto-deletes the variables!	
		}
	}
	
}

void numbers(unsigned char whichNumber, unsigned char numType, unsigned char numX, unsigned char numY, unsigned long numValue) { //0x04

	dataOut[0] = 1;							//Which graphic type it is (numbers)
	dataOut[1] = whichNumber;				//Which number we're setting. 0-7 standard numbers, 8-11 custom score display numbers
	dataOut[2] = numType;					//Send type of number. Default numbers always terminate with currently playing video	
	dataOut[3] = numX;
	dataOut[4] = numY;
	makeLong(5, numValue);
	dataOut[9] = 0;							//Not used here, but we need to clear it in case there's crap in the buffer
	
	sendData(0x04);

	//NumType (4 LSB's):
	//0 = Numbers off. Unless you set the "end flag" you must do this manually to turn off numbers, else they will appear on everything.
	//1 = Large number, XY position (good for score bonus, jackpot values)
    //2 = Small number, XY position. (good for timers, in the screen corners)
	//	  XY positions are ignored for modes 3-5:
    //3 = (2) small numbers, upper left and right corners (good for countdown timers)
    //4 = (2) small numbers, lower left and right corners (good for countdown timers)
    //5 = (4) small numbers, all four corners
	//6 = Small single number, show Double Zeros (such as for a small score)
	//7 = Flash the number after currently playing video ends
	//8 = Show all four scores on right hand side of screen for Match animation
	//9 = Display Ball # at specified number position
	
	//Set Number as Timer:
	//B0001000 OR'd into Numbertype
	
	//FX commands (3 MSB's)
	
	//001xxxxx - Flash the number every other frame
	//010xxxxx - Number displays Player's score (player # determined by number value)
	//100xxxxx - Reserved for future use
	
}

void numbersPriority(unsigned char whichNumber, unsigned char numType, unsigned char numX, unsigned char numY, unsigned long numValue, unsigned char matchPriority) { //0x04

	dataOut[0] = 1;							//Which graphic type it is (numbers)
	dataOut[1] = whichNumber;				//Which number we're setting. 0-7 standard numbers, 8-11 custom score display numbers
	dataOut[2] = numType;					//Send type of number. Default numbers always terminate with currently playing video	
	dataOut[3] = numX;
	dataOut[4] = numY;
	makeLong(5, numValue);
	dataOut[9] = matchPriority;
	
	sendData(0x04);

	//NumType (4 LSB's):
	//0 = Numbers off. Unless you set the "end flag" you must do this manually to turn off numbers, else they will appear on everything.
	//1 = Large number, XY position (good for score bonus, jackpot values)
    //2 = Small number, XY position. (good for timers, in the screen corners)
	//	  XY positions are ignored for modes 3-5:
    //3 = (2) small numbers, upper left and right corners (good for countdown timers)
    //4 = (2) small numbers, lower left and right corners (good for countdown timers)
    //5 = (4) small numbers, all four corners
	//6 = Small single number, show Double Zeros (such as for a small score)
	//7 = Flash the number after currently playing video ends
	//8 = Show all four scores on right hand side of screen for Match animation
	//9 = Display Ball # at specified number position
	
	//Set Number as Timer:
	//B0001000 OR'd into Numbertype
	
	//FX commands (3 MSB's)
	
	//001xxxxx - Flash the number every other frame
	//010xxxxx - Number displays Player's score (player # determined by number value)
	//100xxxxx - Reserved for future use
	
}

void showProgressBar(unsigned char whichGraphic, unsigned char brightBar, unsigned char numX, unsigned char numY, unsigned char lengthBar, unsigned char heightBar) { //0x04

	//Whichgraphic = 0-7 (up to 8 graphic objects such as numbers, progress bars and I guess that's it!)
	//Bright = 0-15
	//X/Y = upper left corner of bar
	//Length Bar = How many pixels to the right from the X position
	//Height Bar = How many pixels down from the Y position

	dataOut[0] = 2;							//Which graphic type it is (progress bar)
	dataOut[1] = whichGraphic;				//Which graphic we're setting
	dataOut[2] = brightBar;					//Must pass along at least a 1 to 15. For 2 bit color, it gets divided down automatically	
	dataOut[3] = numX;
	dataOut[4] = numY;
	dataOut[5] = heightBar;
	dataOut[6] = 0;
	dataOut[7] = 0;
	dataOut[8] = lengthBar;
	
	sendData(0x04);
	
}

void killNumbers() {

	numbers(255, 0, 0, 0, 0);	//Special flag to kill numbers 0-7

}

void killScoreNumbers() {

	numbers(254, 0, 0, 0, 0);	//Special flag to kill numbers 8-11
	
}

void killTimer(unsigned char whichNumber) {		//Terminate a permanent number (usually a timer number)

	numbers(whichNumber, numberStay, 0, 0, 0);

}

unsigned long AddScore(long scoreAmount) {

  unsigned long valueToAdd = (scoreAmount * scoreMultiplier);       //Base value of points

  if (suppressBurst == 0) {                   //A shot that's OK for a burst? Do it!
    
    if (burstReady) {                         //Burst loaded?
      burstReady = 0;                         //Clear flag
      valueToAdd *= ghostBurst;               //Multiple value by GhostBurst
      ghostBurst = 1;							//Now we can clear GhostBurst
      lightningStart(160001);                  //Custom lightshow
      animatePF(430, 30, 0);					//Ghost burst PF animation!
      
      if (ghostBurstCallout) {
        playSFX(2, 'O', 'B', 'C' + random(3), 255);         //Ghost Burst sound effect add    
      }
      else {
        playSFX(2, 'O', 'B', 'B', 255);                    //Ghost Burst sound effect add    
      }   
    }
    
  }
  else {                                //Not a valid Burst Shot. Clear flag for next time
      suppressBurst = 0;    
  }

	playerScore[player] += valueToAdd;                        //Increment player score	
	scoreBall = 1;											  //Flag that points were indeed scored this ball (free ball if you don't)

  if (playerScore[player] > 2147483647) {                   //Did we roll the score?
    playerScore[player] = playerScore[player] - 2147483647; //Roll it over!
    playSFX(2, 'O', 'Z', 'A' + random(4), 255);             //Guess I should tell them what's going on.... :)
  }
  
  SetScore(player);                                         //Send value to Prop

	if (Advance_Enable == 0 or minion[player] > 0) {					//In some sort of mode?
		modeTotal += valueToAdd;			//Increase the Mode Score too
	}
		
	if (playerScore[player] >= replayValue and replayPlayer[player] == 0 and allowReplay > 0) {					//Enough for a replay, and they're allowed?			

		replayPlayer[player] = 1;							//Set flag so this can only happen once
		//video('S', 'R', 'P', 0, 0, 255);					//Replay sound and graphic	
		//playSFX(0, 'A', 'X', 'Z', 255);
		replayGet += 1;
		if (freePlay == 0) {								//Only advance this if it's actually in freeplay mode
			credits += 1;
		}	
		Update(255);		//Send current data, and 255 means Set Replay Notice Flag
	}	

	return valueToAdd;					//In case a display function needs to show the ACTUAL total post-multipliers and Ghost Bursts
	
 }

void SetScore(unsigned char whichPlayer) { //0x03

	dataOut[0] = whichPlayer;							//Which player score will be updated (can also be scores 0, 5, 6, 7 or 8)
	makeLong(1, playerScore[whichPlayer]);

	sendData(0x03);

}

void manualScore(unsigned char whichScore, unsigned long whatValue) { //0x03   Sends a value to a score #. Useful for sending jackpot and other info to score positions not used for players

	dataOut[0] = whichScore;							//Which player score will be updated (can also be scores 0, 5, 6, 7 or 8)
	makeLong(1, whatValue);								//The value

	sendData(0x03);

}

void playMusic(unsigned char group1, unsigned char clip) { //0x05

	if (tiltFlag) {
		return;
	}

	playSFX(3, 'Z', group1, clip, 255);	//Music is like a SFX, but it's always in folder _DZ
	
}

void playMusicOnce(unsigned char group1, unsigned char clip) { //0x05 Sets the MSB to 1, which means play the selected clip, then resume what was playing before

	//Set group1 to 255 to immediately return to paused music
	
	playSFX(3, 'Z', group1 | B10000000, clip, 255);	//Music is like a SFX, but it's always in folder _DZ
		
}

void stopMusic() {

	fadeMusic(0, 0);	//Sending a 0 as the fade timer stops music immediately
	
}	

void volumeSFX(unsigned char whichChannel, unsigned char volLeft, unsigned char volRight) { //0x10

	dataOut[0] = 'f';
	dataOut[1] = whichChannel;	//Which channel
	dataOut[2] = volLeft;		//Set left and right volumes
	dataOut[3] = volRight;		//Set left and right volumes

	sendData(0x10);

}

void fadeMusic(unsigned char fadeSpeed, unsigned char fadeTarget) { //0x10

	dataOut[0] = 'z';		//"m" in ASCII means MUSIC VOLUME CHANGE
	dataOut[1] = fadeSpeed;	//Set left and right volumes
	dataOut[2] = fadeTarget;	//Set left and right volumes
	
	sendData(0x10);

}

void repeatMusic(unsigned char yesOrNo) { //0x10

	dataOut[0] = 'r';		//"r" Set Music repeat
	dataOut[1] = yesOrNo;	//Repeat music (1) or not (0)
	
	sendData(0x10);			//VOLUME command

}

void EOBnumbers(unsigned char whichNum, unsigned long numValue) { //0x0B

	dataOut[0] = whichNum;					//Which bonus # to send (0-4) 4 being "Total Bonus"
	makeLong(1, numValue);					//The number itself

	sendData(0x0B);							//End of Ball Numbers command

	//0 = Area Progress
	//1 = EVPs collected
    //2 = Photos Taken
	//3 = Ghosts Defeated
	//4 = Total Bonus

}

void Update(unsigned char itsState) {

	dataOut[0] = player;
	dataOut[1] = ball;
	dataOut[2] = numPlayers;
	dataOut[3] = credits | (freePlay << 7);
	dataOut[4] = itsState;						//Send a 255 here to set Replay Flag!
	dataOut[5] = showScores;
	dataOut[6] = creditDot;						//Send error flag

	sendData(0x0C);

}

void sendHighScores(unsigned char whichScore) { //0x0E	//Sends the high scores to the Display Processor

	dataOut[0] = whichScore;							//Indicate which high score we're sending (1-6)
	makeLong(1, highScores[whichScore]);				//...Send that score
	dataOut[5] = topPlayers[(whichScore * 3) + 0];		//And the initials
	dataOut[6] = topPlayers[(whichScore * 3) + 1];
	dataOut[7] = topPlayers[(whichScore * 3) + 2];
	
	sendData(0x0E);										//Send a high score and initials
	
}

void sendInitials(unsigned char whichPlayer, unsigned char whichPlace) { //0x0F

	dataOut[0] = whichPlayer;				//Which player it is for (Send a 0 to terminate initial entry display)
	dataOut[1] = cursorPos;					//Position of cursor (0-2)
	dataOut[2] = inChar;					//Which character is under the cursor
	dataOut[3] = initials[0];				//What player has entered
	dataOut[4] = initials[1];
	dataOut[5] = initials[2];
	dataOut[6] = whichPlace;				//What place on board they earned

	sendData(0x0F);							//Initial entry display.
	
}

int value(unsigned char xPos, unsigned char yPos, unsigned long theValue) { //0x12 Puts up to a 6 digit value on screen at X Y block positions (0-15 0-3)

	dataOut[0] = (xPos << 4) | yPos;					//Send BCD XY position (0-15, 0-3)
	
	int numerals = 0;						//Always going to be at least 1 numeral
	int zPad = 0;							//Flag for zero padding	
	unsigned long divider = 100000;			//Divider starts at 100k
		
	for (int xx = 0 ; xx < 6 ; xx++) {		//6 digit number		
		if (theValue >= divider) {
			dataOut[numerals + 1] = '0' + (theValue / divider);
			theValue %= divider;
			zPad = 1;
			numerals += 1;
		}		
		else if (zPad or divider == 1) {
			dataOut[numerals + 1] = '0';
			numerals += 1;
		}	
		divider /= 10;						
	}	

	dataOut[numerals + 1] = 0;							//Ensure this is a 0 for string termination

	sendData(0x12);

	return numerals;
	
}

void text(unsigned char xPos, unsigned char yPos, const char *str) { //0x12 Puts up to 14 characters on screen at X Y block positions (0-15 0-3)

	dataOut[0] = (xPos << 4) | yPos;		//Send BCD XY position (0-15, 0-3)

	int x = 14;
	int xx = 1;
	
	while (x--) {							//Send up to 14 characters, or terminate when string hits a 0	
		dataOut[xx++] = *str++;
		if (*str == 0) {					//End of string? End!
			x = 0;
		}	
	}

	sendData(0x12);							//Text display
	
}

void graphicsMode(unsigned char doWhat, unsigned char theModifier) { //0x13

	dataOut[0] = doWhat;
	dataOut[1] = theModifier;

	sendData(0x13);			//Graphics mod command
	
}

void loadSprite(unsigned char clip0, unsigned char clip1, unsigned char clip2, unsigned char doLoad) { //0x14

	dataOut[0] = clip0;
	dataOut[1] = clip1;
	dataOut[2] = clip2;
	dataOut[3] = doLoad;

	sendData(0x14);

}

void sendSwitches() { //0x15	Sends the switch matrix + cab switches to the display

	for (int x = 0 ; x < 8 ; x++) {		//Copy switch matrix	
		dataOut[x] = switches[x];	
	}
	
	dataOut[8] = cabinet & B11111110;	//Send low byte of cabinet (excluding bit 0)
	dataOut[9] = cabinet >> 8;			//Send high byte of cabinet

	sendData(0x15);
	
}

void writeEEPROM(unsigned long whichAddress, unsigned long whatValue) { //0x20

	int writeSuccess = 0;	
	int timeOutCounter = 0;
	
	while (writeSuccess < 10) {								//Don't give up until successful write
		
		makeLong(0, whichAddress);							//Which address to write to (0-8191)
		makeLong(4, whatValue);								//What long value to write

		sendData(0x20);										//Command to write EEPROM long at location
		
		delay(10);

		timeOutCounter = 5;									//Can't do a possible infinite loop so set a timeout in cycles - will wait up to 20ms

		while (timeOutCounter) {							//Keep exchanging data until we get a complete frame we want, or a timeout occurs

			exchangeData();
				
			if (dataIn[15] == 0x42) {								//Did we get indicator that write function has finished?	
				break;														//Got what we wanted, jump out of loop
			}
			
			timeOutCounter -= 1;											//Decrement timer

		}	
		
		clearInputBuffer();									//Make sure what we get back is clean (no extra characters)

		if (readEEPROM(whichAddress) == whatValue) {
			//Serial.println("Write verified!");
			break;	
		}
		
		writeSuccess += 1;
		
		//Serial.println("Write fail, re-trying...");
		
	}

}

int readEEPROM(unsigned long whichAddress) { //0x21

	makeLong(0, whichAddress);
	dataOut[14] = eepromChecksum;								//Send 7 bit eepromChecksum counter along with packet
	sendData(0x21);												//Send the EEPROM request to Prop

	delay(10);
	exchangeData();
	
	int timeOutCounter = 5;										//Can't do a possible infinite loop so set a timeout in cycles - will wait up to 20ms

	while (timeOutCounter) {									//Keep exchanging data until we get a complete frame we want, or a timeout occurs
	
		delay(10);												//Give EEPROM time to load
	
		exchangeData();
			
		if (dataIn[14] == (eepromChecksum | B10000000) and dataIn[15] == B10101101) {		//Complete frame, and the checksum matches with the MSB added by Prop?		
			break;														//Got what we wanted, jump out of loop
		}
		
		timeOutCounter -= 1;											//Decrement timer

	}

	eepromChecksum += 1;												//Increment the checksum for next time...
	
	if (eepromChecksum > 127) {											//...and keep it 7 bit, and never zero
		eepromChecksum = 1;
	}

	return dataIn[0] | (dataIn[1] << 8) | (dataIn[2] << 16) | (dataIn[3] << 24);	//Parse the bytes we got back into a nice, fat, juicy long
	
}

void showValue(unsigned long numValue, unsigned int flashTime, unsigned int scoreFlag) {	//Show a number after currently playing video and add it to the score

	//Adds numValue to score
	//If a new video is activated before this number is shown, number will not be shown

	if (scoreFlag) {
		numValue = AddScore(numValue);		//Increase the score, and get the final result returned so multipliers show correctly
	}
	
	makeLong(0, numValue);					//The number itself
	dataOut[4] = flashTime;
	
	sendData(0x07);							//End of Ball Numbers command

}

void exchangeData() {											//Sends the 16 bytes of command data to the Propeller, and gets 16 bytes back

	dataOut[15] = 0xFF;											//Byte exchange flag (not really required but nice to have)

	for (int x = 0 ; x < 16 ; x++) {							//How many bytes we want to send
	
		dataIn[x] = 0;											//Clear the current dataIn byte
	
		for(int g = 0; g < 8; g++) {    
			digitalWrite(SDO, dataOut[x] & B00000001); 			//Assert the bit 	
			digitalWrite(CLK, 1);								//Pulse the clock
			digitalWrite(CLK, 0);
			dataIn[x] |= digitalRead(SDI) << g;					//Build the incoming data bytes				
			dataOut[x] >>= 1;									//Shift the bits to get the next bit ready. This also auto-deletes the variables!	
		}
	}

}  

void clearInputBuffer() {	//0x22								//Clears the data output buffer on the Propeller side so extra bytes aren't present in next transfer

	sendData(0x22);												//Send the EEPROM request to Prop
	
}

void sendData(unsigned char commandCode) {						//Sends the 16 bytes of command data to the Propeller. Bytes are sent back but we don't read them (faster)

	dataOut[15] = commandCode;									//The final byte is always the command byte

	for (int x = 0 ; x < 16 ; x++) {							//How many bytes we want to send
		for(int g = 0; g < 8; g++) {    
			digitalWrite(SDO, dataOut[x] & B00000001); 			//Assert the bit 	
			digitalWrite(CLK, 1);								//Pulse the clock
			digitalWrite(CLK, 0);								
			dataOut[x] >>= 1;									//Shift the bits to get the next bit ready. This also auto-deletes the variables!	
		}
	}

}

void makeLong(unsigned char loc, unsigned long theValue) {		//Converts a 4 byte long into sequential dataOut[x] bytes

	dataOut[loc + 0] = theValue & B11111111;
	dataOut[loc + 1] = (theValue >> 8) & B11111111;	
	dataOut[loc + 2] = (theValue >> 16) & B11111111;	
	dataOut[loc + 3] = (theValue >> 24) & B11111111;	

}

extern "C"
{

void __ISR(_TIMER_2_VECTOR, ipl6) LightDriver(void) {

	lightGap++;

	if (lightGap == 2) {
		LATB = 0;
	}
	
	if (lightGap == 3) {
	
    lightGap = 0;
    lightData[lightCol] = 0;						//Clear byte so we can build a new one
    lightRowBit = 1;							//Reset build byte to 1
    
    for (int gx = 0 ; gx < 8 ; gx++) {				//Loop 8 times
    
      if (lamp[lampnum++] > lightPWM) {			  //Increment lamp #, Is the current lamp value greater than PWM?
        lightData[lightCol] |= lightRowBit;		//If so, add current row bit.
      }

      lightRowBit <<= 1;						//Shift build bit to the next position
    
    }

    LATB = (lightData[lightCol] << 8) | lightColBit; //Set Port B to the light row & column output data
	
    lightCol++;  							//Increase light row number, decimal
    lightColBit <<= 1; 							//Shift bit row trigger to the left
  
    if (lightCol == 8) {						//Did we reach the end of a frame?
	
      lightCol = 0;								//Reset Column # numeral
      lightColBit = 1;							//Reset Column # bit
      lampnum = 0;							//Reset lamp # to zero (since we completed a frame)
      
      lightPWM++;							//Increment PWM counter
      
      if (lightPWM == 8) {						//Did we reach the end?
        lightPWM = 0;							//Reset PWM counter	  
      }
	  
    }	

	}

  mT2ClearIntFlag();  // Clear interrupt flag

}


void __ISR(_TIMER_3_VECTOR, ipl3) SwitchDriver(void) {

  LATD = switchrowbit;                              //Set switch active column 
 
  delayMicroseconds(1);                             //Give registers time to latch new values 

  switches[switchrow] = ~PORTD;                     //Get new values, invert them

  switchrow += 1;                                   //Increase light row number, decimal
  switchrowbit <<= 1;                               //Shift bit row trigger to the left 
  
  if (switchrow == 8) {                             //Did we reach the last row?
    switchrow = 0;                                  //Reset decimal row#
    switchrowbit = (B11111110 << 8 ) + B11111111;   //Reset binary
  } 

  
  for (int x = 0 ; x < 24 ; x++) {
	if (SolTimer[x]) {							//Active solenoid? 
		if (SolTimer[x] < ReadCoreTimer()) {	//Did system timer exceed our variable?
		digitalWrite(SolPin[x], 0);				//Turn off solenoid
		SolTimer[x] = 0;						//Turn off timer check
		}
	}  
  }
  
  LATD = 0;                              			//Clear active columns until next time (avoids opto false triggers)
   
  mT3ClearIntFlag();                                // Clear interrupt flag

}  

}

