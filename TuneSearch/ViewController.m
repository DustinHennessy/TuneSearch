//
//  ViewController.m
//  TuneSearch
//
//  Created by Dustin Hennessy on 6/15/15.
//  Copyright (c) 2015 DustinHennessy. All rights reserved.
//

#import "ViewController.h"
#import "ResultsTableViewCell.h"
#import "Images.h"


@interface ViewController ()

@property (nonatomic, strong) NSMutableArray        *resultsArray;
@property (nonatomic, strong) Reachability          *hostReach;
@property (nonatomic, strong) Reachability          *internetReach;
@property (nonatomic, strong) Reachability          *wifiReach;
@property (nonatomic, strong) NSString              *hostName;
@property (nonatomic, strong) IBOutlet UISearchBar  *musicSearchBar;
@property (nonatomic, strong) IBOutlet UITableView  *resultsTableView;


@end

@implementation ViewController

BOOL internetAvailable;
BOOL serverAvailable;


- (IBAction)shareButtonPressed:(id)sender {
    
    NSArray *sharingArray = [_resultsTableView indexPathsForSelectedRows];
    NSMutableArray *stuffToShare = [[NSMutableArray alloc] init];
    
    for (NSIndexPath *objPath in sharingArray) {
        NSDictionary *currentThing = [_resultsArray objectAtIndex:objPath.row];
        [stuffToShare addObject:[currentThing objectForKey:@"collectionName"]];
    }
    
    UIActivityViewController *shareVC = [[UIActivityViewController alloc]initWithActivityItems:stuffToShare applicationActivities:nil];
    
    [self presentViewController:shareVC animated:true completion:nil];
}

- (IBAction)smsButtonPressed:(id)sender {

    if ([MFMessageComposeViewController canSendText]) {
        MFMessageComposeViewController *msgController = [[MFMessageComposeViewController alloc] init];
        [msgController setBody:@"Yout text message here"];
        msgController.messageComposeDelegate = self;
        [self presentViewController:msgController animated:true completion:nil];
        
    }
    
}


- (BOOL)fileIsLocal:(NSString *)filename {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *savedImagePath = [NSTemporaryDirectory() stringByAppendingString:filename];
    
    return [fileManager fileExistsAtPath:savedImagePath];

}


- (void)getImageFromServer:(NSString *)localFileName fromURL:(NSString *)remoteFileName {
    
    NSString *savedImagePath = [NSTemporaryDirectory() stringByAppendingString:localFileName];
    NSLog(@"path:%@",savedImagePath);
    
    NSURL *remoteURL = [[NSURL alloc] initWithString:remoteFileName];
    NSData *imageData = [NSData dataWithContentsOfURL:remoteURL];
    UIImage *imageTemp = [UIImage imageWithData:imageData];
    if (imageTemp != nil) {
        [imageData writeToFile:savedImagePath atomically:false];
        NSLog(@"Got %@", localFileName);
    }
    
}


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self downloadFile];
}


#pragma mark- Table View Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return _resultsArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *cellIdentifier = @"Cell";
    ResultsTableViewCell *cell = (ResultsTableViewCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    
    cell.resultsLabel.text = [[_resultsArray objectAtIndex:indexPath.row] objectForKey:@"collectionName"];
    cell.artistLabel.text = [[_resultsArray objectAtIndex:indexPath.row] objectForKey:@"artistName"];
    NSString *remoteFilename = [[_resultsArray objectAtIndex:indexPath.row] objectForKey:@"artworkUrl60"];
    NSString *filename = [remoteFilename lastPathComponent];
    NSString *filenameWithPath = [NSTemporaryDirectory() stringByAppendingString:filename];
    NSLog(@"loading filename:%@",filename);
    cell.albumImageView.image = [UIImage imageNamed:filenameWithPath];
    
    return cell;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryNone;
}

- (void)downloadFile {
    NSLog(@"download file text");
    
    NSURL *fileURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/search?term=%@", _hostName,_musicSearchBar.text]];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:fileURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60];

    [NSURLConnection sendAsynchronousRequest: urlRequest queue:[[NSOperationQueue alloc] init] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (([data length] > 0) && (error == nil)) {
            NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"Got Data: %@",dataString);
            
            NSError *jsonError = nil;
            NSJSONSerialization *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
            _resultsArray = [(NSDictionary *) json objectForKey:@"results"];
            if (_resultsArray.count > 0) {
                for (NSDictionary *musicInfoString in _resultsArray) {
                    NSString *remoteFilename = [musicInfoString objectForKey:@"artworkUrl60"];
                    NSLog(@"rf:%@",remoteFilename);
                    NSString *filename = [remoteFilename lastPathComponent];
                    NSLog(@"fn:%@",filename);
                    
                    [self getImageFromServer:filename fromURL:remoteFilename];
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [_resultsTableView reloadData];
            });
        } else if (([data length] == 0) && (error == nil)) {
            UIAlertView *alert = [[UIAlertView alloc]
                                  initWithTitle:@"No Data Found" message:@"It looks like we weren't able to find a file" delegate:self
                                  cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alert show];
        } else if (error.code == -1009) {
            UIAlertView *alert = [[UIAlertView alloc]
                                  initWithTitle:@"Internet Disabled" message:@"It looks like your device may not be connected to the Internet. Please make sure the Internet is on and try the update again." delegate:self
                                  cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alert show];
        } else if (error != nil) {
            NSLog(@"Error = %@", error);
            UIAlertView *alert = [[UIAlertView alloc]
                                  initWithTitle:@"Unknown Error" message:[NSString stringWithFormat:@"An error has occured. Please contact support. Error %@",error] delegate:self
                                  cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alert show];
        }
    }];
}

#pragma mark - Connectivity methods

- (void)updateReachabilityStatus:(Reachability *)curReach {
    NSParameterAssert([curReach isKindOfClass: [Reachability class]]);
    NetworkStatus netStatus = [curReach currentReachabilityStatus];
    if(curReach == _hostReach) {
        switch (netStatus)
        {
            case NotReachable:
            {
                NSLog(@"Server Not Available");
                serverAvailable = NO;
                break;
            }
                
            case ReachableViaWWAN:
            {
                NSLog(@"Server Reachable via WWAN");
                serverAvailable = YES;
                break;
            }
            case ReachableViaWiFi:
            {
                NSLog(@"Server Reachable via WiFi");
                serverAvailable = YES;
                break;
            }
        }
    }
    if(curReach == _internetReach || curReach == _wifiReach) {
        switch (netStatus)
        {
            case NotReachable:
            {
                NSLog(@"Internet Not Available");
                internetAvailable = NO;
                break;
            }
                
            case ReachableViaWWAN:
            {
                NSLog(@"Internet Reachable via WWAN");
                internetAvailable = YES;
                break;
            }
            case ReachableViaWiFi:
            {
                NSLog(@"Internet Reachable via WiFi");
                internetAvailable = YES;
                break;
            }
        }
    }
}

- (void)reachabilityChanged:(NSNotification*)note
{
    Reachability* curReach = [note object];
    [self updateReachabilityStatus:curReach];
}




#pragma mark - Life Cyle Methods

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _hostName = @"itunes.apple.com";
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil]; //listener
    
    
    _hostReach = [Reachability reachabilityWithHostName:_hostName];
    [_hostReach startNotifier]; //Sender to main thread
    [self updateReachabilityStatus:_hostReach];
    
    _internetReach = [Reachability reachabilityForInternetConnection];
    [_internetReach startNotifier];
    [self updateReachabilityStatus:_internetReach];
    
    _wifiReach = [Reachability reachabilityForLocalWiFi];
    [_wifiReach startNotifier];
    [self updateReachabilityStatus:_wifiReach];
    
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
