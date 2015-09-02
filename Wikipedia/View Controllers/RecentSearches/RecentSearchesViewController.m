//  Created by Monte Hurd on 11/17/14.
//  Copyright (c) 2014 Wikimedia Foundation. Provided under MIT-style license; please copy and modify!

#import "RecentSearchesViewController.h"
#import "RecentSearchCell.h"
#import "WikiGlyphButton.h"
#import "WikiGlyphLabel.h"
#import "WikiGlyph_Chars.h"
#import "WikipediaAppUtils.h"
#import "UIViewController+WMFHideKeyboard.h"
#import "UIView+TemporaryAnimatedXF.h"
#import "Wikipedia-Swift.h"
#import "UIColor+WMFHexColor.h"

static CGFloat const cellHeight           = 70.f;
static CGFloat const trashFontSize        = 30.f;
static NSInteger const trashColor         = 0x777777;
static NSString* const pListFileName      = @"Recent.plist";
static NSUInteger const recentSearchLimit = 100.f;

@interface RecentSearchesViewController ()

@property (strong, nonatomic) IBOutlet UITableView* table;
@property (strong, nonatomic) IBOutlet UILabel* headingLabel;
@property (strong, nonatomic) IBOutlet WikiGlyphButton* trashButton;

@property (strong, nonatomic) NSMutableArray* tableDataArray;

@end

@implementation RecentSearchesViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableDataArray = @[].mutableCopy;

    [self setupTrashButton];
    [self setupHeadingLabel];
    [self setupTable];

    [self loadDataArrayFromFile];

    [self updateTrashButtonEnabledState];

    [self.table setBackgroundColor:[UIColor clearColor]];
    self.table.backgroundView.backgroundColor = [UIColor clearColor];
}

- (NSUInteger)recentSearchesItemCount {
    return [self.tableDataArray count];
}

- (void)setupTable {
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;

    [self.table registerNib:[UINib nibWithNibName:@"RecentSearchCell" bundle:nil] forCellReuseIdentifier:@"RecentSearchCell"];
}

- (void)setupHeadingLabel {
    self.headingLabel.text = MWLocalizedString(@"search-recent-title", nil);
}

- (void)setupTrashButton {
    self.trashButton.backgroundColor = [UIColor clearColor];
    [self.trashButton.label setWikiText:WIKIGLYPH_TRASH color:[UIColor wmf_colorWithHex:trashColor alpha:1.0f]
                                   size:trashFontSize
                         baselineOffset:1];

    self.trashButton.accessibilityLabel  = MWLocalizedString(@"menu-trash-accessibility-label", nil);
    self.trashButton.accessibilityTraits = UIAccessibilityTraitButton;

    [self.trashButton addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                   action:@selector(trashButtonTapped)]];
}

- (void)saveTerm:(NSString*)term
       forDomain:(NSString*)domain
            type:(SearchType)searchType {
    if (!term || (term.length == 0)) {
        return;
    }
    if (!domain || (domain.length == 0)) {
        return;
    }

    NSDictionary* termDict = [self dataForTerm:term domain:domain];
    if (termDict) {
        [self removeTerm:term forDomain:domain];
    }

    [self.tableDataArray insertObject:@{
         @"term": term,
         @"domain": domain,
         @"timestamp": [NSDate date],
         @"type": @(searchType)
     } atIndex:0];

    if (self.tableDataArray.count > recentSearchLimit) {
        self.tableDataArray = [self.tableDataArray subarrayWithRange:NSMakeRange(0, recentSearchLimit)].mutableCopy;
    }

    [self saveDataArrayToFile];
    [self.table reloadData];
}

- (void)updateTrashButtonEnabledState {
    self.trashButton.enabled = (self.tableDataArray.count > 0) ? YES : NO;
}

- (void)removeTerm:(NSString*)term
         forDomain:(NSString*)domain {
    NSDictionary* termDict = [self dataForTerm:term domain:domain];
    if (termDict) {
        [self.tableDataArray removeObject:termDict];
        [self saveDataArrayToFile];
    }
}

- (void)removeAllTerms {
    [self.tableDataArray removeAllObjects];
    [self saveDataArrayToFile];
}

- (NSDictionary*)dataForTerm:(NSString*)term
                      domain:(NSString*)domain {
    // For now just match on the search term, not the domain or other fields.
    return [self.tableDataArray wmf_firstMatchForPredicate:[NSPredicate predicateWithFormat:@"(term == %@)", term]];
    //return [self.tableDataArray wmf_firstMatchForPredicate:[NSPredicate predicateWithFormat:@"(term == %@) AND (domain == %@)", term, domain]];
}

- (NSString*)getFilePath {
    NSArray* paths               = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:pListFileName];
}

- (void)saveDataArrayToFile {
    NSError* error;
    NSString* path         = [self getFilePath];
    NSFileManager* manager = [NSFileManager defaultManager];
    if ([manager isDeletableFileAtPath:path]) {
        [manager removeItemAtPath:path error:&error];
    }

    if (![manager fileExistsAtPath:path]) {
        [self.tableDataArray writeToFile:path atomically:YES];
    }

    [self updateTrashButtonEnabledState];
}

- (void)loadDataArrayFromFile {
    NSString* path = [self getFilePath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSArray* a = [[NSArray alloc] initWithContentsOfFile:path];
        self.tableDataArray = a.mutableCopy;
    }
}

- (void)trashButtonTapped {
    if (!self.trashButton.enabled) {
        return;
    }

    [self.trashButton animateAndRewindXF:CATransform3DMakeScale(1.2f, 1.2f, 1.0f)
                              afterDelay:0.0
                                duration:0.1
                                    then:^{
        [self showDeleteAllDialog];
    }];
}

- (void)showDeleteAllDialog {
    UIAlertView* dialog =
        [[UIAlertView alloc] initWithTitle:MWLocalizedString(@"search-recent-clear-confirmation-heading", nil)
                                   message:MWLocalizedString(@"search-recent-clear-confirmation-sub-heading", nil)
                                  delegate:self
                         cancelButtonTitle:MWLocalizedString(@"search-recent-clear-cancel", nil)
                         otherButtonTitles:MWLocalizedString(@"search-recent-clear-delete-all", nil), nil];
    [dialog show];
}

- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.cancelButtonIndex != buttonIndex) {
        [self deleteAllRecentSearchItems];
    }
}

- (void)deleteAllRecentSearchItems {
    [self removeAllTerms];
    [self.table reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (CGFloat)tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath {
    return cellHeight;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return self.tableDataArray.count;
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    static NSString* cellId = @"RecentSearchCell";
    RecentSearchCell* cell  = (RecentSearchCell*)[tableView dequeueReusableCellWithIdentifier:cellId forIndexPath:indexPath];

    NSString* term = self.tableDataArray[indexPath.row][@"term"];
    [cell.label setText:term];

    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView*)tableView canEditRowAtIndexPath:(NSIndexPath*)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView*)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath*)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString* term   = self.tableDataArray[indexPath.row][@"term"];
        NSString* domain = self.tableDataArray[indexPath.row][@"domain"];
        [self removeTerm:term forDomain:domain];

        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
    NSString* term = self.tableDataArray[indexPath.row][@"term"];

    [self.delegate recentSearchController:self didSelectSearchTerm:term];
}

- (void)scrollViewWillBeginDragging:(UIScrollView*)scrollView {
    [self wmf_hideKeyboard];
}

@end
