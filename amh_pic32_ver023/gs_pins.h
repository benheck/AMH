//America's Most Haunted
//Variables and Constants Definitions

#define cycleMilliSecond 12
#define cycleSecond		12000					//How many kernel cycles per second
#define cycleSecond2    24000
#define cycleSecond3    36000
#define cycleSecond4    48000
#define cycleSecond6    72000

#define longSecond		15000					//How many cycles appx a "long" second for timers

//RGB port-level access---------------------------------------------------------------------------

#define RGBClockBit   0x04					//Pin definitions for the external RGB lighting clock
#define RGBDataBit		0x02					//Pin definitions for the external RGB lighting data

#define popScore		10000
#define advanceScore	50000
#define comboScore		75000
#define startScore		250000
#define winScore		1000000
#define loopSecondsAdd	3						//How many seconds you gain in Photo Hunt by shooting the loop

//Modify NumberType
#define numberScore		B01000000			   //Draws number as Player (Number Value's) score. Use to build custom score displays 
#define numberFlash		B00100000
#define numberStay		B00010000
#define returnPixels    B00100000              //Before drawing this character, place the existing left and rightmost pixels in the Outbuffer data return buffer 

//Modify Video Type
#define	loopVideo       B10000000              //Should video start over after it ends?
#define preventRestart  B01000000              //If video called is already playing, don't restart it (just let it keep playing)
#define noEntryFlush    B00100000              //Do not flush graphics on video start (for instance, to have a number appear on an enqueued video)
#define noExitFlush     B00010000              //Do not flush graphics on video end
#define allowBar		B00000100			   //Can show Progess Bar during a video?
#define allowLarge      B00000010              //Can show large numbers on the video?
#define allowSmall      B00000001              //Can show small numbers on the video?
#define allowAll		B00000011			   //Allow both large and small numbers on the video
#define manualStep		B00001000			   //Video frames must be advanced manually

//Graphic Mode Commands
#define clearScreen		B10000000				//Erase buffer
#define loadScreen		B01000000				//Load buffer into display memory

//Attract Mode Starting Points
#define highScoreTable	2						//Jump to High Score Table in attract mode
#define lastGameScores	7						//Jump to Last Scores
#define holdTourneyScores 15					//Jump to Last Scores, hold on screen for 20 seconds to write down

//loopCatch Bits
#define catchBall		B00000001				//Flag that means try and catch the ball next time it comes in the loop
#define checkBall		B00000010				//Flag that we're checking if ball actually caught
#define ballCaught		B10000000				//Flag that the ball has been caught in the loop

//Multiball Bits
#define multiballLoading		B00000001		//Bit that says multiball is loading
#define	multiballLoaded			B00000010		//Bit that says all balls have been loaded for MB
#define multiballMinion    		B10000000		//Bit that says this is a Minion Multiball!
#define multiballHell			B01000000		//Bit that says this is a Hellavator Multiball! (it can be both!)

#define minionWon     B00000001         //Sub wizard mode enable bits
#define photoWon      B00000010
#define mbWon         B00000100
#define subWizReady   B10000111         //Is sub mode ready?
#define subWizStarted B10001111         //Has it been started?
#define subWizWon     B10101111         //A winner is you!

#define popSS         B01000100         //Pops skill shot bits
#define orbSS         B00100010         //ORB skill shot bits
#define helSS         B00010001         //Hell skill shot bits
#define allSS         B01110111         //All skill shot bits

#define hospitalBit   B00000010
#define theaterBit    B00000100
#define barBit        B00001000
#define warBit        B00010000
#define hotelBit      B00100000
#define prisonBit     B01000000
#define allWinBit     B01111110
#define jackpotBit    B10000000

unsigned long orbitDelta = 0;

unsigned char endingQuote = 0;			//If Easter Egg quote, suppress the usual end of ball quote
unsigned char ghostBurst = 0;       //Burst multiplier. If ADDSCORE 
unsigned char burstReady = 0;       //If rollover hit, set this flag to 1. Next score will be X ghostBurst!

unsigned char burstLane = 0;        //Which lane is lit for GHOST BURST
unsigned char suppressBurst = 0;    //Rollovers is a LAME way to get a burst. This flag prevents that from happening

unsigned char modeToBit[] = {0, 1, 5, 2, 3, 4, 0};   //Set the index here to MODE, and it tells how many bits to shift over to light the Back Panel Ghost that matches mode
unsigned long panelBlinker = 0;     //Used to blink ghosts on rear panel

unsigned char bumpGhosts = 0;            //How many ghosts left to beat in Bumps in the Night
unsigned char bumpHits = 0;             //How many hits left to beat the ghost in Bumps
unsigned char bumpWhich = 0;            //Which spot currently holds the Bump Ghost
unsigned char bumpType = 0;             //What the Bump Ghost looks like 0-3
unsigned long bumpValue = 0;            //What you get for current ghost. Faster you hit, more you score!

unsigned char adultMode = 1;				//Disables some of the worst lines. To some extent. A little.
unsigned char middleWarBar = 0;     		//Should middle shot advance pops (war/bar) and if so, how many?
unsigned char winMusic = 1;         //What music to play when a ghost is defeated. 1 = Most Haunted, 2 = Ghost Squad, 3 = Chuck Rap

unsigned char orbSlings = 20;				//How many sling hits it takes to spot an ORB letter?

int coinDoorState = 99;						//If coin door is open (1) or not (0) or don't know (99)
int coinDoorDetect = 0;						//Whether or not we care if the door is open or not (1 = care, 0 = don't. Use 0 for games without a door switch)

unsigned char skip = 0;						//If NOT ZERO, a skippable event is occurring. The value indicates which event is occurring, so the system knows what to do if player chooses to skip

unsigned char tiltFlag = 0;					  //If a tilt occurred
unsigned char tiltCounter = 0;				//How many warnings you got
unsigned char tiltLimit = 3;				  //Warning limit
unsigned char tiltTenths = 6;         //Default is .6 seconds (integer version) Multiply by 1200 to get cycle value

int whichMenu = 1;							  //Which menu we are in
int whichSelection = 9;						//What is selected. When menu loads default is 9 (Game Settings)
int menuAbortFlag = 0;						//If you try to enter the menu during a game, it sets this flag, ends game, and puts you back in the main loop
unsigned char audioSwitch = 0;				//Speaks which switch has been tested, in case your PF is in front of DMD

unsigned char dataOut[16];					//What we're sending to the Propeller
unsigned char dataIn[16];					//We can get up to 16 bytes at a time from the Propeller
unsigned char eepromChecksum = 1;			//Location 14 on the output buffer. When EEPROM data is fetched, same number is placed in location 14 of returned data

unsigned char pulses = 0;       //Total Pulse count. Clear after each game to "eat" the remainder
unsigned char pulsesPerCoin = 3;    //How many pulses one coin gives      
unsigned char pulsesPerCredit = 8;  //How many pulses it takes to create one credit
unsigned char credits = 0;       		//How many credits in the machine

unsigned char ghostBurstCallout = 1; //Should the Ghost Burst play the voice clip?

unsigned char freePlay = 1;					//If the machine is Free Play or not (default = TRUE)
unsigned char coinsIn = 0;					//How many coins you've inserted. Once it equals coinsPerCredit, a credit is awarded!
unsigned char coinsPerCredit = 1;			//Good old 25 cents per game!

unsigned char creditDot = 0;				//A flag that says there's a problem with the game
unsigned long replayValue = 50000000;		//Free credit if player exceeds this score
unsigned char replayPlayer[5];				//Flag if a player has acheived a replay this round
unsigned char allowReplay = 1;				//If game awards replays or not (default is YES)
unsigned char allowMatch = 1;				//If we should do match animation at end of game

unsigned long gamesPlayed = 0;				//Total games played since last reset
unsigned long ballsPlayed = 0;				//Counts balls played to compute average ball time
unsigned long totalBallTime = 0;			//Total seconds a ball is in play. Divide by ballsPlayed to get average
unsigned long averageBallTime = 1;			//Calculate and store here
unsigned short secondsCounter = 0;			//Counts seconds to add to totalBallTime
unsigned long extraBallGet = 0;				//How many extra balls have been earned
unsigned long replayGet = 0;				//How many replays have been earned
unsigned long matchGet = 0;					//How many matches succeeded
unsigned long coinsInserted = 0;			//How many coins / tokens inserted

unsigned short dollars = 0;					//Displays Earnings
unsigned char cents = 0;					//Displays Earnings

unsigned char debugSwitch = 0;
unsigned char ballSearchEnable = 1;						//If we should look for balls or no

unsigned long gameRestart = 0;          //Hold START to count this up and when it reaches X amount game restarts

// Mode-specific variables------------------------------------------

unsigned char Mode[5];									//What mode is currently active.
unsigned char ModeWon[5];								//What modes player has won
unsigned char subWon[5];                //Bit 7 = Enable check, Bit 2 = MB, bit 1 = Photo, bit 0 = Minion. Complete those 3 to light SUB WIZARD MODE
unsigned char modeRestart[5];						//What modes player is eligible to restart Binary B01111110 like Mode Won
unsigned long restartTimer = 0;							//Timer for seconds
unsigned char restartSeconds = 0;						//Timer for Restart
unsigned char restartMode = 0;							//What mode we're trying to restart, so game knows what to "kill" if they miss
unsigned char popMode[5];								//What the pop bumber is advancing for each player. ( 1 is fort, 2 is bar)
unsigned char popActive = 0;							//If any pop was hit during a cycle
unsigned char tourBits = 0;								//Set the 4 LSB's in this to "tour" the haunted locations and enable bonus perks (just like COD!)
unsigned char tourTotal = 0;							//Counts the bits we've hit
unsigned char tourLights[6];							//Which tour lights should be on. We keep a copy here so Combo Timeouts won't erase Tour Shots
unsigned char tourComplete[5];							//Which tours the player has completed. Do all 6 for SUPER POINTS!
unsigned char Advance_Enable = 1;						//Default is 1. Set to 0 if a Ghost Battle is in progress.
unsigned short loopCatch = 0;							//Used for catching balls in the Ghost Loop and making sure they're caught before proceeding

// Hellvator Multiball-------------------------------

unsigned char multipleBalls = 0;						//A flag that says a mode is using multiple balls, but isn't a Minion or Hellavator multiball. Confusing, I know
unsigned char multiBall = 0;							//Multiball. Bit 7 = Minion MB, Bit 1 = All balls launched Bit 0 = Launching Balls
unsigned char hellMB = 0;								//Flag used to tell Hell MB apart from Minion MB (also if we can catch ghosts or not)
unsigned char catchValue = 0;							//How many times you've caught all 4 in multiball (adds multiplier)
unsigned char lockCount[5];								//How many balls have been soft locked in the Hellavator
unsigned char hellFlashFlag = 0;          //Flag to do a lighting effect when the hellavator reaches the top or bottom
unsigned char multiCount = 0;							//How many balls the game should auto-launch for a Multiball
unsigned long multiTimer = 0;
unsigned long hellJackpot[5];							//Starting MB jackpot value
unsigned char hitsToLight[5];							//How many times you have to press "Call" before hellavator moves / lights for lock							
unsigned char callHits = 0;								//How many times you've hit Call this ball (resets per player)

// Video Mode---------------------

unsigned char videoMode[5];								//1 = Mode Ready! 10 = Mode ready when current mode ends 100 = Instruction Screen 101 = Started!
int ghostY = 0;											//Y position of ghost
unsigned char videoModeEnable = 1;						//If Video Mode can be started or not. I sure hope not. I hate video modes!
unsigned char videoCount = 0;
unsigned short videoSpeed = 0;							//Speed at which the video advances
unsigned char videoCycles = 0;
unsigned long frameNumber = 0;							//Which frame of video we are on
unsigned char vidBank = 0;								//What we're loading next, A or B
unsigned char videoSpeedStart = 4;						//Default speed at which the video advances

// Team Member Spelling & Ghost Minions -------------------------------

unsigned char wiki[5];
unsigned char tech[5];
unsigned char psychic[5];
unsigned long scoringTimer = 0;							//How long DOUBLE SCORING will go on
unsigned char minionDamage = 1;							//How much damage you cause per hit minion
unsigned char minion[5];								//The state of the Minion fight per player
unsigned char minionTarget[5];							//How many hits to beat the minion
int minionHits = 0;										//How many times you've hit the minion. Resets on mode start / ball loss. Is signed if you go below 0 with double damage
unsigned char minionsBeat[5];							//How many minions the player has beaten
unsigned char minionHitProgress[5];						//Saves how many hits you previously got on a Minion if you start another mode before beating him
unsigned char minionMB = 0;								//Flag to keep track of Minion Multiball
unsigned long minionJackpot = 0;						//What current Jackpot is
#define minionMB1	2									//Which Minions give MB (Needs to be 1 below, IE, if third minion gives MB, set to 2, for 9th, set to 8
#define minionMB2	8

unsigned char comboSeconds = 0;							//How many seconds combos are lit for. Can be changed in menu
unsigned int comboTimerStart = 72000;					//Cycle counter for how long combos are lit. Default = 6 seconds
unsigned char comboVideoFlag = 0;						//If a combo was hit, this flag makes it so the next video is enqueued (so we see COMBO + normal shot video)
unsigned char comboCount = 1;							//How many combos player has made
unsigned int comboTimer = 0;							//Time left to get a combo
unsigned char comboShot = 0;							//Which Camera Shot has the combo lit (0-5)
unsigned char comboEnable = 0;							//0 = No combos allowed (some modes) 1 = Combos OK! (mode modes, but check!)

unsigned char hellLock[5];								//If you can lock balls in the Hellavator or not
unsigned char spiritGuide[5];							//If spirit guide is lit, and what was awarded if you shoot it
bool spiritGuideActive = 0;								//During multi-ball and some other things, Spirit Guide is disabled
unsigned char spiritProgress[5];							//If in tourney mode, this tracks players progress through spirit guide (but still skip awards they've already claimed)

#define	teamWiki	B10000000							//Bit values for teamMod flags
#define teamTech	B01000000
#define teamTech	B01000000
#define teamPsychic B00100000

unsigned char EVP_Target = 10;							//How many pops to get an EVP
unsigned char popCount = 0;								//How many pops we have
unsigned char EVP_Total[5];								//How many EVP's each player has collected
unsigned char EVP_EBtarget[5];							//How many EVP's each player must get to earn Extra Ball
unsigned char EVP_EBsetting = 10;						//Defaults to 10, can be changed in menu if I remember to add it in			
unsigned long EVP_Jackpot[5];							//Jackpot value per player.
unsigned char jackpotMultiplier = 0;					//Current multiplier for the mode
unsigned int photosTaken[5];							//Total photos a player got.
unsigned int areaProgress[5];							//How many mode-advancing shots each player has made
unsigned int ghostsDefeated[5];							//Total ghosts defeated per ball
unsigned char orb[5];									//Which ORB roll over lanes have been hit
unsigned long bonus = 0;								//Total bonus at end of ball
unsigned char bonusMultiplier = 0;						//Multipliers per ball
unsigned char scoreMultiplier = 1;						//Can be used for double scoring and stuff. Right now just for Psychic Scoring
unsigned char zeroPointBall = 1;						//If you score zero points on a ball 1 means you get it back, 0 means too bad sucker!
unsigned char demonMultiplier[5];						//Flag for Demon Mode multiplier
unsigned char achieve[5];								    //Flag for what acheivements the player did. Each one adds a multiplier to Demon Battle

//General Mode Variables------------------------------------------

unsigned char gTargets[3];								//Which of the Ghost Targets have been cleared.
unsigned char targetBits = 0;							//Which targets have NOT been cleared (starts at B00000111)
unsigned char targetsHit = 0;							//How many of the 3 targets you have hit
unsigned long saveStart = 50000;						//The default amount of ball save time, in seconds
unsigned char saveCurrent[5];							//How much Save Start time each player has (can be increased during game)
unsigned long saveTimer = 0;							//Timer for Ball Save
unsigned short scoopSaveStart = 1510;					//Ball save time, in milliseconds, when ball is ejected from scoop (default 1.5 seconds)
unsigned char scoopSaveWhen = 0;          //0 = scoop save always works 1 = doesn't work in Multiball (since there's usually a save there anyway)
unsigned long drainTimer = 0;							//Timer for events after a ball drain
long modeTimer = 0;										//Timer for stuff in modes, like random taunts and hurry ups
unsigned long displayTimer = 0;							//Timer for display actions
unsigned char skillShot = 0;							//If skill shot is enabled, and which one we're going for
unsigned char skillShotComplete[5];						//Check to see if a player makes all 3 unique Skill Shots during a game
unsigned char launchCounter = 0;						//For debug purposes. Counts how many times it's tried to load the ball
signed long skillScoreTimer = 0;						//Counts past the skill shot animation (4 seconds) and then counts cycleSecond * numberPlayers to show the scores. Then loops back to run the video again (single player works as normal)

//Hospital - Mode 1

unsigned char hosProgress[5];
unsigned char hosTrapCheck = 0;							//Flag if a ball search has to occur and kick out the VUK
unsigned char DoctorState = 0;							//0 = Guarding door, 1 = Distracted
int DoctorTimer = 0;									//Count up timer. When it reaches limit, ghost moves back towards door a bit.
int DoctorTarget = 0;									//Target amount before move. With each hit, ghost moves a little faster.
int DoctorSeconds = 0;									//Hurry-up timer display. Not really in seconds.
unsigned char doctorHits = 0;							//Only prompt on Doctor hits every 3 times
unsigned char patientStage = 0;							//What stage of Ghost Patient you're at
unsigned char patientsSaved = 0;						//How many you saved, through Murder!
unsigned char badExit = 0;								//If = 0, then ball ejected properly, rolled down habitrail and hit left inlane switch

unsigned char flipperAttract = 1;						//Flag to disable the Flipper Attract when ball return in Hospital Fail (Default on)

//Theater - Mode 2

unsigned char theProgress[5];							//The progress in Theater Mode
unsigned long sweetJumpBonus = 0;						//How many points you get for SWEET JUMPS
unsigned char sweetJump = 0;							//How many JUMPS you've done (directs what video plays)
unsigned long shotValue = 0;							//Keeps track of what next shot is worth. Decrements each second.
#define TheaterTime	21									//16 seconds, plus some slop for the display

//Bar - Mode 3

unsigned char spotProgress = 0;							//What level the pops start at (0 - 12 spot halfway)
unsigned char barProgress[5];							//How many pops have advanced the Bar
unsigned char whoreJackpot = 0;							//How many Jackpots on Ghost Whore.
unsigned char kegsStolen = 0;							//How many kegs have been stolen!

//War Fort - Mode 4

unsigned char fortProgress[5];							//How many pops have advanced in the Fort Mode
unsigned char soldierUp = 0;			
unsigned char warHits = 0;
unsigned char goldHits = 0;								//How many hits on the door
unsigned long goldTimer = 0;							//How long to get the gold!
unsigned long goldTotal = 0;							//How much you collected
#define GoldTime	21									//20 SECONDS TO COLLECT GOLD

//Hotel - Mode 5

unsigned char hotProgress[5];
unsigned char ControlBox[6];							//Flag to set where the random control box is, and where we've checked already
unsigned char HellBall = 0;								//Status of what the ball in the Hellavator is doing.
unsigned char hellCheck = 0;							//Used to check if a ball is stuck in the Hellavator

//Prison - Mode 6

unsigned char priProgress[5];
unsigned char Tunnel = 0;								//Did the ball just roll through the tunnel? Used for Basement Scoop switch logic
unsigned char teamSaved = 0;							//How many members we've saved
unsigned char convictState = 0;							//Freeing convict ghosts. 1 = Need to open door 2 = Need to shoot scoop
unsigned char convictsSaved = 0;						//How many you've saved. Maybe we use this for a bonus or something

//Ghost Photo Hunt - Mode 7

unsigned char rollOvers[5];								//GLIR rollover targets. Use LSB's
unsigned long rollOverValue[5];           				//Each player's GLIR rollover value
unsigned char GLIR[5];									//Flag if GLIR is lit and can be started
unsigned char GLIRneeded[5];							//How many times each player must spell GLIR to light Photo Hunt
unsigned char GLIRlit[5];								//If GLIR is lit for a player. If MSB bit set, prevents it from being started (usually when a Minion is active)
unsigned char photosToGo = 0;							//How many photos left to collect (from 9-0 to 3-0)
unsigned char photosNeeded[5];							//Number of photos each player must collect. (starts at 3)
int photoTimer = 0;										//Timer used just for photo mode!
unsigned char countSeconds = 0;							//How many seconds left. Used for other modes, too
unsigned char photoLocation[6];							//What shots have valid photos
unsigned char photoCurrent = 0;							//Which location (0-5) currently has the photo
unsigned char photoLights[] = {7, 14, 23, 31, 39, 47};  //The lamp number of the Camera Icons, from left to right
unsigned char photoStrobe[] = {4, 6, 3, 5, 3, 4};		//How many south of Camera icon that you can strobe
unsigned char photoSecondsStart[5];						//How many seconds you get to collect a photo
unsigned long photoValue = 0;							//Current value of photos (decreases every second!)
unsigned char photoPath[] = {1, 3, 0, 2, 4, 5, 1, 3, 0, 1, 0};//Sequence in which to make the shots if in Tournament Mode (with overflow just in case)
unsigned char photoWhich = 0;							//How many we've taken per round of Photo Hunt (used to guide tourney path)
unsigned long photoAdd[5];               //Add-on points to Photo Hunt shot values


//Demon Battle - Mode 10

unsigned char deProgress[5];							//How far you are through the mode
unsigned char demonLife;								//How weak Demon is

					 //Switch 0.........................................7 Was 9999 and 5000
unsigned short swDBTime[] = {5000, 9999, 5000, 5000, 5000, 5000, 5000, 5000,
							 5000, 5000, 5000, 5000, 5000, 5000, 5000, 5000,
							 5000, 5000, 5000, 5000, 5000, 5000, 1000, 1000,
							 9999, 9999, 5000, 5000, 5000, 5000, 5000, 9999,
							 5000, 5000, 5000, 2500, 2500, 1000, 5000, 5000,
							 5000, 5000, 5000, 10000, 5000, 1000, 1000, 5000,     //Bumped up ball in hellavator switch to allow combos to it
							 5000, 5000, 2500, 5000, 5000, 2500, 5000, 5000,
							 1000, 9000, 1000, 1000, 1000, 1000, 1000, 1000};
					 //Switch 56........................................63
//Sets the debounce time per switch. The switch must be off XXX cycles before it can be re-triggered
//Note how most are 5000 (standard) but slings are slower (9999), pops are faster (2500)

						//Switch 0.........................................7
unsigned short swRampDBTime[] = {200, 200, 200, 200, 200, 200, 200, 200,
								200, 200, 200, 200, 200, 200, 200, 200,
								50, 50, 10, 10, 10, 200, 200, 200,
								5, 200, 200, 200, 10, 50, 50, 100,
								50, 50, 50, 10, 10, 10, 20, 20,
								100, 100, 100, 200, 200, 10, 10, 200,
								50, 50, 5, 200, 200, 5, 50, 50,
								200, 5000, 200, 10, 10, 10, 10, 200,};
						//Switch 56........................................63
//Sets the ramp-up per switch. The switch must be on XXX many cycles in order to register a hit
//The ramp-up time on the Ball Load Good switch is always higher

#define trapSwitchSlow		5000	//When finding balls, the "slow" reaction time for switches
#define trapSwitchNormal	200		//The default switch ramp time for trapped balls

					 //Switch 0.........................................7
unsigned char swClearDB[] =    {0, 0, 0, 0, 0, 0, 0, 0,
								0, 0, 0, 0, 0, 0, 0, 0,
								0, 0, 0, 0, 0, 0, 1, 1,
								0, 0, 0, 0, 0, 0, 0, 0,
								0, 0, 0, 0, 0, 1, 0, 0,
								0, 0, 0, 0, 0, 1, 1, 0,
								0, 0, 1, 0, 0, 1, 0, 0,
								0, 0, 0, 0, 0, 0, 0, 0,};
						//Switch 56........................................63
//1 = 


#define switchfreq		2000							//How often switch data gets sent up to PC. 40MHz system timer (half the speed of CPU freq) / 500 times a second
#define optoDebounce	5000
#define switchOnTime	100
#define flipperDebounce 50

unsigned long switchDead = 0;								//Timer to check to see if the ball is stuck
#define deadTopDefault			12							//Old default is 16 seconds
#define searchTimerDefault		4000						//Cycles between coil whacks in ball search. 2000-6000 is a good range
#define sendChase				3							//How many times to try a ball search during a game before sending out a chase ball

unsigned char chaseBall	= 0;								//Flag if a chase ball has been sent
unsigned char deadTopSeconds = deadTopDefault;				//This is the actual "in seconds" number we would change. EEPROM stores it in seconds but is calculated into cycle time on settings load
unsigned long deadTop = (deadTopSeconds * cycleSecond);		//Base default values, can be changed in settings
unsigned long searchTimer = searchTimerDefault;
unsigned char searchAttempts = 0;							//How many times we've tried to find the ball during a game

//opCode Definitions----------------------------------------------------

#define op_Blink		1
#define op_Pulse		2
#define op_Strobe		4

#define op_Switches			B00111110						//The opcode for sending / receiving switch data
#define op_EOL				B11111111						//End of opcode transmission.
#define op_AutoEnable		B00111011						//Enables automatic flippers, slings, pops, etc.

#define EnableServo   	 	B00010000						//Opcodes for enabling automatic event handling on playfield
#define EnableVUK      		B00001000						//Set each bit for what you'd like to enable
#define EnableSlings   		B00000100
#define EnablePops    		B00000010
#define EnableFlippers 		B00000001

//Light driver variables-------------------------------------------------

int RGBClock = 35;									//Pin definitions for the RGB cabinet lighting
int RGBData = 36;									//Pin definitions for the RGB cabinet lighting

#define extRGBData     B00000010				//Port definitions E1 (second bit)
#define extRGBClock		 B00000100				//Port definitions E2 (third bit)

#define defaultR	128								//Default "mode 0" colors (medium white)
#define defaultG	128
#define defaultB	128
#define tempLamp	5								//Memory area for temp light animations

unsigned long lightningTimer = 0;					//To flash some lightning
unsigned char lightningGo = 0;						//If a lightning effect is occuring
int lightningPWM = 0;								//For PWM lightning FX
unsigned char leftRGB[3];							//RGB colors of left cabinet GI
unsigned char rightRGB[3];							//RGB colors of right cabinet GI
unsigned char cabModeRGB[3];						//The default colors of the cabinet for each Mode (not the same as generic white default colors)
unsigned char targetRGB[3];							//RGB color the cabinet lighting is trying to get to

long RGBtimer = 0;									//Times how quickly the RGB changes (100 cycles is good)
long RGBspeed = 0;									//How quickly it changes

unsigned char ghostRGB[3];							//The current RGB color of the ghost
unsigned char ghostModeRGB[3];						//What color the ghost should be for the mode

unsigned char rgbSwap[] = {1, 2, 1};				//Green second, blue third - Or Blue second, green third					   
unsigned char rgbType = 0;							//Standard light configuration (green second, blue third)

unsigned long ghostFadeTimer = 0;					//Flag for if the ghost should fade
unsigned long ghostFadeAmount = 0;					//What amount the timer should reset to

unsigned char ghostGreen = 1;						//Default Green light is the second variable
unsigned char ghostBlue = 2;						//Default Blue light is the third variable

unsigned short GIword = 0;							//The general illumination that will get sent out

unsigned short animationTimer = 0;					//How many kernel cycles before animation advances
unsigned short lightStart = 0;						//What frame # the PF animation starts on									
unsigned short lightCurrent = 0;					//What frame # the PF animation is currently on
unsigned short lightEnd = 0;						//Last frame in this animation. When lightCurrent++ > lightEnd, we revert to lightStart
unsigned char lightStatus = 0;						//Control byte for insert light animations

#define animationTarget	800							//12,000 HZ / 15 FPS = 800 kernel cycles per light frame
#define lightAnimate	B10000000					//Bit 7 enables animation
#define lightLoop		B01000000					//Bit 6 causes animation to loop back to lightStart until disabled

unsigned char lightData[8]; 						//Bits of each byte control the lights, for a total of 64. What actually gets output to the pins.
unsigned char lightCol = 0; 						//Current Column byte we are displaying (rows = bits)
unsigned char lightColBit = 1; 						// Shifts left with each row to trigger Darlingtoin arrays
unsigned char lightRowBit = 1;						//Used to build each byte of Column data
unsigned short lightGap = 0;						//Ghost-busting gap
unsigned short lightPWM = 0; 						//PWM Timer for lights
#define	lightcyclefreq	8000 						//Number of times per second to run the light routine (8000 / 8 columns / 8 cycles PWM = 125 HZ)

unsigned char lamp[65];                             //PWM values for all 64 lights
unsigned char lampState[65];						//What state each light is in 0 = standard, 1 = blink, 2 = strobe + 3, 4 = pulsate
unsigned char strobeAmount[65];
unsigned char lampPlayers[321];						//Stores a player's lamps
unsigned char statePlayers[321];					//Stores a player's lamp states
unsigned char strobePlayers[321];					//Stores a player's strobe states
unsigned char lampnum = 0;                          //Which lamp we are computing at the moment (used in interrupt)
unsigned char lightNumber = 0;						//The lamp number pulled from the op code

unsigned int pulseDir = 0;							//What direction the pulse is going
unsigned int pulseLevel = 0;						//Current pulse level (for all lights)
unsigned int pulseTimer = 0;						//Timer for the pulses
unsigned int strobePos[65];							//Which lamp the stobe is on (0 = target, 2 = third)
unsigned int strobeTimer = 0;
unsigned int blinkTimer = 0;						//Timer for blinking the lights

unsigned long dirtyPoolTimer = 0;					//Checks if a ball is stuck under the ghost. Check this after modes where it's possible.
unsigned char dirtyPoolChecker = 1;					//If the game should check for Dirty Pool. Modes that want to trap the ball should set this to 0 until complete.
unsigned char trapTargets = 0;						//If a ball is trapped behind targets, set this flag so ball search won't release it
unsigned char trapDoor = 0;							//Flag that a ball is to be held behind the door in the VUK (Hospital Mode / Demon locks)

unsigned long LeftTimer = 0;
unsigned char LeftPower = 0;
unsigned long RightTimer = 0;
unsigned char RightPower = 0;

unsigned long centerTimer = 0;						//Avoid double hits on Pop Bumper Path, and supresses video on Pops
unsigned long popsTimer = 0;						//If ball rolls out of pops, keeps Center Shot from triggering
unsigned long rampTimer = 0;						//Avoids double hits on the Ramp Approach switch
unsigned long orbTimer = 0;							//Avoids false scores on Balcony Approach switch

unsigned char slingCount[5];						//Counts the Sling Hits. Dialog once at 4 hits, resets when Timer is zero

unsigned char lightSpeed = 1;						//How fast blinks, pulsates and strobes occur. Depends on kernel speed too. Default = 1

#define strobeSpeed 1000							//Number of cycles before the strobe advances
#define pulseSpeed 500								//Number of cycles before the pulse changes values
#define blinkSpeed0 2000							//Number of cycles before the blink changes
#define blinkSpeed1 4000							//Number of cycles before the blink changes

//-----------------------------------------------------------------------

//Switch driver variables-------------------------------------------------

unsigned char switches[8]; 							//Eight switches (bits) per byte, total of 64
unsigned char switchrow = 0; 						//Current row of lights in decimal.
unsigned short switchrowbit = (254 << 8 ) + 255; 	// Shifts left with each row to trigger Darlingtoin arrays
unsigned char xColumn = 0;							//Used for numeric switch decoding.
unsigned char xBit = 0;
unsigned short cabinet = 0;							//Shift register cabinet input destination variable						
unsigned short tempCabinet = 0;						//Temp variable used to read in the bits
unsigned short tempGIout = 0;						//Temp variable used to shift out the GI light bits
unsigned short swDebounce[64];						//Debounce timer for all matrixed switches.
unsigned short switchStatus[64];					//State of the matrixed switches

unsigned short cabDebounce[16];						//Debounce timer for all dedicated switches.
unsigned short cabStatus[16];						//State of the dedicated switches

unsigned char tens = 0;								//Used to slice up numbers
unsigned char ones = 0;

//-----------------------------------------------------------------------

unsigned char command[6];							//Holds the commands from the serial bus. Commands are 6 bytes, we have 2 extra bytes to eat a CR LF if needed
unsigned char commandByte = 0;						//Which byte of the command we're currently filling (0-5)
unsigned char messageFlag = 0;						//Flag that we're getting a valid message
unsigned char itemType = 0;							//ASCII character telling us what item type it is (lights, MOSFETs, etc)
unsigned char itemNumber = 0;						//Which thing to set
unsigned char itemParameter = 0;					//What to set it to


//Gameplay Variables & Timers----------------------------------------------------

//ALL TIMERS MUST BE UNSIGNED SO AS NOT TO INVOKE NEGATIVE VALUES!

unsigned int LeftVUKTime = 0;						//Kickout timer for left VUK (behind door)
unsigned int ScoopTime = 0;							//Kickout timer for Basement Scoop

int LeftOrbitTime = 0;								//Timer that lefts us know which way the ball is going on Left Orbit.
int UpperOrbitTime = 0;								//Timer after upper switch hit on orbit. Used to avoid double advance on Prison Lock

int LFlipTime = -1;							//Timer for flipper high current
int RFlipTime = -1;							//Timer for flipper high current

int LholdTime = 0;							//Timers for hold coil PWM
int RholdTime = 0;							//Timers for hold coil PWM

int leftDebounce = 0;						//Flipper buttons don't use the built-in Cabinet Button Debounce
int rightDebounce = 0;						//These variables do it manually

unsigned long plungeTimer = 0;				//Timer for Autoplunging!
unsigned char ballQueue = 0;				//If another ball is added DURING a plunge timer event. Unlikely, but possible.

//-----------------------------------------------------------------------

unsigned char startAnyway = 0;				//If insufficient balls, 3 start attempts will start a game
unsigned char ballsInGame = 0;				//Flag if a ball is missing. If 2 balls missing, service your game asshole

unsigned char drainSwitch = 63;				//Which ball counter switch acts as drain
unsigned char tournament = 0;				//If game is in Tournament Mode or no (1 = YES 0 = NO)
unsigned char ball = 0;         			//Starts at ball 1, should ball = 4 game is over (man)
unsigned char ballsPerGame = 4;				//At which ball count the game ends. Should be the # of balls you want, plus 1. (so for a 1 ball game it'd be 2)
int activeBalls = 0;						//How many balls are on the playfield
unsigned char extraBalls = 0;				//Flag that gives current player an extra ball after drain / bonus
unsigned char allowExtraBalls = 1;			//Should game allow extra balls?
unsigned char extraLit[5];					//If player has an Extra Ball lit or not
unsigned char scoreBall = 0;				//Whetever or not a player scored on a ball or not
unsigned long playerScore[5];				//Each player's score. Use 1-4, skipping 0   
unsigned char numPlayers = 0;      			//Total # of players in the game
unsigned long loadChecker = 0;				//On first load, makes sure ball fully loaded.
unsigned long modeTotal = 0;				//Total points you made in a mode
unsigned char showScores = 0;				//Don't show scores during attract mode until there's been a game completed

unsigned char startingAttract = 1;			//When machine resets, which part of the Attract Mode it should goto
unsigned char attractLights = 1;			//If the machine should do lighting Attract Mode. Usually yes, but disabled in Debug Mode
unsigned char player = 0;					//Player currently playing
unsigned char run = 0;          			//What state the machine is in during attract and game start modes
unsigned long kickTimer = 0;				//How long before a ball is kicked out of the drain
unsigned short kickPulse = 0;				//To pulse the kicker coil
unsigned char kickFlag = 0;					//Flag that says ball has been kicked from the drain. Keeps Ball Switch 4 from accidentally triggering a double drain					

unsigned char pPos[4];						//Sorts the scores at the end of a game 0 = highest, 3 = lowest
unsigned long highScores[5];				//Best [0] and 5th [4]
unsigned char initials[3];					//What has been entered on the initial screen
unsigned char topPlayers[15];				//The top players initials
unsigned char inChar = 65;					//Which character the player is entering
unsigned char cursorPos = 0;				//Cursor position of character entry (0-2) Hitting START on character 2 finishes entry

//-----------------------------------------------------------------------
                                                         
#define drainStart	100000

unsigned char ghostLook = 1;		//Should the ghost look at shots as they're made?
unsigned long ghostAction = 0;		//Timer / control for making the ghost do things.
unsigned long ghostBored = 0;		//After looking someplace, eventually the ghost gets bored and turns back to center.

unsigned long MagnetTimer = 0;		//How long should the magnet stay on? Negative values used to add english spin
unsigned long MagnetCount = 0;		//This is used to PWM the magnet.
unsigned char magFlag = 0;			//If the magnet should be pulsing or not during the timer
unsigned char magEnglish = 1;   //Should the ball be given a tug when released?

unsigned char HellLocation = 0;		//Location of the Hellavator
unsigned char HellTarget = 0;		//Where were are trying to move the elevator
unsigned long HellSpeed = 0;		//Speed (in cycles) to move elevator, set to 0 to indicate target acquired
unsigned long HellTimer = 0;		//Counts cycles between moves
unsigned long HellSafe = 0;			//Checks if ball successfully exits Hellavator

unsigned char DoorLocation = 0;		//Location of the Spooky Door
unsigned char DoorTarget = 0;		//Where were are trying to move the door to
unsigned long DoorSpeed = 0;		//Speed (in cycles) to move door, set to 0 to indicate target acquired
unsigned long DoorTimer = 0;		//Counts cycles between moves
unsigned long doorCheck = 0;		//Checks for ball traps during ball search

unsigned char TargetLocation = 0;	//Location of the Target
unsigned char TargetTarget = 0;		//Where were are trying to move the Target
int TargetDelay = 0;				//How long until the targets start moving
unsigned long TargetNewSpeed = 0;	//What speed to set once Delay Timer is up
unsigned long TargetSpeed = 0;		//Speed (in cycles) to move Target, set to 0 to indicate target acquired
unsigned long TargetTimer = 0;		//Counts cycles between moves

unsigned char GhostLocation = 0;	//Rotation of Ghost.
unsigned char ghostTarget = 0;		//Where we want the ghost to go
unsigned int ghostSpeed = 0;		//How often the ghost changes location
unsigned int ghostTimer = 0;		//Timer to set Ghost Speed

unsigned char sfxVolume[2];			//Volume of SFX
unsigned char musicVolume[2];		//Volume of the left and right channels
unsigned char lastMusic[2];			//What music WAS playing
unsigned char currentMusic[2];		//What music is currently playing
unsigned char sfxDefault = 25;		//Default SFX volume
unsigned char musicDefault = 20;	//Default music volume

unsigned char leftVolume = 100;		
unsigned char rightVolume = 10;

unsigned long SolTimer[24];									//32 bit system-based timer for solenoids
unsigned char AutoEnable = 0;                      //Which solenoids can auto-fire with PC commands  

//unsigned short coilSettings[] = {300, 15, 15, 10, 30, 30, 0};		//Flipper, Slings, Pops, Left Vuk, Right Scoop, Autolauncher, etc...	
	
unsigned short coilDefaults[] = {9, 5, 9, 8, 2, 9, 5, 2, 0};				//Flipper, Slings, Pops, Left Vuk, Right Scoop, Autolauncher, Load strength, Drain kick strength, null
unsigned short coilSettings[] = {9, 5, 9, 8, 2, 9, 5, 2, 0};				//Flipper, Slings, Pops, Left Vuk, Right Scoop, Autolauncher, Load strength, Drain kick strength, null					   

#define autoPlungeFast	25005							//What setting gives an "instant" autoplunge
#define autoPlungeSlow	35005							//Slower version

unsigned char autoPlungeCheck = 0;						//If an autoplunge should wait for drained ball to be kicked back into trough before loading

//-------------------------Define Game Settings. Production Game Only-------------------------------------------------------------------


//Variable (User Changeable) Coil Settings------------------------------

unsigned short FlipPower = 300; 						//Default flipper high power winding ON time, in cycles
unsigned short SlingPower = 15;							//How hard the slings hit	
unsigned short PopPower = 15;                       	//Default auto power for pop bumpers
unsigned short vukPower = 10;							//Power of the left VUK behind door
unsigned short scoopPower = 30;							//Power of the right basement scoop	
unsigned short plungerStrength = 30;					//How hard the autolauncher kicks it out
unsigned short loadStrength = 6;						//How hard the ball loader is
unsigned short drainStrength = 12;						//15 How hard it gets out of drain

unsigned char drainTries = 0;							//If a drain kick doesn't work, this increments and is added to the Drain Strength until all 4 balls are loaded

unsigned short drainPWMstart = 5850;					//When to switch from Drain Kick power kick to PWM hold

//Static Coil / Magnet Settings-----------------------------------------
//#define loadStrength	10							//How hard the ball loader is
//#define drainStrength	10							//15 How hard it gets out of drain
#define holdTop			50 //250					//Used to PWM the hold coil on flippers
#define holdHalf		25 //125					//Save a calculation later	
#define magPWM			100 //350					//How many cycles between magnet pulses to hold it on
#define magFlagTime		2							//How many MS long each magnet cycle pulse is (stay under 10 else it's always on)


//Sets the ramp-up per switch. The switch must be on XXX many cycles in order to register a hit	
unsigned short cabRampDBTime[] = {200, 200, 200, 5, 5, 200, 200, 200, 			//unused, Door, User0, RFlip, LFlip, Menu, Enter, Coin
								  12, 0, 5, 200, 200, 2, 2, 200,}; 				//Tilt, ghostOpto, doorOpto, unused, Start, ghostOpto, doorOpto, unused

//Sets the debounce time per switch. The switch must be off XXX cycles before it can be re-triggered
unsigned short cabDBTime[] = {200, 200, 200, 200, 200, 200, 200, 200,	  			//unused, Door, User0, RFlip, LFlip, Menu, Enter, Coin
							  7500, 2500, 7500, 200, 200, 5000, 7500, 200,};		//Tilt, ghostOpto, doorOpto, unused, Start, ghostOpto, doorOpto, unused


//-----Assign Solenoid Pin #'s to a logic number listing
								//NEW    NEW
unsigned char SolPin[] = {22, 23, 32, 25, 31, 30, 2, 4, 7, 11, 12, 70, 71, 72, 73, 75, 78, 79, 80, 81, 82, 83, 84, 85};
//Solenoid pin #'s assigned to an array (0-23)

//		sol0
#define Magnet			0
#define sol1			1	//GI 1
#define sol2			2	//GI 2
#define sol3			3	//GI 3
#define sol4			4
#define sol5			5
#define leftBackglass	6
#define rightBackglass	7

#define LSling			8 //
#define RSling			9 //
#define ScoopKick		10 //
#define LeftVUK			11 //
#define sol12			12
#define Bump0			13
#define Bump1			14
#define Bump2			15

#define RFlipHigh		78 //   //These need to be set to actual PIN#'s, not solenoid #'s.
#define RFlipLow		79 //   //These need to be set to actual PIN#'s, not solenoid #'s.
#define LFlipHigh		80 //   //These need to be set to actual PIN#'s, not solenoid #'s.
#define LFlipLow		81 //    //These need to be set to actual PIN#'s, not solenoid #'s.

#define LoadCoil		20	// //Ball Load
#define drainKick		21	//Drain Kick (Unused on Ben's prototype)
#define Plunger			22	// //Plunger
#define sol23			23
//      sol23

#define solenable       28
#define solenableBit  0x8000

//-------------------------------------------------------------------

//Inter-processor communication pins------------------

#define ATN			14
#define SDI			14
#define CLK			15
#define SDO			16

//-----------------------------------------------------------------------

//Cabinet switch shift register inputs------------------

#define cdatain			45
#define cclock			37
#define clatch			43
#define GIdata			29

#define GIdataBit     0x80
#define cClockBit     0x01
#define cLatchBit     0x100

#define startLight		13

//Shift register bit # declarations (New Pinheck System)------------

#define	Door				   1
#define	User0				   2
#define	RFlip 				   3
#define	LFlip 				   4
#define	Menu				   5
#define	Enter				   6
#define	Coin				   7
#define	Tilt				   8
#define TCBDTWN7			   9
#define TCBDTWN6			   10
#define TCBDTWN5			   11
#define	Start				   12

#define ghostOpto			   13 //TCBDTWN #1 / Opto 1
#define doorOpto			   14 //TCBDTWN #2 / Opto 2

#define	StartLight			   51

//-----------------------------------------------------------------------


//Servo Connections on the Aux Board--------------------------------------

#define HellServo			0
#define DoorServo			1
#define GhostServo			2
#define Targets				3

//Servo Position Constants-----------------------------------------------

#define TargetDownDefault	160
#define TargetJog			40
#define TargetUpDefault		5			
#define hellUpDefault		160
#define hellStuck			60
#define hellDownDefault		10
#define DoorOpenDefault		5
#define DoorClosedDefault	90
#define GhostDistracted		120			//Where the ghost turns to when distracted (decreases each time) Make sure it's a multiple of 20 + GhostAtDoor
#define GhostMiddle			70			//Halfway back to the Spooky Door
#define GhostAtDoor			20			//Ghost guarding the Spooky Door.

#define subwayTime			15000		//Amount of time it takes for ball to exit hellavator and hit Middle Subway Switch

//---------------------------------------------------------------------

//Servo User Variables----------------------------------------------------

unsigned char TargetDown = TargetDownDefault;				//Set these to defaults on load
unsigned char TargetUp = TargetUpDefault;
unsigned char hellUp =  hellUpDefault;
unsigned char hellDown = hellDownDefault;
unsigned char DoorOpen = DoorOpenDefault;
unsigned char DoorClosed = DoorClosedDefault;

int settingsState = 0;								//0 = Selecting servo, 1 = Changing servo
	

//Subway Switch Numbers

#define subUpper		35
#define subLower		36
