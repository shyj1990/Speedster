#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
static BOOL isOnSpringBoard;
// -1 means "don't touch the system value". Starting at 0.0 would make
// emptySwitcherDismissDelay return a 0s delay before setResponse: ever runs,
// causing the switcher animation to be recomputed constantly (high CPU on iOS 17).
static double SwitcherDismiss = -1;

// static Class CASpringAnimationClass = Nil;
// static Class SBFAnimationSettingsClass = Nil;

static BOOL isSpeedEnable;
static BOOL isBounceEnable;
static int Speedvalue;
static int Bouncevalue;
static BOOL isFineTuneSpeedEnable;
static BOOL isFineTuneBounceEnable;
static double FineTuneSpeedValue;
static double FineTuneBounceValue;

static BOOL isFolderAnimationEnabled;
static BOOL isFolderAnimationBounceEnabled;
// static double FolderInitialVelocityValue;
// static double FolderSpeedValue;
// static double FolderStiffnessValue;
static double FolderMassValue;
static double FolderDampingValue;

static BOOL inAppAnimationEnabled;
static BOOL inAppAnimationBounceEnabled;
// static double InitialVelocityValue;
// static double VelocityValue;
// static double StiffnessValue;
static double MassValue;
static double DampingValue;
static double DurationValue;

static BOOL isScreenwakeEnable;
static BOOL isScreensleepEnable;
static double Screensleepvalue;
static double Screenwakevalue;

static BOOL isNoiconflyEnable;
static BOOL isNoiconshakingEnable;
static BOOL isNoiconZoominSwitcher;
static BOOL isNoWallZoominSwitcher;
static BOOL isInstantFolder;

void preferencesthings(){ //pref starts to look THICC
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.hoangdus.speedsterprefs"];

    //app close/open values
    isSpeedEnable = (prefs && [prefs objectForKey:@"isSpeedEnable"] ? [[prefs valueForKey:@"isSpeedEnable"] boolValue] : NO );
    isBounceEnable = (prefs && [prefs objectForKey:@"isBounceEnable"] ? [[prefs valueForKey:@"isBounceEnable"] boolValue] : NO );
    Speedvalue = (prefs && [prefs objectForKey:@"Speedvalue"] ? [[prefs valueForKey:@"Speedvalue"] integerValue] : 1 );
    Bouncevalue = (prefs && [prefs objectForKey:@"Bouncevalue"] ? [[prefs valueForKey:@"Bouncevalue"] integerValue] : 1 );
    isFineTuneSpeedEnable = (prefs && [prefs objectForKey:@"isFineTuneSpeedEnable"] ? [[prefs valueForKey:@"isFineTuneSpeedEnable"] boolValue] : NO );
    isFineTuneBounceEnable = (prefs && [prefs objectForKey:@"isFineTuneBounceEnable"] ? [[prefs valueForKey:@"isFineTuneBounceEnable"] boolValue] : NO );
    FineTuneSpeedValue = (prefs && [prefs objectForKey:@"FineTuneSpeedValue"] ? [[prefs valueForKey:@"FineTuneSpeedValue"] doubleValue] : 1 );
    FineTuneBounceValue = (prefs && [prefs objectForKey:@"FineTuneBounceValue"] ? [[prefs valueForKey:@"FineTuneBounceValue"] doubleValue] : 1 );

    //screen sleep/wake values
    isScreenwakeEnable = (prefs && [prefs objectForKey:@"isScreenwakeEnable"] ? [[prefs valueForKey:@"isScreenwakeEnable"] boolValue] : NO );
    isScreensleepEnable = (prefs && [prefs objectForKey:@"isScreensleepEnable"] ? [[prefs valueForKey:@"isScreensleepEnable"] boolValue] : NO );
    Screensleepvalue = (prefs && [prefs objectForKey:@"Screensleepvalue"] ? [[prefs valueForKey:@"Screensleepvalue"] doubleValue] : 0.01 );
    Screenwakevalue = (prefs && [prefs objectForKey:@"Screenwakevalue"] ? [[prefs valueForKey:@"Screenwakevalue"] doubleValue] : 2 );

    //folder values
    isFolderAnimationEnabled = (prefs && [prefs objectForKey:@"isFolderAnimationEnabled"] ? [[prefs valueForKey:@"isFolderAnimationEnabled"] boolValue] : NO );
    isFolderAnimationBounceEnabled = (prefs && [prefs objectForKey:@"isFolderBounceEnabled"] ? [[prefs valueForKey:@"isFolderBounceEnabled"] boolValue] : NO );
    // FolderInitialVelocityValue
    // FolderSpeedValue = (prefs && [prefs objectForKey:@"FolderVelocityValue"] ? [[prefs valueForKey:@"FolderVelocityValue"] doubleValue] : 1 );
    FolderDampingValue = (prefs && [prefs objectForKey:@"FolderDampingValue"] ? [[prefs valueForKey:@"FolderDampingValue"] doubleValue] : 0 );
    FolderMassValue = (prefs && [prefs objectForKey:@"FolderMassValue"] ? [[prefs valueForKey:@"FolderMassValue"] doubleValue] : 0 );
    // FolderStiffnessValue = (prefs && [prefs objectForKey:@"FolderStiffnessValue"] ? [[prefs valueForKey:@"FolderStiffnessValue"] doubleValue] : 1 );
    
    //extra
    isNoiconflyEnable = (prefs && [prefs objectForKey:@"nofly"] ? [[prefs valueForKey:@"nofly"] boolValue] : NO );
    isNoiconZoominSwitcher = (prefs && [prefs objectForKey:@"nozoom"] ? [[prefs valueForKey:@"nozoom"] boolValue] : NO );
    isNoWallZoominSwitcher = (prefs && [prefs objectForKey:@"noWPzoom"] ? [[prefs valueForKey:@"noWPzoom"] boolValue] : NO );
    isNoiconshakingEnable = (prefs && [prefs objectForKey:@"noshaking"] ? [[prefs valueForKey:@"noshaking"] boolValue] : NO );
    isInstantFolder = (prefs && [prefs objectForKey:@"InstantFolder"] ? [[prefs valueForKey:@"InstantFolder"] boolValue] : NO );
}

void inAppSpeedPreferences(){
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.hoangdus.speedsterprefs"];

    //in-app values
    inAppAnimationEnabled = (prefs && [prefs objectForKey:@"InAppAnimationEnabled"] ? [[prefs valueForKey:@"InAppAnimationEnabled"] boolValue] : NO );
    inAppAnimationBounceEnabled = (prefs && [prefs objectForKey:@"isInAppBounceEnabled"] ? [[prefs valueForKey:@"isInAppBounceEnabled"] boolValue] : NO );
    // InitialVelocityValue
    // VelocityValue = (prefs && [prefs objectForKey:@"VelocityValue"] ? [[prefs valueForKey:@"VelocityValue"] doubleValue] : 1 );
    DampingValue = (prefs && [prefs objectForKey:@"DampingValue"] ? [[prefs valueForKey:@"DampingValue"] doubleValue] : 0 );
    MassValue = (prefs && [prefs objectForKey:@"DurationMassValue"] ? [[prefs valueForKey:@"DurationMassValue"] doubleValue] : 0 );
    // StiffnessValue = (prefs && [prefs objectForKey:@"StiffnessValue"] ? [[prefs valueForKey:@"StiffnessValue"] doubleValue] : 1 );
    DurationValue = (prefs && [prefs objectForKey:@"DurationMassValue"] ? [[prefs valueForKey:@"DurationMassValue"] doubleValue] : 0 );
}

static void preferencesChanged(){ //runs at load and every time the prefs darwin notification fires
    preferencesthings();
    inAppSpeedPreferences();
}

//reverse number to make sliders go from left to right lol
//
//All spring-related mappings below are EXPONENTIAL (not linear): perceived
//speed follows a logarithmic curve, so a linear track made one 1% step at the
//fast end change the animation 3-7x more than the same step at the slow end.
//With a constant-ratio curve, 1% of the track feels the same everywhere.
//NOTE: saved slider values shift meaning once (re-set your sliders after update).
static double reverseSpeedSliderValue(double input){ //track 0.05..0.40 -> response 0.40..0.05
    double f = (input - 0.05) / 0.35; //0 = slowest end, 1 = fastest end
    f = MIN(MAX(f, 0.0), 1.0);
    return 0.40 * pow(0.125, f); //8x total range -> constant 1.04% duration change per 1% track
}

static double reverseBounceSliderValue(double input){ //track 0.2..1.0 -> dampingRatio 0.9..0.1
    double f = (input - 0.2) / 0.8;
    f = MIN(MAX(f, 0.0), 1.0);
    return 0.9 * pow(0.1111, f); //9x total range -> uniform bounce feel per step
}

static double reverseTurnOffSpeed(double input){
    double total = 0.91;
    return total - input; //plain fade duration: linear is perceptually fine
}

static double reverseAppSpeedSliderValue(double input){ //track 0..0.99 -> stock multiplier 1.0..0.1
    double f = input / 0.99;
    f = MIN(MAX(f, 0.0), 1.0);
    double value = pow(0.1, f); //10x total range -> constant ratio per step
    //Floor the multiplier: values below 0.1 make CASpringAnimation parameters
    //pathological (tiny mass/damping), which on iOS 17 + ProMotion (120Hz)
    //keeps springs recomputing frames and burns CPU.
    if (value < 0.1) {
        value = 0.1;
    }
    return value;
}

static double reverseFolderSliderValue(double input){ //track 0..0.9 -> stock multiplier 1.0..0.1
    double f = input / 0.9;
    f = MIN(MAX(f, 0.0), 1.0);
    return pow(0.1, f); //same constant-ratio curve as the in-app sliders
}


//Volume HUD exemption ---------------------------------------------------------------
//The stock volume HUD animates with the same SBFFluidBehaviorSettings that the app
//open/close hooks modify, so it inherited the tweaked speed (it disappeared
//abnormally fast). SpringBoard announces every volume change right before the HUD
//(re)shows, and the HUD's show+hide animations are all configured within a couple
//of seconds after that, so fluid settings touched during this short "active"
//window belong to the volume HUD and must pass through unmodified.
static NSInteger volumeHUDGeneration = 0;
static BOOL volumeHUDActive = NO;

//------------------------------------------------------------------------------------

//Root cause found via 2.1.6 log evidence: the volume HUD reads fluid settings objects
//whose setters are NEVER called during the volume event (vcStack=0 for every call), so
//it animates with whatever value those objects carried from an earlier (tweaked)
//configuration - the exemption window alone can never help. Fix: remember the original
//(caller-requested) value of every settings object we touch, and on each volume event
//restore those stock values into the live objects before the HUD reads them. The next
//app animation re-configures its own objects and gets tweaked values as usual.
static NSMapTable *stockResponseValues;      //weak key: settings object -> NSNumber (caller-requested response)
static NSMapTable *stockDampingRatioValues;  //SBFFluidBehaviorSettings
static NSMapTable *stockDampingValues;       //SBFAnimationSettings
static NSMapTable *stockMassValues;
static NSLock *stockValuesLock;
static BOOL restoringForHUD = NO;

//Boot grace window: SpringBoard subsystems that freeze animation timing derived from
//fluid settings (the volume HUD's auto-hide delay is computed once at launch from the
//then-current response and never re-read) must see STOCK values at init, or they cache
//a poisoned copy that no amount of restoring can reach. No rewriting while the grace is
//active; the only cost is that app animations right after a respring run at stock speed.
//The grace ends 1s after applicationDidFinishLaunching returns: the v2.1.4-4 diagnosis
//proved all freeze reads happen synchronously inside that method. Floors: 2.5s absolute
//(the burst starts ~2s after load), 15s ceiling fallback if the launch signal never fires.
static CFAbsoluteTime tweakLoadTime = 0;
static CFAbsoluteTime springBoardDidFinishLaunchingTime = 0;
static BOOL bootGraceArmed = NO;

static BOOL bootGraceActive(void){
    if (!isOnSpringBoard || bootGraceArmed) return NO;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if ((now - tweakLoadTime) < 2.5) return YES; //absolute floor: burst starts ~2s after load
    //Device-verified (v2.1.4-4/-5 logs): every freeze read happens synchronously INSIDE
    //applicationDidFinishLaunching (+1s..+3s, via PrototypeTools), so ending the grace
    //1s after that method returns covers them deterministically (~3.6s total on A17).
    if (springBoardDidFinishLaunchingTime != 0) {
        if ((now - springBoardDidFinishLaunchingTime) < 1.0) return YES; //launch just completed
        bootGraceArmed = YES;
        return NO;
    }
    if ((now - tweakLoadTime) > 15.0) { //fallback if the launch signal never fired
        bootGraceArmed = YES;
        return NO;
    }
    return YES;
}

//Silence the compiler for restore calls: the hooked setters exist at runtime on the
//recorded objects, but the compiler only knows them from the %hook context.
@interface NSObject (SpeedsterFluidSettings)
- (void)setResponse:(double)arg1;
- (void)setDampingRatio:(double)arg1;
- (void)setDamping:(double)arg1;
- (void)setMass:(double)arg1;
@end

static void initStockMaps(void){
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        stockResponseValues = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory | NSMapTableObjectPointerPersonality valueOptions:NSMapTableStrongMemory];
        stockDampingRatioValues = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory | NSMapTableObjectPointerPersonality valueOptions:NSMapTableStrongMemory];
        stockDampingValues = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory | NSMapTableObjectPointerPersonality valueOptions:NSMapTableStrongMemory];
        stockMassValues = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory | NSMapTableObjectPointerPersonality valueOptions:NSMapTableStrongMemory];
        stockValuesLock = [NSLock new];
    });
}

static void recordStockValue(NSMapTable *map, id object, double value){
    if (!isOnSpringBoard) return;
    initStockMaps();
    [stockValuesLock lock];
    [map setObject:@(value) forKey:object];
    [stockValuesLock unlock];
}

static void restoreStockValuesForHUD(void){
    if (!isOnSpringBoard) return;
    initStockMaps();
    [stockValuesLock lock];
    restoringForHUD = YES; //hooks pass straight through to %orig while restoring
    for (id obj in stockResponseValues) {
        NSNumber *v = [stockResponseValues objectForKey:obj];
        if (v) [(id)obj setResponse:[v doubleValue]];
    }
    for (id obj in stockDampingRatioValues) {
        NSNumber *v = [stockDampingRatioValues objectForKey:obj];
        if (v) [(id)obj setDampingRatio:[v doubleValue]];
    }
    for (id obj in stockDampingValues) {
        NSNumber *v = [stockDampingValues objectForKey:obj];
        if (v) [(id)obj setDamping:[v doubleValue]];
    }
    for (id obj in stockMassValues) {
        NSNumber *v = [stockMassValues objectForKey:obj];
        if (v) [(id)obj setMass:[v doubleValue]];
    }
    restoringForHUD = NO;
    [stockValuesLock unlock];
}

static void noteVolumeHUDActivity(void){
    volumeHUDActive = YES;
    restoreStockValuesForHUD();
    NSInteger generation = ++volumeHUDGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (volumeHUDGeneration == generation) volumeHUDActive = NO;
    });
}

//App Open animation and bouncing
%hook SBFFluidBehaviorSettings
    -(void)setResponse:(double)arg1{ //App open and close speed
        if(restoringForHUD){ %orig; return; }
        if(isOnSpringBoard){
            recordStockValue(stockResponseValues, self, arg1);
            if(bootGraceActive()){
                %orig;
                return;
            }
        }
        if(volumeHUDActive){ //stock volume HUD: keep untouched, don't disturb switcher state
            %orig;
            return;
        }
        if(isSpeedEnable){
            if(!isFineTuneSpeedEnable){
                //Change speed value base on selector pos
                switch (Speedvalue){
                case 1:
                    %orig(0.37);
                    SwitcherDismiss = 0.2;
                    break;
                case 2: 
                    %orig(0.25);
                    SwitcherDismiss = 0.17;
                    break;
                case 3:
                    %orig(0.19);
                    SwitcherDismiss = 0.15;
                    break;
                case 4:
                    %orig(0.1);
                    SwitcherDismiss = 0.12;
                    break;
                case 5:   
                    %orig(0.07);
                    SwitcherDismiss = 0.1;
                    break;   
                default:
                    %orig;
                    SwitcherDismiss = -1;    
                    break;
                }
            }else{
                //Fine Tune Mode
                %orig(reverseSpeedSliderValue(FineTuneSpeedValue));
                //Check Speed Value and change SpringBoard and Switcher Dismiss speed accordingly
                if (reverseSpeedSliderValue(FineTuneSpeedValue) < 0.4 && reverseSpeedSliderValue(FineTuneSpeedValue) >= 0.37){
                    SwitcherDismiss = 0.2;
                    //SpringboardSpeed = 1.1;
                }else if(reverseSpeedSliderValue(FineTuneSpeedValue) < 0.37 && reverseSpeedSliderValue(FineTuneSpeedValue) >= 0.25){
                    SwitcherDismiss = 0.17;
                    //SpringboardSpeed = 1.3;
                }else if(reverseSpeedSliderValue(FineTuneSpeedValue) < 0.25 && reverseSpeedSliderValue(FineTuneSpeedValue) >= 0.19){
                    SwitcherDismiss = 0.15;
                    //SpringboardSpeed = 1.5;
                }else if(reverseSpeedSliderValue(FineTuneSpeedValue) < 0.19 && reverseSpeedSliderValue(FineTuneSpeedValue) >= 0.1){
                    SwitcherDismiss = 0.12;
                    //SpringboardSpeed = 1.75;
                }else if(reverseSpeedSliderValue(FineTuneSpeedValue) < 0.1){
                    SwitcherDismiss = 0.1;
                    //SpringboardSpeed = 2;                    
                }else{
                    //Slider at or below its minimum: keep the system default
                    SwitcherDismiss = -1;
                }
            }            
        }else{
            %orig;
            SwitcherDismiss = -1;
            //SpringboardSpeed = -1;
        }
    }
    -(void)setDampingRatio:(double)arg1{ //App open and close bouncing (volume HUD is exempted, see note above)
        if(restoringForHUD){ %orig; return; }
        if(isOnSpringBoard){
            recordStockValue(stockDampingRatioValues, self, arg1);
            if(bootGraceActive()){
                %orig;
                return;
            }
        }
        if(volumeHUDActive){ //stock volume HUD: keep untouched
            %orig;
            return;
        }
        if(isBounceEnable){
            if(!isFineTuneBounceEnable){
                switch (Bouncevalue){
                    case 1:
                        %orig(0.9);
                        break;
                    case 2:
                        %orig(0.8);
                        break;
                    case 3:
                        %orig(0.6);
                        break;
                    case 4:
                        %orig(0.4);
                        break;
                    case 5:
                        %orig(0.2);
                        break;
                    default:
                        %orig;
                        break;    
                }
            }else{
                %orig(reverseBounceSliderValue(FineTuneBounceValue));
            }
        }else{
            %orig;
        }
    }

%end

//Springboard speed (mostly for folder but might affect something else on springboard too)
%hook SBFAnimationSettings

    //folder starting speed
    // -(void)setInitialVelocity:(double)arg1{
    //     %orig;
    // }

    // -(void)setSpeed:(double)arg1{
    //     if(isInstantFolder){
    //         %orig(arg1);        
    //     }else{
    //         if (isFolderAnimationEnabled){
    //             %orig(arg1*FolderSpeedValue);
    //         }else{
    //             %orig;
    //         }
    //     }
    // }

    -(void)setDamping:(double)arg1{
        if(restoringForHUD){ %orig; return; }
        if(isOnSpringBoard){
            recordStockValue(stockDampingValues, self, arg1);
            if(bootGraceActive()){
                %orig;
                return;
            }
        }
        if(volumeHUDActive){ //stock volume HUD: keep untouched
            %orig;
            return;
        }
        if(isInstantFolder){
            %orig;
        }else{
            if(isFolderAnimationEnabled && isFolderAnimationBounceEnabled){
                %orig(arg1*reverseFolderSliderValue(FolderDampingValue));
            }else{
                %orig;
            }
        }
    }

    //folder mass
    -(void)setMass:(double)arg1{
        if(restoringForHUD){ %orig; return; }
        if(isOnSpringBoard){
            recordStockValue(stockMassValues, self, arg1);
            if(bootGraceActive()){
                %orig;
                return;
            }
        }
        if(volumeHUDActive){ //stock volume HUD: keep untouched
            %orig;
            return;
        }
        if(isInstantFolder){
            %orig(arg1*0.0001);
        }else{
            if(isFolderAnimationEnabled){
                %orig(arg1*reverseFolderSliderValue(FolderMassValue));
            }else{
                %orig;
            }
        }
    }

    // -(void)setStiffness:(double)arg1{
    //     if(isInstantFolder){
    //         %orig;
    //     }else{
    //         if(isFolderAnimationEnabled){
    //             %orig(arg1*FolderStiffnessValue);
    //         }else{
    //             %orig;
    //         }
    //     }
    // }

%end

//In-App animation
%hook CASpringAnimation

    //start speed
    // -(void)setInitialVelocity:(double)arg1{
    //     %orig;
    // }

    //speed
    // - (void)setVelocity:(double)arg1{
    //     if(inAppAnimationEnabled){
    //         %orig(arg1 * VelocityValue);
    //     }else{
    //         %orig(arg1);
    //     }
    // }

    // -(void)setStiffness:(double)arg1{
    //     if(inAppAnimationEnabled){
    //         %orig(arg1 * StiffnessValue);
    //     }else{
    //         %orig(arg1);
    //     }
    // }

    //mass
    -(void)setMass:(double)arg1{ //in app speed
        if(inAppAnimationEnabled && !isOnSpringBoard){
            %orig(arg1 * reverseAppSpeedSliderValue(MassValue));
        }else{
            %orig(arg1);
        }
    }

    -(void)setDamping:(double)arg1{
        if((inAppAnimationEnabled && inAppAnimationBounceEnabled) && !isOnSpringBoard){
            %orig(arg1 * reverseAppSpeedSliderValue(DampingValue));
        }else{
            %orig(arg1);
        }
    }

    // - (void)setDuration:(double)arg1{
    //     if(inAppAnimationEnabled && !isOnSpringBoard){
    //         %orig(arg1 * 0.5);
    //     }else{
    //         %orig(arg1);
    //     }
    // }

%end

//In-App animation 2: electric boogaloo
// %hook CAAnimation

//     //duration
//    - (void)setDuration:(double)arg1{ //more in app speed but with more side effect 
//         if ([self isKindOfClass:[CASpringAnimationClass class]]) { //thanks fakeclockup
//             %orig(arg1);
//             return;
//         }
//         if(inAppAnimationEnabled){
//             %orig(arg1 * reverseAppSpeedSliderValue(DurationValue));
//         }else{
//             %orig;
//         }
//     }
    
// %end

//Screen Turn On and Off Speed
%hook SBFWakeAnimationSettings
    -(double)backlightFadeDuration{ //Screen turn off speed
        if(isScreensleepEnable){
            return reverseTurnOffSpeed(Screensleepvalue);
        }else{
            return %orig;
        }
    }
    -(double)speedMultiplierForWake{ //Screen turn on speed (might be glitchy)
        if(isScreenwakeEnable){
            return Screenwakevalue;
        }else{
            return %orig;
        }
    }
    -(double)speedMultiplierForLiftToWake{ //Screen turn on speed but for lift to wake (again might be glitchy)
        if(isScreenwakeEnable){
            return Screenwakevalue;
        }else{
            return %orig;
        }
    }
%end

//Extra extra
%hook SBFluidSwitcherAnimationSettings
    -(void)setWallpaperScaleInSwitcher:(double)arg1{ //Switcher wallpaper zoom out
        if(isNoWallZoominSwitcher){
            %orig(1);
        }else{
            %orig;
        }
    }    

    -(void)setHomeScreenScaleInSwitcher:(double)arg1{ //Switcher homescreen zoom out
        if(isNoiconZoominSwitcher){
            %orig(1);
        }else{
            %orig;
        }
    }

    -(double)emptySwitcherDismissDelay{ //Switcher fix when set speed too high
        //Volume HUD exemption: the HUD's auto-hide timing also flows through this
        //fluid-framework delay, so while the HUD is active the stock delay must win
        //or the HUD starts disappearing almost immediately (2.1.4-1 symptom: the
        //hide ANIMATION was stock-speed after value restore, but it still began way early).
        if (volumeHUDActive || SwitcherDismiss == -1){
            return %orig;
        }
        return SwitcherDismiss;
    }
%end

%hook CSCoverSheetTransitionSettings
    -(BOOL)iconsFlyIn{ //fly in icon when unlock
        if(isNoiconflyEnable){
            return 0;
        }else{
            return %orig; //keep the system default (e.g. Respect Reduce Motion)
        } 
    }	
%end

%hook SBIconView

    -(void)setEditingAnimationStrength:(CGFloat)arg1{
         if (isNoiconshakingEnable){ 
            %orig(0);
        }else{
            %orig(arg1);
        }
    }

%end

//Marks when SpringBoard finished launching so the boot grace (see note above) can end
//adaptively instead of running a fixed 15s after every respring. The class only exists
//in SpringBoard; Logos skips the hook everywhere else.
%hook SpringBoard
    - (void)applicationDidFinishLaunching:(id)application {
        %orig;
        springBoardDidFinishLaunchingTime = CFAbsoluteTimeGetCurrent();
    }
%end

//Direct HUD presentation as extra trigger signals (class renamed to
//SBVolumeControl on iOS 13+, so init the group with that class).
//Several redundant triggers because selector availability differs between iOS
//versions - Logos silently skips hooks whose selector doesn't exist.
%group VolumeHUDExempt
%hook VolumeControl
    - (void)handleVolumeButtonWithType:(long long)arg1 down:(BOOL)arg2 { //hardware volume button press
        noteVolumeHUDActivity();
        %orig;
    }
    - (void)increaseVolume { //official SBVolumeControl API (iOS 13+)
        noteVolumeHUDActivity();
        %orig;
    }
    - (void)decreaseVolume { //official SBVolumeControl API (iOS 13+)
        noteVolumeHUDActivity();
        %orig;
    }
    - (void)_presentVolumeHUDWithVolume:(float)volume { //HUD is about to be presented (iOS 13-15)
        noteVolumeHUDActivity();
        %orig;
    }
    - (void)hideVolumeHUDIfVisible { //official SBVolumeControl API (iOS 13+)
        noteVolumeHUDActivity();
        %orig;
    }
%end
%end

%ctor { //More pref
    tweakLoadTime = CFAbsoluteTimeGetCurrent(); //start of the 15s boot grace window (see note above)
    // NSLog(@"[Speedster] load test");
    // CASpringAnimationClass = NSClassFromString(@"CASpringAnimation");
    // SBFAnimationSettingsClass = NSClassFromString(@"SBFAnimationSettings");
    isOnSpringBoard = [[[NSBundle mainBundle] bundleIdentifier] isEqual:@"com.apple.springboard"];

    %init(_ungrouped); //activate all hooks outside explicit %groups

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)preferencesChanged, CFSTR("com.hoangdus.speedsterprefs-updated"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	preferencesChanged();

	if (isOnSpringBoard) {
		//Volume changes made from SpringBoard (hardware buttons etc.) are announced
		//right before the volume HUD presents - use that as the exemption window trigger.
		//queue:nil is REQUIRED: an async queue would run this block only after the
		//synchronous dispatch finishes, i.e. AFTER the HUD already configured its
		//dismiss animation with the tweaked response value. Observers registered in
		//%ctor run first (we register before SBVolumeControl does), so a synchronous
		//block opens the window before the HUD configures its animations.
		[[NSNotificationCenter defaultCenter] addObserverForName:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil queue:nil usingBlock:^(NSNotification *note){
			noteVolumeHUDActivity();
		}];

		%init(VolumeHUDExempt, VolumeControl = objc_getClass("SBVolumeControl"));
	}
}
