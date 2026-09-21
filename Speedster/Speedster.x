#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <execinfo.h>
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
static double reverseSpeedSliderValue(double input){
    double total = 0.45;
    return total - input;
}

static double reverseBounceSliderValue(double input){
    double total = 1.1;
    return total - input;
}

static double reverseTurnOffSpeed(double input){
    double total = 0.91;
    return total - input;
}

static double reverseAppSpeedSliderValue(double input){
    double value = 1.0 - input;
    //Floor the multiplier: values below 0.1 make CASpringAnimation parameters
    //pathological (tiny mass/damping), which on iOS 17 + ProMotion (120Hz)
    //keeps springs recomputing frames and burns CPU.
    if (value < 0.1) {
        value = 0.1;
    }
    return value;
}

static double reverseFolderSliderValue(double input){
    double total = 1.0;
    return total - input;
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

//TEMP diagnostic logging (v2.1.6) ---------------------------------------------------
//Two window-timing attempts (2.1.4/2.1.5) failed; this build only collects evidence.
//Everything relevant is appended to /var/mobile/Documents/speedster_debug.log
//(SpringBoard runs as mobile, so that path is writable; call sites guard with
//isOnSpringBoard so in-app processes never touch the file).
static void debugLog(NSString *fmt, ...){
    va_list args;
    va_start(args, fmt);
    NSString *payload = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    static dispatch_queue_t logQueue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ logQueue = dispatch_queue_create("com.hoangdus.speedster.debuglog", DISPATCH_QUEUE_SERIAL); });
    dispatch_async(logQueue, ^{
        NSString *path = @"/var/mobile/Documents/speedster_debug.log";
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            [@"" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
        NSString *line = [NSString stringWithFormat:@"%@ | %@\n", [NSDate date], payload];
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        if (fh) {
            [fh seekToEndOfFile];
            [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [fh closeFile];
        }
    });
}

//IMP map of SBVolumeControl so a raw (symbol-stripped) stack can still be checked:
//if any return address falls inside an SBVolumeControl method body, the current
//setResponse:/setDampingRatio: call belongs to the volume HUD animation path.
static uintptr_t volumeControlIMPs[512];
static NSInteger volumeControlIMPCount = 0;

static void collectVolumeControlIMPs(void){
    if (volumeControlIMPCount > 0) return;
    Class vc = objc_getClass("SBVolumeControl");
    if (!vc) return;
    unsigned int count = 0;
    Method *methods = class_copyMethodList(vc, &count);
    for (unsigned int i = 0; i < count && volumeControlIMPCount < 512; i++) {
        volumeControlIMPs[volumeControlIMPCount++] = (uintptr_t)method_getImplementation(methods[i]);
    }
    free(methods);
    //sort ascending so a stack address between imp[k] and imp[k+1] maps to method k
    for (NSInteger i = 1; i < volumeControlIMPCount; i++) {
        uintptr_t key = volumeControlIMPs[i];
        NSInteger j = i - 1;
        while (j >= 0 && volumeControlIMPs[j] > key) {
            volumeControlIMPs[j + 1] = volumeControlIMPs[j];
            j--;
        }
        volumeControlIMPs[j + 1] = key;
    }
}

static BOOL stackTouchesVolumeControl(void){
    if (volumeControlIMPCount == 0) return NO;
    void *bt[128];
    int n = backtrace(bt, 128);
    for (int i = 0; i < n; i++) {
        uintptr_t addr = (uintptr_t)bt[i];
        //binary search: largest IMP <= addr
        NSInteger lo = 0, hi = volumeControlIMPCount - 1, mid = -1;
        while (lo <= hi) {
            NSInteger m = (lo + hi) / 2;
            if (volumeControlIMPs[m] <= addr) { mid = m; lo = m + 1; }
            else hi = m - 1;
        }
        if (mid >= 0) {
            uintptr_t upper = (mid + 1 < volumeControlIMPCount) ? volumeControlIMPs[mid + 1] : volumeControlIMPs[mid] + 16384;
            if (addr < upper) return YES;
        }
    }
    return NO;
}
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
//a poisoned copy that no amount of restoring can reach. No rewriting during the first
//15s after tweak load; the only cost is that app animations right after a respring
//run at stock speed for 15s.
static CFAbsoluteTime tweakLoadTime = 0;

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
    debugLog(@"HUD restore: stock values applied to all recorded settings objects");
}

static void noteVolumeHUDActivity(NSString *source){
    volumeHUDActive = YES;
    debugLog(@"HUD window OPEN via %@", source);
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
            if((CFAbsoluteTimeGetCurrent() - tweakLoadTime) < 15.0){ //boot grace: feed stock values to launching subsystems
                debugLog(@"setResponse GRACE ptr=%p val=%.3f", self, arg1);
                %orig;
                return;
            }
            if(stackTouchesVolumeControl()){ //rare; callStackSymbols is slow (caused 1s app-switch lag in 2.1.6), only pay it for volume-related calls
                NSArray *dbgStack = [NSThread callStackSymbols];
                debugLog(@"setResponse ptr=%p val=%.3f active=%d vcStack=1 stack=%@", self, arg1, volumeHUDActive, [dbgStack componentsJoinedByString:@" | "]);
            }else{
                debugLog(@"setResponse ptr=%p val=%.3f active=%d vcStack=0", self, arg1, volumeHUDActive);
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
            if((CFAbsoluteTimeGetCurrent() - tweakLoadTime) < 15.0){ //boot grace: feed stock values to launching subsystems
                debugLog(@"setDampingRatio GRACE ptr=%p val=%.3f", self, arg1);
                %orig;
                return;
            }
            if(stackTouchesVolumeControl()){
                NSArray *dbgStack = [NSThread callStackSymbols];
                debugLog(@"setDampingRatio ptr=%p val=%.3f active=%d vcStack=1 stack=%@", self, arg1, volumeHUDActive, [dbgStack componentsJoinedByString:@" | "]);
            }else{
                debugLog(@"setDampingRatio ptr=%p val=%.3f active=%d vcStack=0", self, arg1, volumeHUDActive);
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
            if((CFAbsoluteTimeGetCurrent() - tweakLoadTime) < 15.0){ //boot grace: feed stock values to launching subsystems
                debugLog(@"setDamping GRACE ptr=%p val=%.3f", self, arg1);
                %orig;
                return;
            }
            if(stackTouchesVolumeControl()){
                NSArray *dbgStack = [NSThread callStackSymbols];
                debugLog(@"setDamping ptr=%p val=%.3f active=%d vcStack=1 stack=%@", self, arg1, volumeHUDActive, [dbgStack componentsJoinedByString:@" | "]);
            }else{
                debugLog(@"setDamping ptr=%p val=%.3f active=%d vcStack=0", self, arg1, volumeHUDActive);
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
            if((CFAbsoluteTimeGetCurrent() - tweakLoadTime) < 15.0){ //boot grace: feed stock values to launching subsystems
                debugLog(@"setMass GRACE ptr=%p val=%.3f", self, arg1);
                %orig;
                return;
            }
            if(stackTouchesVolumeControl()){
                NSArray *dbgStack = [NSThread callStackSymbols];
                debugLog(@"setMass ptr=%p val=%.3f active=%d vcStack=1 stack=%@", self, arg1, volumeHUDActive, [dbgStack componentsJoinedByString:@" | "]);
            }else{
                debugLog(@"setMass ptr=%p val=%.3f active=%d vcStack=0", self, arg1, volumeHUDActive);
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

//Direct HUD presentation as extra trigger signals (class renamed to
//SBVolumeControl on iOS 13+, so init the group with that class).
//Several redundant triggers because selector availability differs between iOS
//versions - Logos silently skips hooks whose selector doesn't exist.
%group VolumeHUDExempt
%hook VolumeControl
    - (void)handleVolumeButtonWithType:(long long)arg1 down:(BOOL)arg2 { //hardware volume button press
        noteVolumeHUDActivity(@"handleVolumeButton");
        %orig;
    }
    - (void)increaseVolume { //official SBVolumeControl API (iOS 13+)
        noteVolumeHUDActivity(@"increaseVolume");
        %orig;
    }
    - (void)decreaseVolume { //official SBVolumeControl API (iOS 13+)
        noteVolumeHUDActivity(@"decreaseVolume");
        %orig;
    }
    - (void)_presentVolumeHUDWithVolume:(float)volume { //HUD is about to be presented (iOS 13-15)
        noteVolumeHUDActivity(@"_presentVolumeHUD");
        %orig;
    }
    - (void)hideVolumeHUDIfVisible { //official SBVolumeControl API (iOS 13+)
        noteVolumeHUDActivity(@"hideVolumeHUD");
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
		[@"" writeToFile:@"/var/mobile/Documents/speedster_debug.log" atomically:YES encoding:NSUTF8StringEncoding error:nil]; //reset diagnostic log each load

		Class vc = objc_getClass("SBVolumeControl");
		debugLog(@"ctor v2.1.4-3: SBVolumeControl=%@ present=%d inc=%d dec=%d handle=%d hide=%d", vc,
			class_getInstanceMethod(vc, @selector(_presentVolumeHUDWithVolume:)) != NULL,
			class_getInstanceMethod(vc, @selector(increaseVolume)) != NULL,
			class_getInstanceMethod(vc, @selector(decreaseVolume)) != NULL,
			class_getInstanceMethod(vc, @selector(handleVolumeButtonWithType:down:)) != NULL,
			class_getInstanceMethod(vc, @selector(hideVolumeHUDIfVisible)) != NULL);

		collectVolumeControlIMPs(); //must run BEFORE %init so we capture the ORIGINAL imps

		//Re-check 10s later: %ctor runs during dyld init, the class may register afterwards
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			Class vcl = objc_getClass("SBVolumeControl");
			debugLog(@"late check: SBVolumeControl=%@ present=%d inc=%d dec=%d handle=%d hide=%d", vcl,
				class_getInstanceMethod(vcl, @selector(_presentVolumeHUDWithVolume:)) != NULL,
				class_getInstanceMethod(vcl, @selector(increaseVolume)) != NULL,
				class_getInstanceMethod(vcl, @selector(decreaseVolume)) != NULL,
				class_getInstanceMethod(vcl, @selector(handleVolumeButtonWithType:down:)) != NULL,
				class_getInstanceMethod(vcl, @selector(hideVolumeHUDIfVisible)) != NULL);
			collectVolumeControlIMPs(); //no-op if already collected at ctor time
		});

		//Volume changes made from SpringBoard (hardware buttons etc.) are announced
		//right before the volume HUD presents - use that as the exemption window trigger.
		//queue:nil is REQUIRED: an async queue would run this block only after the
		//synchronous dispatch finishes, i.e. AFTER the HUD already configured its
		//dismiss animation with the tweaked response value. Observers registered in
		//%ctor run first (we register before SBVolumeControl does), so a synchronous
		//block opens the window before the HUD configures its animations.
		[[NSNotificationCenter defaultCenter] addObserverForName:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil queue:nil usingBlock:^(NSNotification *note){
			debugLog(@"volume notification arrived");
			noteVolumeHUDActivity(@"notification");
		}];
		debugLog(@"ctor: notification observer registered");

		%init(VolumeHUDExempt, VolumeControl = objc_getClass("SBVolumeControl"));
		debugLog(@"ctor: VolumeHUDExempt initialized");
	}
}
