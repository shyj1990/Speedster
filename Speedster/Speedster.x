#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <stdio.h>
#import <stdarg.h>

//2.2.0-Fresh-1: ground-up rebuild on the Fluid-17 clean baseline.
//ONLY feature kept from the Fluid-18..34 era: folder open/close speed + bounce
//(the Fluid-22..27 write-side mechanism, field-verified stable). Everything that
//ever touched the lock screen / Dynamic Island is GONE by construction:
//  - no app open/close animation  -> no SBFFluidBehaviorSettings setter scaling
//  - no in-app animation          -> no CASpringAnimation/UIView/CAAnimation hooks
//  - no wake/sleep speed          -> no SBFWakeAnimationSettings hooks (retired Fluid-16)
//  - no stock-restore registry    -> no restoreStockValuesForHUD (the root cause of
//                                    BOTH the lock-pill flashing saga AND the
//                                    Fluid-33/34 white-ring regression)
//  - no getter hooks at all       -> getter multiplication stays BANNED (Fluid-18
//                                    watchdog freeze), and no getter can leak a
//                                    scaled value into the lock pill (Fluid-35 lesson)
//The tweak now writes ONLY per-animation objects that are created fresh and die
//with the animation, so lock-screen state can never be contaminated.

static BOOL isOnSpringBoard;

//Folder open/close animation (the only speed feature in the Fresh rebuild)
static BOOL isFolderAnimationEnabled;
static BOOL isFolderAnimationBounceEnabled;
static double FolderMassValue;
static double FolderDampingValue;

//Extra toggles (unchanged from the original tweak)
static BOOL isNoiconflyEnable;
static BOOL isNoiconshakingEnable;
static BOOL isNoiconZoominSwitcher;
static BOOL isNoWallZoominSwitcher;

void preferencesthings(){
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.hoangdus.speedsterprefs"];

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
}

static void preferencesChanged(){ //runs at load and every time the prefs darwin notification fires
    preferencesthings();
}

//Folder slider mapping: perceptual (exponential) curve, 0% = exactly stock,
//fast end capped at 0.1 (same constant-ratio philosophy as the old speed sliders).
static double reverseFolderSliderValue(double input){ //track 0..0.9 -> stock multiplier 1.0..0.1
    double f = input / 0.9;
    f = MIN(MAX(f, 0.0), 1.0);
    return pow(0.1, f); //0% = exactly stock, fast end capped
}

//Diagnostics: budgeted append-only log, fresh per respring. Kept (slimmed) from
//the Fluid series: it never caused harm and makes any future regression diagnosable.
static NSString *diagLogPath = nil;
static NSInteger diagBudget = 0;

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

static void diagLogB(NSString *fmt, ...){ //budgeted variant for chatty call sites
    if (diagBudget <= 0) return;
    diagBudget--;
    va_list args; va_start(args, fmt);
    diagLogCore(fmt, args);
    va_end(args);
}

//Lock state tracking ----------------------------------------------------------
//The lock flag only GATES the folder scaling hooks (a folder cannot be opened
//while locked; the gate is cheap belt-and-braces so lock-screen animations are
//guaranteed stock by construction). There is deliberately NO restore machinery
//here: with zero long-lived object writes there is nothing to restore.
static volatile BOOL deviceLocked = YES; //SpringBoard always launches into the lock screen
static dispatch_source_t lockPollTimer;

static BOOL queryUILocked(void){
    Class cls = objc_getClass("SBLockScreenManager");
    if (!cls) return NO;
    id mgr = ((id(*)(Class, SEL))objc_msgSend)(cls, @selector(sharedInstance));
    if (!mgr) return NO;
    return !!((BOOL(*)(id, SEL))objc_msgSend)(mgr, @selector(isUILocked));
}

static void setDeviceLocked(BOOL locked, const char *source){
    if (locked == deviceLocked) return;
    int old = deviceLocked;
    deviceLocked = locked;
    diagLog(@"deviceLocked %d -> %d (%s)", old, locked, source);
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
    dispatch_source_set_event_handler(lockPollTimer, ^{
        setDeviceLocked(queryUILocked(), "poll");
    });
    dispatch_resume(lockPollTimer);
}

//Folder dock spring acceleration (Fluid-22, field-verified) --------------------
//The real zoom spring object is [SBFolderIconZoomAnimator dockAnimationSettings]
//(SBFFluidBehaviorSettings response 0.531 / dampingRatio 0.845) and it is created
//FRESH for every open/close and discarded afterwards (pointers never repeat).
//We scale it synchronously inside the _performAnimationToFraction hook, BEFORE
//%orig builds the spring from it. No restore needed: the object dies with the
//animation. The weak stock maps keep the original baseline so repeated calls on
//the same object (interruption re-entry) scale from stock and converge instead
//of compounding. Getter multiplication stays BANNED (Fluid-18 freeze disaster).
static NSMapTable *folderDockStockResponse;   //weak key -> NSNumber stock response
static NSMapTable *folderDockStockDamping;    //weak key -> NSNumber stock dampingRatio

static void initFolderDockMaps(void){
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        folderDockStockResponse = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory | NSMapTableObjectPointerPersonality valueOptions:NSMapTableStrongMemory];
        folderDockStockDamping = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory | NSMapTableObjectPointerPersonality valueOptions:NSMapTableStrongMemory];
    });
}

static void folderScaleDockValue(id obj, BOOL isResponse, double mult){
    if (!obj || mult == 1.0 || mult <= 0) return;
    SEL readSel = isResponse ? @selector(response) : @selector(dampingRatio);
    double cur = ((double(*)(id, SEL))objc_msgSend)(obj, readSel);
    NSMapTable *stocks = isResponse ? folderDockStockResponse : folderDockStockDamping;
    NSNumber *stockNum = [stocks objectForKey:obj];
    double stock;
    if (stockNum) {
        stock = [stockNum doubleValue];
    } else {
        stock = cur; //first sight: current value is the stock baseline
        [stocks setObject:@(stock) forKey:obj];
    }
    double target = stock * mult;
    if (fabs(cur - target) <= 0.0001) return; //already in place
    if (isResponse) [(id)obj setResponse:target];
    else [(id)obj setDampingRatio:target];
    diagLogB(@"[folder-fluid] dock %s %g->%g (x%.3f)", isResponse ? "response" : "dampingRatio", cur, target, mult);
}

//Folder BSAnimationSettings time dilation (Fluid-25/26/27, field-verified) -----
//SBReversibleLayerPropertyAnimator.animateWithSettings: family carries BaseBoard
//BSAnimationSettings (duration / mass / stiffness / damping / speed); the folder
//zoom spring is one of them. Acceleration = uniform time dilation: duration*mult,
//stiffness/(mult^2), damping*zeta/mult - omega scales by 1/mult (zeta slider
//independent, c*zeta/mult so each knob works alone or together).
//In-place capture/scale/restore (Fluid-25/26 hard lessons):
//  - NEVER pass a different object identity into the animation system
//  - ALWAYS restore stock values right after %orig
//  - mark in-flight objects (associated object) so nested calls cannot
//    double-scale (snowball k 341.51 -> 3.4e-6 => SIGABRT safe mode)
//The reversal path (_reverseWithSettings:) is not hooked - it stays stock.
static CFAbsoluteTime folderReadWindowUntil = 0; //opens when the folder zoom hook fires

static void *folderBSScaleSavedKey = &folderBSScaleSavedKey;
static void folderScaleBSAnimSettingsInPlace(id settings, const char *via){
    if (!settings) return;
    if (!isOnSpringBoard || deviceLocked) return;
    if (CFAbsoluteTimeGetCurrent() > folderReadWindowUntil) return;
    if (objc_getAssociatedObject(settings, folderBSScaleSavedKey)) return; //re-entrant: outer call already scaled this object
    //speed and bounce are independent knobs. mult dilates time (smaller = faster);
    //zeta scales the damping ratio (smaller = more visible bounce).
    double mult = 1.0;
    if (isFolderAnimationEnabled && FolderMassValue > 0.0005) mult = reverseFolderSliderValue(FolderMassValue);
    double zeta = 1.0;
    if (isFolderAnimationBounceEnabled && FolderDampingValue > 0.0005) zeta = reverseFolderSliderValue(FolderDampingValue);
    if (mult >= 1.0 && zeta >= 1.0) return;
    @try {
        NSString *cls = NSStringFromClass([settings class]);
        BOOL spring = [cls rangeOfString:@"Spring"].location != NSNotFound;
        NSMutableDictionary *saved = [NSMutableDictionary dictionary];
        if (spring) {
            double k = 0, c = 0;
            @try { k = ((double(*)(id, SEL))objc_msgSend)(settings, @selector(stiffness)); } @catch (NSException *e) { return; }
            @try { c = ((double(*)(id, SEL))objc_msgSend)(settings, @selector(damping)); } @catch (NSException *e) { return; }
            if (k <= 0 && c <= 0) return;
            saved[@"stiffness"] = @(k);
            saved[@"damping"] = @(c);
            [(id)settings setValue:@(k / (mult * mult)) forKey:@"stiffness"];
            [(id)settings setValue:@(c * zeta / mult) forKey:@"damping"];
            diagLogB(@"[rev-anim] via=%s SPRING k %g->%g c %g->%g zeta x%g", via, k, k / (mult * mult), c, c * zeta / mult, zeta);
        } else {
            double dur = 0;
            @try { dur = ((double(*)(id, SEL))objc_msgSend)(settings, @selector(duration)); } @catch (NSException *e) { return; }
            if (dur <= 0) return;
            saved[@"duration"] = @(dur);
            [(id)settings setValue:@(dur * mult) forKey:@"duration"];
            diagLogB(@"[rev-anim] via=%s TIMED dur %g->%g", via, dur, dur * mult);
        }
        objc_setAssociatedObject(settings, folderBSScaleSavedKey, saved, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch (NSException *e) {
        diagLogB(@"[rev-anim] scale threw %@", e);
    }
}
static void folderRestoreBSAnimSettings(id settings){
    if (!settings) return;
    @try {
        NSMutableDictionary *saved = objc_getAssociatedObject(settings, folderBSScaleSavedKey);
        if (!saved) return;
        for (NSString *key in saved) [(id)settings setValue:saved[key] forKey:key];
        objc_setAssociatedObject(settings, folderBSScaleSavedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch (NSException *e) {
        diagLogB(@"[rev-anim] restore threw %@", e);
    }
}

//Folder open/close zoom, iOS 17 write-side mechanism (Fluid-20..27) ------------
//Architecture (verified against iOS 17 runtime headers): SBFolderController
//_newAnimatorForZoomUp: creates an SBFolderIconZoomAnimator per open/close; the
//zoom spring is built inside _performAnimationToFraction:withCentralAnimationSettings:
//from the passed SBFAnimationSettings (SBHFolderZoomSettings.centralAnimationSettings)
//and from dockAnimationSettings. On iOS 17 the legacy setMass:/setDamping: hooks
//are dead code for folders (those setters fire once at boot only), so we scale the
//passed objects directly here: write scaled values BEFORE %orig (the animation
//snapshots its parameters there) and restore the stock values right after.
%group FolderZoom

//Diagnostics: identifies which animator class actually runs. If the speed slider
//ever fails to take effect, these lines say whether the hook fired at all.
%hook SBFolderController
    - (id)_newAnimatorForZoomUp:(bool)arg1 {
        id animator = %orig;
        if (isOnSpringBoard && animator && !deviceLocked) {
            diagLogB(@"[folder-animator] zoomUp=%d class=%@", arg1, NSStringFromClass([animator class]));
        }
        return animator;
    }
%end

%hook SBFolderIconZoomAnimator
    - (void)_performAnimationToFraction:(double)arg1 withCentralAnimationSettings:(id)arg2 delay:(double)arg3 alreadyAnimating:(bool)arg4 sharedCompletion:(id)arg5 {
        //open the BSAnimationSettings scale window for the animation's lifetime
        //(the real spring may read per-frame via the reversible animators)
        if (isOnSpringBoard && !deviceLocked) {
            folderReadWindowUntil = CFAbsoluteTimeGetCurrent() + 2.5;
        }
        BOOL applied = NO;
        double savedMass = 0, savedDamping = 0;
        if (isOnSpringBoard && !deviceLocked && arg2
            && [arg2 respondsToSelector:@selector(mass)] && [arg2 respondsToSelector:@selector(damping)]) {
            double stockMass = [(id)arg2 mass];
            double stockDamping = [(id)arg2 damping];
            double massMult = 1.0, dampingMult = 1.0;
            if (isFolderAnimationEnabled && FolderMassValue > 0.0005) {
                massMult = reverseFolderSliderValue(FolderMassValue);
            }
            if (isFolderAnimationEnabled && isFolderAnimationBounceEnabled && FolderDampingValue > 0.0005) {
                dampingMult = reverseFolderSliderValue(FolderDampingValue);
            }
            if (massMult != 1.0 || dampingMult != 1.0) {
                savedMass = stockMass;
                savedDamping = stockDamping;
                if (massMult != 1.0) [(id)arg2 setMass:stockMass * massMult];
                if (dampingMult != 1.0) [(id)arg2 setDamping:stockDamping * dampingMult];
                applied = YES;
                diagLogB(@"[folder-zoom] frac=%g already=%d mass %g x%.3f damping %g x%.3f obj=%p %@",
                         arg1, arg4, stockMass, massMult, stockDamping, dampingMult, arg2, NSStringFromClass([arg2 class]));
                //scale the REAL zoom spring object (fresh per open/close, dies after)
                if ([self respondsToSelector:@selector(dockAnimationSettings)]) {
                    id dock = [self performSelector:@selector(dockAnimationSettings)];
                    if (dock && [dock respondsToSelector:@selector(response)]
                            && [dock respondsToSelector:@selector(setResponse:)]) {
                        folderScaleDockValue(dock, YES, massMult);
                        folderScaleDockValue(dock, NO, dampingMult);
                    }
                }
            }
        }
        %orig;
        if (applied) { //the animation snapshotted its parameters inside %orig; restore stock
            [(id)arg2 setMass:savedMass];
            [(id)arg2 setDamping:savedDamping];
        }
    }
%end
%end

//Reversible layer animators carry the REAL zoom timing (BSAnimationSettings) ---
%group ReversibleAnim
%hook SBReversibleLayerPropertyAnimator
    - (void)animateWithSettings:(id)arg1 completion:(id)arg2 {
        folderScaleBSAnimSettingsInPlace(arg1, "animate");
        %orig;
        folderRestoreBSAnimSettings(arg1);
    }
    - (void)_animateFromRelativeValue:(double)arg1 toRelativeValue:(double)arg2 withSettings:(id)arg3 beginTime:(id)arg4 {
        folderScaleBSAnimSettingsInPlace(arg3, "rel");
        %orig;
        folderRestoreBSAnimSettings(arg3);
    }
    - (void)_animateFromValue:(double)arg1 toValue:(double)arg2 withSettings:(id)arg3 beginTime:(id)arg4 {
        folderScaleBSAnimSettingsInPlace(arg3, "val");
        %orig;
        folderRestoreBSAnimSettings(arg3);
    }
    - (id)_additiveAnimationForKeyPath:(id)arg1 withSettings:(id)arg2 beginTime:(id)arg3 fromRelativeValue:(double)arg4 toRelativeValue:(double)arg5 {
        folderScaleBSAnimSettingsInPlace(arg2, "add");
        id result = %orig;
        folderRestoreBSAnimSettings(arg2);
        return result;
    }
%end
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

//Lock-state transitions from the class that owns them (iOS 17 selectors verified
//against the runtime dump; Logos silently skips wherever they don't exist).
//The class is bound at %init time via objc_getClass.
%group LockScreenTracker
%hook SBLockScreenManager
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

%ctor {
    isOnSpringBoard = [[[NSBundle mainBundle] bundleIdentifier] isEqual:@"com.apple.springboard"];

    initFolderDockMaps(); //build maps BEFORE any hook can fire (a dispatch_once gate
                          //inside a hooked call path = same-thread reentry = self-deadlock
                          //class, the Fluid-33/34 NSLock lesson)

    %init(_ungrouped); //activate all hooks outside explicit %groups

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)preferencesChanged, CFSTR("com.hoangdus.speedsterprefs-updated"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	preferencesChanged();

	//Diagnostics. Injection is SpringBoard-only (Speedster.plist) since the Fresh
	//rebuild has no in-app features - no multi-process log tearing, no sandbox
	//write failures, no wasted injection.
	diagLogPath = @"/var/mobile/Library/SpeedsterDiag.log";
	diagBudget = 500;
	remove(diagLogPath.fileSystemRepresentation); //fresh log per respring
	diagLog(@"Speedster 2.2.0-Fresh-1 loaded in SpringBoard, deviceLocked(assumed)=%d", deviceLocked);
	//boot self-check: one line snapshot of install + feature state
	diagLog(@"[selfcheck] folder=%d speedSlider=%g bounce=%d slider=%g | fly=%d shake=%d nozoom=%d noWPzoom=%d",
	        isFolderAnimationEnabled, FolderMassValue, isFolderAnimationBounceEnabled, FolderDampingValue,
	        isNoiconflyEnable, isNoiconshakingEnable, isNoiconZoominSwitcher, isNoWallZoominSwitcher);

	//Lock state tracking (gate only - see note above)
	Class lockMgrClass = objc_getClass("SBLockScreenManager");
	if (lockMgrClass) {
		%init(LockScreenTracker, SBLockScreenManager = lockMgrClass);
		diagLog(@"LockScreenTracker hooks initialized");
	} else {
		diagLog(@"SBLockScreenManager class NOT found!");
	}
	watchLockState();
	startLockPolling();

	//Folder zoom acceleration (iOS 17 write-side mechanism - see FolderZoom note above)
	Class folderAnimatorClass = objc_getClass("SBFolderIconZoomAnimator");
	Class folderControllerClass = objc_getClass("SBFolderController");
	if (folderAnimatorClass && folderControllerClass) {
		%init(FolderZoom, SBFolderIconZoomAnimator = folderAnimatorClass, SBFolderController = folderControllerClass);
		diagLog(@"FolderZoom hooks initialized (animator+controller found)");
	} else {
		diagLog(@"FolderZoom classes missing: animator=%p controller=%p", folderAnimatorClass, folderControllerClass);
	}

	//Reversible layer animators carry the REAL zoom timing (BSAnimationSettings)
	Class reversibleClass = objc_getClass("SBReversibleLayerPropertyAnimator");
	if (reversibleClass) {
		%init(ReversibleAnim, SBReversibleLayerPropertyAnimator = reversibleClass);
		diagLog(@"ReversibleAnim hooks initialized");
	} else {
		diagLog(@"SBReversibleLayerPropertyAnimator NOT found");
	}
}
