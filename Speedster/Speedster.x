#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <execinfo.h>
#import <dlfcn.h>
#import <stdio.h>
#import <stdarg.h>
static BOOL isOnSpringBoard;
// -1 means "don't touch the system value". Starting at 0.0 would make
// emptySwitcherDismissDelay return a 0s delay before setResponse: ever runs,
// causing the switcher animation to be recomputed constantly (high CPU on iOS 17).
static double SwitcherDismiss = -1;

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
static double FolderMassValue;
static double FolderDampingValue;

static BOOL inAppAnimationEnabled;
static BOOL inAppAnimationBounceEnabled;
static double MassValue;
static double DampingValue;

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

    //folder values
    isFolderAnimationEnabled = (prefs && [prefs objectForKey:@"isFolderAnimationEnabled"] ? [[prefs valueForKey:@"isFolderAnimationEnabled"] boolValue] : NO );
    isFolderAnimationBounceEnabled = (prefs && [prefs objectForKey:@"isFolderBounceEnabled"] ? [[prefs valueForKey:@"isFolderBounceEnabled"] boolValue] : NO );
    FolderDampingValue = (prefs && [prefs objectForKey:@"FolderDampingValue"] ? [[prefs valueForKey:@"FolderDampingValue"] doubleValue] : 0 );
    FolderMassValue = (prefs && [prefs objectForKey:@"FolderMassValue"] ? [[prefs valueForKey:@"FolderMassValue"] doubleValue] : 0 );

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
    DampingValue = (prefs && [prefs objectForKey:@"DampingValue"] ? [[prefs valueForKey:@"DampingValue"] doubleValue] : 0 );
    MassValue = (prefs && [prefs objectForKey:@"DurationMassValue"] ? [[prefs valueForKey:@"DurationMassValue"] doubleValue] : 0 );
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
static double reverseSpeedSliderValue(double input){ //track 0.05..0.40 -> response 0.45..0.15
    double f = (input - 0.05) / 0.35; //0 = slowest end, 1 = fastest end
    f = MIN(MAX(f, 0.0), 1.0);
    //Per user preference: 0% = exactly stock (~0.45), and the fast end is capped
    //at 0.15 (3x stock) instead of the original 0.05 (9x). 3x total range ->
    //constant ~1.1% duration change per 1% of track (very fine-grained).
    return 0.45 * pow(0.3333, f);
}

static double reverseBounceSliderValue(double input){ //track 0.2..1.0 -> dampingRatio 0.9..0.2
    double f = (input - 0.2) / 0.8;
    f = MIN(MAX(f, 0.0), 1.0);
    //0% = stock feel (dampingRatio ~0.9, no extra bounce); bouncy end capped at
    //0.2 (the most bouncy preset) instead of the original 0.1 (endless wobble).
    return 0.9 * pow(0.2222, f);
}

static double reverseAppSpeedSliderValue(double input){ //track 0..0.99 -> stock multiplier 1.0..0.1
    double f = input / 0.99;
    f = MIN(MAX(f, 0.0), 1.0);
    //0% = exactly stock (x1.0); fast end capped at x0.1 (springs ~3.2x faster,
    //matching the app open/close 3x cap philosophy).
    double value = pow(0.1, f);
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
    return pow(0.1, f); //0% = exactly stock, fast end capped, same as in-app
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

//Diag logging lives below (lock exemption section); forward-declared because the
//stock-restore above logs its map sizes too.
static void diagLog(NSString *fmt, ...);
static void diagLogB(NSString *fmt, ...);

static void recordStockValue(NSMapTable *map, id object, double value){
    if (!isOnSpringBoard) return;
    initStockMaps();
    [stockValuesLock lock];
    [map setObject:@(value) forKey:object];
    [stockValuesLock unlock];
}

static void restoreStockValuesForHUD(NSString *reason){
    if (!isOnSpringBoard) return;
    initStockMaps();
    diagLog(@"restore(%@): response=%lu dampingRatio=%lu damping=%lu mass=%lu", reason,
            (unsigned long)[stockResponseValues count], (unsigned long)[stockDampingRatioValues count],
            (unsigned long)[stockDampingValues count], (unsigned long)[stockMassValues count]);
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
    restoreStockValuesForHUD(@"volume");
    NSInteger generation = ++volumeHUDGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (volumeHUDGeneration == generation) volumeHUDActive = NO;
    });
}

//Lock screen exemption ---------------------------------------------------------------
//v2.1.4-Fluid-6 failed on device: the lock pill kept flashing and its frequency tracked
//the app open/close slider, i.e. the exemptions never engaged. Both legacy lock signals
//are dead on iOS 17: "com.apple.springboard.lockcomplete" doesn't fire and the lockstate
//notify payload reads 0 in both directions, so deviceLocked stayed NO and every exemption
//branch was skipped (behavior identical to Fluid-5).
//v2.1.4-Fluid-7 reads lock state from the class that OWNS it (verified against the iOS 17
//SpringBoard runtime dump): SBLockScreenManager.sharedInstance.isUILocked, via three
//redundant channels - (1) direct hooks on _setUILocked:/_reallySetUILocked: (instant),
//(2) a 0.5s authoritative poll (converges even if hooks/notifications ever fail), and
//(3) the lockcomplete darwin notification as a bonus. On change we also run the
//volume-HUD-style stock restore so the lock pill reads clean fluid settings objects.
//Fluid-7 device result: lock tracking + stock pass-through all WORK (log-verified), yet
//the pill still flashes. The 40-line log budget was consumed entirely by the ~40-line
//wake burst, so the loop's own calls (if any) were invisible. Fluid-8 is a
//diagnostics-first build, no behavior change: 500-line budget, class names on every
//line, unlocked-phase per-class sampling (frozen-copy hunt), locked-phase logging of
//the wake getters (the only values still tweaked while locked), and a 10s heartbeat
//that proves silence during the flash is real.
//Diag logging (this build only): /var/mobile/Library/SpeedsterDiag.log, fresh per
//respring, budgeted while locked so it can never spam per-frame.
static volatile BOOL deviceLocked = YES; //SpringBoard always launches into the lock screen
static dispatch_source_t lockPollTimer;
static NSString *diagLogPath = nil;
static NSInteger diagBudget = 0;

//Fluid-14 unlock grace: for a short window right after the unlock transition completes,
//keep every SpringBoard-facing hook at stock. The lock pill collapses during the unlock
//transition and may (re)configure its presentation settings just after the state flips;
//any tweaked value it picks up there gets frozen into its own state and replays as the
//endless silent flash on the next lock. Cost: app animations in the first 0.6s after
//unlock run at stock speed (barely noticeable, the unlock flow lands on the home screen).
static CFAbsoluteTime unlockTransitionTime = 0;
static BOOL unlockGraceActive(void){
    if (!isOnSpringBoard || deviceLocked) return NO;
    if (unlockTransitionTime == 0) return NO;
    return (CFAbsoluteTimeGetCurrent() - unlockTransitionTime) < 0.6;
}

static void diagLogCore(NSString *fmt, va_list args){
    if (!diagLogPath) return;
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    NSString *line = [NSString stringWithFormat:@"[%.3f] %@\n",
                      [NSDate date].timeIntervalSince1970, msg];
    FILE *f = fopen(diagLogPath.fileSystemRepresentation, "a");
    if (f) {
        fseek(f, 0, SEEK_END);
        if (ftell(f) > 512 * 1024) { fclose(f); f = fopen(diagLogPath.fileSystemRepresentation, "w"); }
        if (f) { fputs(line.UTF8String, f); fclose(f); }
    }
}

static void diagLog(NSString *fmt, ...){
    va_list args; va_start(args, fmt);
    diagLogCore(fmt, args);
    va_end(args);
}

//Budgeted variant for potentially chatty call sites (500 lines per lock session max).
//Fluid-7 lesson: the 40-line budget was eaten by the ~40-line wake burst alone, so
//everything the flash loop did AFTER the burst went unlogged and silence during the
//flash was indistinguishable from budget starvation.
static void diagLogB(NSString *fmt, ...){
    if (diagBudget <= 0) return;
    diagBudget--;
    va_list args; va_start(args, fmt);
    diagLogCore(fmt, args);
    va_end(args);
}

//Fluid-15 unlocked-phase read sampling. While locked every hooked path provably
//returns stock, yet the pill keeps flashing - so the poison must be a value the
//pill's controllers captured while UNLOCKED into their own storage (settings-object
//restore can never reach a private copy). Unlocked-phase calls of the suspects were
//invisible in every previous log (diagLogB only fires while locked). This samples
//the first N unlocked reads of each suspect with raw image!offset backtraces.
//NOTE: backtraces taken from inside our hooks are polluted by every installed
//tweak's hook trampoline frames (Fluid-14 SymMap analysis proved the "SpringBoard"
//frames in storm traces are trampolines), but who-calls-whom is still readable.
static NSInteger unlockTraceBudget = 0;
static void unlockSampleTrace(NSString *tag, double value){
    if (!isOnSpringBoard || deviceLocked || unlockTraceBudget <= 0) return;
    unlockTraceBudget--;
    void *frames[32] = {0};
    int n = backtrace(frames, 32);
    NSMutableString *line = [NSMutableString stringWithFormat:@"[unlock-read] %@ value=%g (%d frames):", tag, value, n];
    for (int i = 2; i < n && i < 16; i++) {
        Dl_info info;
        memset(&info, 0, sizeof(info));
        NSString *raw = @"?";
        if (dladdr(frames[i], &info) && info.dli_fname) {
            const char *base = strrchr(info.dli_fname, '/');
            raw = [NSString stringWithFormat:@"%s!0x%lx", base ? base + 1 : info.dli_fname,
                   (unsigned long)((uintptr_t)frames[i] - (uintptr_t)info.dli_fbase)];
        }
        [line appendFormat:@" <- %@", raw];
    }
    diagLog(@"%@", line);
}

//Folder speed on iOS 17 -------------------------------------------------------------
//The folder zoom animation reads response/dampingRatio from a long-lived
//SBFFluidBehaviorSettings object that SpringBoard configures ONCE (during our boot
//grace) and only READS afterwards - the setter hooks never fire for folder opens.
//Fix: identify the folder object by its stable caller fingerprint in the getter
//backtrace (SpringBoard image-relative offsets, slide-independent across boots) and
//scale the values at READ time. Nothing is ever written, so lock-screen machinery
//always sees stock values (deviceLocked short-circuits before this runs).
static NSMapTable *folderFluidObjects; //object -> @YES(folder)/@NO(not folder)
static NSInteger folderTraceBudget = 0;
static CFTimeInterval lastFolderTraceTime = 0;

static BOOL folderCallerFingerprint(void){
    void *frames[24] = {0};
    int n = backtrace(frames, 24);
    for (int i = 2; i < n && i < 16; i++) {
        Dl_info info;
        memset(&info, 0, sizeof(info));
        if (dladdr(frames[i], &info) && info.dli_fname) {
            const char *base = strrchr(info.dli_fname, '/');
            const char *img = base ? base + 1 : info.dli_fname;
            if (!strcmp(img, "SpringBoard")) {
                uintptr_t off = (uintptr_t)frames[i] - (uintptr_t)info.dli_fbase;
                if (off == 0x77d970 || off == 0x77e3e4 || off == 0x77e448 || off == 0x77e480) return YES;
            }
        }
    }
    return NO;
}

//Per-object decision cache + read-time folder acceleration. Called only while
//unlocked, outside all grace/HUD windows, and behind the value gate in the getters.
static double folderSpeedAdjust(id obj, double v, BOOL isResponse){
    if(!folderFluidObjects) folderFluidObjects = [NSMapTable strongToStrongObjectsMapTable];
    id flag = nil;
    [stockValuesLock lock];
    flag = [folderFluidObjects objectForKey:obj];
    [stockValuesLock unlock];
    if(flag){ //known object: O(1) decision, no backtrace
        if([flag isEqual:@YES]) return v * reverseFolderSliderValue(isResponse ? FolderMassValue : FolderDampingValue);
        return v;
    }
    if(folderTraceBudget <= 0) return v;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if(now - lastFolderTraceTime < 0.05) return v; //rate-limit evaluations
    lastFolderTraceTime = now;
    folderTraceBudget--;
    BOOL hit = folderCallerFingerprint();
    [stockValuesLock lock];
    [folderFluidObjects setObject:(hit ? @YES : @NO) forKey:obj];
    [stockValuesLock unlock];
    if(hit){
        double mult = reverseFolderSliderValue(isResponse ? FolderMassValue : FolderDampingValue);
        diagLog(@"[folder-obj] %p identified (%@), value %g -> x%g", obj, isResponse ? @"response" : @"dampingRatio", v, mult);
        return v * mult;
    }
    return v;
}

//Fluid-8 unlocked-phase sampling: one line per (selector, class) pair. The flash loop
//most likely runs on a value some controller FROZE out of a settings object while the
//device was unlocked (same disease as the volume HUD's launch-time freeze), so we need
//to know every class that flows through the hooked setters during normal use.
//Instances are created per-animation, so the class name is the only stable identity.
static NSMutableSet *diagUniqueLogged;
static void diagLogClassOnce(NSString *tag, id obj, double value){
    if (!isOnSpringBoard || !obj || deviceLocked) return;
    if (diagUniqueLogged && diagUniqueLogged.count >= 64) return; //saturated: skip the per-call string alloc + lock
    initStockMaps();
    NSString *className = NSStringFromClass([obj class]);
    NSString *key = [NSString stringWithFormat:@"%@|%@", tag, className];
    BOOL shouldLog = NO;
    [stockValuesLock lock];
    if (!diagUniqueLogged) diagUniqueLogged = [NSMutableSet new];
    if ([diagUniqueLogged count] < 64 && ![diagUniqueLogged containsObject:key]) {
        [diagUniqueLogged addObject:key];
        shouldLog = YES;
    }
    [stockValuesLock unlock];
    if (shouldLog) diagLog(@"[unlocked] %@ on %@ value=%g", tag, className, value);
}

static BOOL queryUILocked(void){
    Class cls = objc_getClass("SBLockScreenManager");
    if (!cls) return NO;
    id mgr = ((id(*)(Class, SEL))objc_msgSend)(cls, @selector(sharedInstance));
    if (!mgr) return NO;
    return !!((BOOL(*)(id, SEL))objc_msgSend)(mgr, @selector(isUILocked));
}

static void setDeviceLocked(BOOL locked, const char *source){
    if (locked == deviceLocked) return;
    diagLog(@"deviceLocked %d -> %d (%s)", deviceLocked, locked, source);
    deviceLocked = locked;
    if (!locked) unlockTransitionTime = CFAbsoluteTimeGetCurrent();
    diagBudget = 500; //fresh log budget per lock session
    unlockTraceBudget = 8; //fresh unlocked-read backtrace samples per session
    folderTraceBudget = 150; //fresh folder fingerprint evaluations per session
    //Fluid-14: the lock pill's animation config is read INSIDE %orig of the lock call,
    //i.e. BEFORE this function used to run at the hook's tail - so every lock started
    //with the pill reading unlock-period tweaked object values and freezing them into
    //its own presentation state (the endless silent flash). On LOCK the restore must
    //run BEFORE the lock machinery; the SBLockScreenManager hooks below were reordered
    //accordingly. This function stays as the authoritative state/restore entry.
    restoreStockValuesForHUD(locked ? @"lock" : @"unlock");
}

static void lockCompleteDarwinCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo){
    setDeviceLocked(YES, "lockcomplete");
}

static void watchLockState(void){
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                    (CFNotificationCallback)lockCompleteDarwinCallback,
                                    CFSTR("com.apple.springboard.lockcomplete"), NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}

static void startLockPolling(void){
    lockPollTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(lockPollTimer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                              (int64_t)(0.5 * NSEC_PER_SEC), 0);
    __block NSInteger heartbeatTicks = 0;
    dispatch_source_set_event_handler(lockPollTimer, ^{
        setDeviceLocked(queryUILocked(), "poll");
        //Fluid-8: positive-evidence heartbeat. If the flash loop keeps running while this
        //reports budget left, the loop provably makes NO hooked setter calls at all ->
        //frozen-copy/controller-cache disease, not a settings-object disease.
        if (deviceLocked && (++heartbeatTicks % 20) == 0) {
            diagLog(@"heartbeat: locked, diagBudget left=%ld", (long)diagBudget);
        }
    });
    dispatch_resume(lockPollTimer);
}

//App Open animation and bouncing
%hook SBFFluidBehaviorSettings
    //Fluid-15 read-side instrumentation: while locked every WRITE is stock, so if the
    //pill still flashes the poison was READ (and privately frozen) while unlocked.
    //Sample the first unlocked reads of each value: the [unlock-read] backtraces show
    //exactly which controller touches a (possibly tweaked) value right before freezing
    //it. Selectors verified present in the iOS 17 SymMap dump. Perf: class-once logging
    //and an 8/session trace budget keep the hot getter path cheap.
    -(double)response{
        double v = %orig;
        if(isOnSpringBoard && !deviceLocked){
            diagLogClassOnce(@"get-response", self, v);
            unlockSampleTrace(@"get-response", v);
            if(!bootGraceActive() && !unlockGraceActive() && !volumeHUDActive
               && v > 0.4 && v < 0.65 && isFolderAnimationEnabled){
                v = folderSpeedAdjust(self, v, YES);
            }
        }
        return v;
    }
    -(double)dampingRatio{
        double v = %orig;
        if(isOnSpringBoard && !deviceLocked){
            diagLogClassOnce(@"get-dampingRatio", self, v);
            unlockSampleTrace(@"get-dampingRatio", v);
            if(!bootGraceActive() && !unlockGraceActive() && !volumeHUDActive
               && v > 0.75 && v < 0.95 && isFolderAnimationBounceEnabled){
                v = folderSpeedAdjust(self, v, NO);
            }
        }
        return v;
    }
    -(double)settlingDuration{
        double v = %orig;
        if(isOnSpringBoard && !deviceLocked){
            diagLogClassOnce(@"get-settlingDuration", self, v);
            unlockSampleTrace(@"get-settlingDuration", v);
        }
        return v;
    }

    -(void)setResponse:(double)arg1{ //App open and close speed
        if(restoringForHUD){ %orig; return; }
        if(isOnSpringBoard){
            recordStockValue(stockResponseValues, self, arg1);
            diagLogClassOnce(@"setResponse", self, arg1);
            if(bootGraceActive()){
                %orig;
                return;
            }
            if(unlockGraceActive()){ //Fluid-14: just-unlocked boundary stays stock
                %orig;
                return;
            }
        }
        if(volumeHUDActive){ //stock volume HUD: keep untouched, don't disturb switcher state
            %orig;
            return;
        }
        if(deviceLocked){ //lock-screen island/UI (e.g. lock pill) animations run stock
            diagLogB(@"setResponse %g while locked (%@ self=%p)", arg1, NSStringFromClass([(id)self class]), self);
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
                if(FineTuneSpeedValue <= 0.0005){ //Fluid-14: 0% = never touch the object (true stock kill switch)
                    %orig;
                    SwitcherDismiss = -1;
                    return;
                }
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
            diagLogClassOnce(@"setDampingRatio", self, arg1);
            if(bootGraceActive()){
                %orig;
                return;
            }
            if(unlockGraceActive()){ //Fluid-14: just-unlocked boundary stays stock
                %orig;
                return;
            }
        }
        if(volumeHUDActive){ //stock volume HUD: keep untouched
            %orig;
            return;
        }
        if(deviceLocked){ //lock-screen island/UI (e.g. lock pill) animations run stock
            diagLogB(@"setDampingRatio %g while locked (%@ self=%p)", arg1, NSStringFromClass([(id)self class]), self);
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
                if(FineTuneBounceValue <= 0.0005){ //Fluid-14: 0% = never touch the object (true stock kill switch)
                    %orig;
                    return;
                }
                %orig(reverseBounceSliderValue(FineTuneBounceValue));
            }
        }else{
            %orig;
        }
    }

%end

//Springboard speed (mostly for folder but might affect something else on springboard too)
%hook SBFAnimationSettings

    -(void)setDamping:(double)arg1{
        if(restoringForHUD){ %orig; return; }
        if(isOnSpringBoard){
            recordStockValue(stockDampingValues, self, arg1);
            diagLogClassOnce(@"setDamping", self, arg1);
            if(bootGraceActive()){
                %orig;
                return;
            }
            if(unlockGraceActive()){ //Fluid-14: just-unlocked boundary stays stock
                %orig;
                return;
            }
        }
        if(volumeHUDActive){ //stock volume HUD: keep untouched
            %orig;
            return;
        }
        if(deviceLocked){ //lock-screen animations run stock
            diagLogB(@"SBFAnimationSettings setDamping %g while locked (%@ self=%p)", arg1, NSStringFromClass([(id)self class]), self);
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
            diagLogClassOnce(@"setMass", self, arg1);
            if(bootGraceActive()){
                %orig;
                return;
            }
            if(unlockGraceActive()){ //Fluid-14: just-unlocked boundary stays stock
                %orig;
                return;
            }
        }
        if(volumeHUDActive){ //stock volume HUD: keep untouched
            %orig;
            return;
        }
        if(deviceLocked){ //lock-screen animations run stock
            diagLogB(@"SBFAnimationSettings setMass %g while locked (%@ self=%p)", arg1, NSStringFromClass([(id)self class]), self);
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

%end

//In-App animation
%hook CASpringAnimation

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

%end

//Screen Turn On and Off Speed
//Fluid-13 FINAL root cause: while the device is locked, ANY non-stock wake animation
//multiplier breaks the lock pill's presentation state machine - the pill's show/hide
//animations complete faster than the island expects, so it re-presents endlessly
//(100x = violent flip-flop, 3x = still flip-flops; Fluid-9's clamp wasn't enough).
//Fluid-14 correction: the wake multiplier was NOT the root cause either. The Fluid-13
//device log proved every hooked value path returns stock while locked AND the flash
//loop makes zero hooked calls (heartbeat budget untouched) - the pill freezes tweaked
//values captured at the lock transition, where %orig (the lock machinery that configures
//the pill) ran BEFORE the stock restore. Fix = restore-before-%orig on lock + unlock
//grace window + 0%-means-untouched kill switch. See SBLockScreenManager hooks below.
//The settings-object "storm" in earlier logs is a red herring: it also fires during
//the boot grace window when every hook is a pure pass-through. Meanwhile the wake
//multiplier was the ONLY time-varying tweaked value left while locked, and it is
//read exactly when the flash appears (screen wake on the lock screen).
//Fluid-16: all three wake getters return the stock value in EVERY state - the Fluid-15
//log proved the poison read happens ~1.3s BEFORE the lock flag flips (backlight-off
//prep), so no state window is safe. The wake/sleep speed features are fully retired
//(iOS 17 hard conflict with the lock pill); no hook anywhere writes these values.
%hook SBFWakeAnimationSettings
    //Fluid-16 FINAL: all three getters return stock ALWAYS. The Fluid-15 log caught the
    //smoking gun: ~1.3s before EVERY lock (lock button -> backlight fade prep), while the
    //lock flag still says "unlocked", the system reads backlightFadeDuration and got the
    //tweaked+clamped 0.15 (stock 0.185) - a non-stock WAKE-FAMILY value inside the lock
    //transition, the exact disease Fluid-13 proved fatal to the pill state machine (any
    //multiplier != 1 in this family flip-flops the pill). Waking only ever happens from
    //the locked/off state and sleeping only ever happens into it, so unlocked-phase
    //reads of these getters are always transition-gap reads; the user-facing features
    //were imperceptible anyway (clamped 0.15 vs 0.185 stock = 19% at the fastest slider).
    -(double)backlightFadeDuration{ //Screen turn off speed
        double stock = %orig;
        if(deviceLocked || unlockGraceActive()){
            diagLogB(@"backlightFadeDuration -> stock %g (%@)", stock, NSStringFromClass([(id)self class]));
        }else{
            diagLogClassOnce(@"backlightFadeDuration", self, stock);
        }
        return stock;
    }
    -(double)speedMultiplierForWake{ //Screen turn on speed (might be glitchy)
        double stock = %orig;
        if(deviceLocked || unlockGraceActive()){
            diagLogB(@"speedMultiplierForWake -> stock %g (%@)", stock, NSStringFromClass([(id)self class]));
        }else{
            diagLogClassOnce(@"speedMultiplierForWake", self, stock);
        }
        return stock;
    }
    -(double)speedMultiplierForLiftToWake{ //Screen turn on speed but for lift to wake (again might be glitchy)
        double stock = %orig;
        if(deviceLocked || unlockGraceActive()){
            diagLogB(@"speedMultiplierForLiftToWake -> stock %g (%@)", stock, NSStringFromClass([(id)self class]));
        }else{
            diagLogClassOnce(@"speedMultiplierForLiftToWake", self, stock);
        }
        return stock;
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
        //Fluid-15 verdict: ZERO calls in an entire session (locked AND unlocked) - the
        //getter is fully exonerated as the pill poison, so the switcher auto-dismiss
        //timing feature returns (Fluid-14 behavior below).
        if (isOnSpringBoard && (deviceLocked || unlockGraceActive())){
            double stock = %orig;
            diagLogB(@"dismissDelay while locked -> stock %g (SwitcherDismiss=%g, %@)", stock, SwitcherDismiss, NSStringFromClass([(id)self class]));
            return stock;
        }
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

//Authoritative lock-state transitions from the class that owns them (iOS 17 selectors
//verified against the runtime dump; Logos silently skips wherever they don't exist).
//The class is bound at %init time via objc_getClass, same pattern as VolumeControl.
%group LockScreenTracker
%hook SBLockScreenManager
    //Fluid-14 ordering: on LOCK, setDeviceLocked (which runs the stock restore) MUST run
    //BEFORE %orig - the pill's presentation config reads the fluid settings objects
    //inside the lock machinery, and it has to see stock values there. On UNLOCK the old
    //tail-first order is kept so the unlock machinery itself still runs through the
    //locked (stock) pass-through, and the unlock grace starts right after.
    -(void)_setUILocked:(BOOL)arg1{
        if(arg1 && !deviceLocked) setDeviceLocked(YES, "_setUILocked(pre)");
        %orig;
        if(!arg1 && deviceLocked) setDeviceLocked(NO, "_setUILocked");
    }
    -(void)_reallySetUILocked:(BOOL)arg1{
        if(arg1 && !deviceLocked) setDeviceLocked(YES, "_reallySetUILocked(pre)");
        %orig;
        if(!arg1 && deviceLocked) setDeviceLocked(NO, "_reallySetUILocked");
    }
%end
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

		//Lock screen exemption wiring (see the lock exemption note above)
		diagLogPath = @"/var/mobile/Library/SpeedsterDiag.log";
		remove(diagLogPath.fileSystemRepresentation); //fresh log per respring
		diagBudget = 500; //budget for the pre-first-transition (locked after respring) session
		diagLog(@"Speedster Fluid-18 loaded, deviceLocked(assumed)=%d", deviceLocked);
		Class lockMgrClass = objc_getClass("SBLockScreenManager");
		if (lockMgrClass) {
			%init(LockScreenTracker, SBLockScreenManager = lockMgrClass);
			diagLog(@"SBLockScreenTracker hooks initialized");
		} else {
			diagLog(@"SBLockScreenManager class NOT found!");
		}
		watchLockState();
		startLockPolling();
	}
}
