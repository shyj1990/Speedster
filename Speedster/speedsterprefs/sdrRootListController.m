#include "sdrRootListController.h"
#import  "spawn.h"
#import <dlfcn.h>
#import <CoreFoundation/CoreFoundation.h>

//Resolve the jailbreak root prefix at runtime. This dylib is installed inside
//the preference bundle (e.g. <jbroot>/Library/PreferenceBundles/SpeedsterPrefs.bundle),
//where <jbroot> is /var/jb on rootless bootstraps and a randomized path on
//roothide, so its own load path gives us the prefix without hardcoding it.
static NSString *jbrootPrefix(void){
    Dl_info info;
    if (dladdr((void *)&jbrootPrefix, &info) && info.dli_fname) {
        NSString *selfPath = [NSString stringWithUTF8String:info.dli_fname];
        // The preference bundle always lives under /Library/PreferenceBundles
        // inside the jailbreak root, so use that as the path anchor.
        NSRange anchor = [selfPath rangeOfString:@"/Library/PreferenceBundles"];
        if (anchor.location != NSNotFound && anchor.location > 0) {
            return [selfPath substringToIndex:anchor.location];
        }
    }
    return @"/var/jb"; //rootless fallback
}

// ---------------------------------------------------------------------------
// Slider + percentage input cluster
//
// The stock PSSliderCell lets its UISlider fill the whole row. We wrap that
// UISlider inside a container that also hosts a small text field on the right
// end of the row. Typing a percentage (0-100, percent of the track) moves the
// knob; dragging the knob updates the number. The text field writes the same
// preference key the slider uses, so the main tweak needs no changes.
// ---------------------------------------------------------------------------

static NSString * const kSpeedsterPrefsDomain = @"com.hoangdus.speedsterprefs";
static NSString * const kSpeedsterUpdateNotification = @"com.hoangdus.speedsterprefs-updated";

//Every slider key in Root.plist that should get the percentage input field
static NSArray *speedsterSliderKeys(void){
    static NSArray *keys;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        keys = @[@"FineTuneSpeedValue", @"FineTuneBounceValue", @"DurationMassValue",
                 @"DampingValue", @"FolderMassValue", @"FolderDampingValue",
                 @"Screensleepvalue", @"Screenwakevalue"];
    });
    return keys;
}

@interface SpeedsterSliderCluster : UIView <UITextFieldDelegate>
@property (nonatomic, retain) UISlider *slider;
@property (nonatomic, retain) UITextField *textField;
@property (nonatomic, copy) NSString *prefKey;
@end

@implementation SpeedsterSliderCluster

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        _textField = [[UITextField alloc] initWithFrame:CGRectZero];
        _textField.borderStyle = UITextBorderStyleRoundedRect;
        _textField.textAlignment = NSTextAlignmentCenter;
        _textField.font = [UIFont systemFontOfSize:13];
        _textField.keyboardType = UIKeyboardTypeDecimalPad;
        _textField.placeholder = @"%";
        _textField.delegate = self;
        [self addSubview:_textField];

        //The decimal pad has no return key, so add a "done" accessory bar
        UIToolbar *bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
        UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard)];
        bar.items = @[space, done];
        _textField.inputAccessoryView = bar;
    }
    return self;
}

//Adopt the stock slider from the cell (keep its existing target-action so
//PSSliderTableCell's own save logic keeps working while the user drags)
- (void)configureWithKey:(NSString *)key slider:(UISlider *)slider {
    self.prefKey = key;
    if (_slider != slider) {
        [_slider removeTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        [_slider removeFromSuperview];
        _slider = slider;
        slider.translatesAutoresizingMaskIntoConstraints = YES; //our frames win over any stale constraints
        [_slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:slider];
    }
    [self setNeedsLayout];
    [self refreshText];
}

- (void)sliderChanged:(UISlider *)sender {
    [self refreshText]; //knob dragged -> number follows
}

- (void)dismissKeyboard {
    [_textField resignFirstResponder]; //commit happens in textFieldDidEndEditing
}

- (double)speedsterCurrentValue {
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:kSpeedsterPrefsDomain];
    NSNumber *num = prefs[_prefKey];
    return num ? num.doubleValue : _slider.value;
}

- (void)refreshText {
    if (_textField.isFirstResponder) return; //never clobber while typing
    double v = [self speedsterCurrentValue];
    double mn = _slider.minimumValue, mx = _slider.maximumValue;
    double pct = (mx > mn) ? (v - mn) / (mx - mn) * 100.0 : 0.0;
    pct = MIN(MAX(pct, 0.0), 100.0);
    _textField.text = [NSString stringWithFormat:@"%.0f%%", pct];
}

//Number committed -> move the knob and persist to the same pref key the
//slider uses, then post the same darwin notification the plist's
//PostNotification uses so the main tweak picks the value up
- (void)commitEditing {
    NSString *raw = [_textField.text stringByReplacingOccurrencesOfString:@"%" withString:@""];
    double pct = [raw doubleValue];
    pct = MIN(MAX(pct, 0.0), 100.0);
    double mn = _slider.minimumValue, mx = _slider.maximumValue;
    double v = mn + (mx - mn) * pct / 100.0;

    NSMutableDictionary *prefs = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:kSpeedsterPrefsDomain] mutableCopy];
    if (!prefs) prefs = [[NSMutableDictionary alloc] init];
    prefs[_prefKey] = @(v);
    [[NSUserDefaults standardUserDefaults] setPersistentDomain:prefs forName:kSpeedsterPrefsDomain];
    [[NSUserDefaults standardUserDefaults] synchronize];

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kSpeedsterUpdateNotification, NULL, NULL, YES);

    [_slider setValue:(float)v animated:YES];
    [self refreshText];
}

//UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}
- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self commitEditing];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.superview) return;
    self.frame = self.superview.bounds;
    CGFloat pad = 10, tfW = 66, tfH = 26, gap = 8;
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    if (_slider.superview != self) { //self-heal if the cell ever re-parents the slider
        [self addSubview:_slider];
    }
    _slider.frame = CGRectMake(pad, (h - 31) / 2.0, w - tfW - gap - pad * 2, 31);
    _textField.frame = CGRectMake(w - pad - tfW, (h - tfH) / 2.0, tfW, tfH);
}

@end

@implementation sdrRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    NSArray *chosenIDs = @[@"2", @"3", @"4", @"5"];
    self.savedSpecifiers = (_savedSpecifiers) ?: [[NSMutableDictionary alloc] init];
    for(PSSpecifier *specifier in [self specifiersForIDs:chosenIDs]) {
     [self.savedSpecifiers setObject:specifier forKey:[specifier propertyForKey:@"id"]];
    }
	}    
	return _specifiers;
}

//BIG BRAIN LINK: https://www.reddit.com/r/jailbreakdevelopers/comments/e965nj/comment/fbf2xcv/
-(void)updateSpecifierVisibility:(BOOL)animated {
  NSDictionary *preferences = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.hoangdus.speedsterprefs"];

  //Check if our switch is set to NO, then remove fine tune slider
  if(![preferences[@"isFineTuneSpeedEnable"] boolValue]) {
    [self removeSpecifier:self.savedSpecifiers[@"3"] animated:animated];
  // If the switch is set to YES, then add back fine tune slider
  } else if(![self containsSpecifier:self.savedSpecifiers[@"3"]]) {
    [self insertSpecifier:self.savedSpecifiers[@"3"] atIndex:4 animated:animated];
  }

  //Check if our switch is set to YES, then remove preset
  if([preferences[@"isFineTuneSpeedEnable"] boolValue]) {
    [self removeSpecifier:self.savedSpecifiers[@"2"] animated:animated];
  // If the switch is set to NO, add back the preset
  } else if(![self containsSpecifier:self.savedSpecifiers[@"2"]]) {
    [self insertSpecifier:self.savedSpecifiers[@"2"] atIndex:4 animated:animated];
  }

  //Check if our switch is set to NO, then remove fine tune slider
  if(![preferences[@"isFineTuneBounceEnable"] boolValue]) {
    [self removeSpecifier:self.savedSpecifiers[@"5"] animated:animated];
  // If the switch is set to YES, then add back fine tune slider
  } else if(![self containsSpecifier:self.savedSpecifiers[@"5"]]) {
    [self insertSpecifier:self.savedSpecifiers[@"5"] atIndex:7 animated:animated];
  }

  //Check if our switch is set to YES, then remove preset
  if([preferences[@"isFineTuneBounceEnable"] boolValue]) {
    [self removeSpecifier:self.savedSpecifiers[@"4"] animated:animated];
  // If the switch is set to NO, add back the preset
  } else if(![self containsSpecifier:self.savedSpecifiers[@"4"]]) {
    [self insertSpecifier:self.savedSpecifiers[@"4"] atIndex:7 animated:animated];
  }
}

-(void)reloadSpecifiers {
  [super reloadSpecifiers];
  [self updateSpecifierVisibility:NO];
}

-(void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
  [super setPreferenceValue:value specifier:specifier];
  [self updateSpecifierVisibility:YES];
}

-(void)viewDidLoad {
  [super viewDidLoad];
  [self updateSpecifierVisibility:NO];
}

//---- Percentage input field on every slider row -----------------------------

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    [self speedsterDecorateSliderCell:cell];
    return cell;
}

- (UISlider *)speedsterFindSliderIn:(UIView *)view {
    if ([view isKindOfClass:[UISlider class]]) return (UISlider *)view;
    for (UIView *v in view.subviews) {
        UISlider *s = [self speedsterFindSliderIn:v];
        if (s) return s;
    }
    return nil;
}

//If the cell hosts a stock slider (and its specifier key is one of ours),
//wrap the slider in a SpeedsterSliderCluster that adds the percentage field
- (void)speedsterDecorateSliderCell:(UITableViewCell *)cell {
    if (!cell) return;
    UISlider *slider = [self speedsterFindSliderIn:cell];
    if (!slider) return;

    PSSpecifier *spec = nil;
    if ([cell respondsToSelector:@selector(specifier)]) {
        spec = [cell performSelector:@selector(specifier)];
    }
    NSString *key = [spec propertyForKey:@"key"];
    if (![speedsterSliderKeys() containsObject:key]) return;

    SpeedsterSliderCluster *cluster = nil;
    for (UIView *v in cell.subviews) {
        if ([v isKindOfClass:[SpeedsterSliderCluster class]]) {
            cluster = (SpeedsterSliderCluster *)v;
            break;
        }
    }
    if (!cluster) {
        cluster = [[SpeedsterSliderCluster alloc] initWithFrame:cell.bounds];
        [cell addSubview:cluster];
    }
    [cluster configureWithKey:key slider:slider];
}

- (void)respring:(id)sender{ //handle the "respring" button
    pid_t pid;
    NSString *jb = jbrootPrefix();

    //Preferred: sbreload (resprings cleanly and waits for SpringBoard to return)
    NSString *sbreloadPath = [jb stringByAppendingString:@"/usr/bin/sbreload"];
    const char *sbreloadArgv[] = {sbreloadPath.fileSystemRepresentation, NULL};
    if (posix_spawn(&pid, sbreloadArgv[0], NULL, NULL, (char *const *)sbreloadArgv, NULL) != 0) {
        //Fallback: plain respring by killing SpringBoard (same uid, always allowed)
        NSString *killallPath = [jb stringByAppendingString:@"/usr/bin/killall"];
        const char *killallArgv[] = {killallPath.fileSystemRepresentation, "SpringBoard", NULL};
        posix_spawn(&pid, killallArgv[0], NULL, NULL, (char *const *)killallArgv, NULL);
    }
}

- (void)github{
  [[UIApplication sharedApplication]openURL:[NSURL URLWithString:@"https://github.com/Hoangdus/Speedster"]options:@{} completionHandler:nil];
}

- (void)twitter{
  [[UIApplication sharedApplication]openURL:[NSURL URLWithString:@"https://twitter.com/Hoangdev23"]options:@{} completionHandler:nil];
}

- (void)paypal{
  [[UIApplication sharedApplication]openURL:[NSURL URLWithString:@"https://ko-fi.com/hoangdus"]options:@{} completionHandler:nil];
}

@end

@implementation SdrHeaderCell
- (id)initWithSpecifier:(PSSpecifier *)specifier {
  self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];

  if (self) {
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 30, self.frame.size.width, 60)];
    title.numberOfLines = 1;
    title.font = [UIFont systemFontOfSize:50];
    title.text = @"Speedster";
    title.textColor = [UIColor orangeColor];
    title.textAlignment = NSTextAlignmentCenter;
    [self addSubview:title];

    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 85, self.frame.size.width, 30)];
    subtitle.numberOfLines = 1;
    subtitle.font = [UIFont systemFontOfSize:20];
    subtitle.text = @"By HoangDus";
    subtitle.textColor = [UIColor grayColor];
    subtitle.textAlignment = NSTextAlignmentCenter;
    [self addSubview:subtitle];
  }
  return self;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)arg1 {
  return 150.0;
}
@end
