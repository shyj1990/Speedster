#include "sdrRootListController.h"
#import  "spawn.h"
#import <dlfcn.h>

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
