//
//  ViewController.m
//  BlueToothApp
//
//  Created by ShaoLing on 5/1/14.
//  Copyright (c) 2014 dastone.cn. All rights reserved.
//

#import "ViewController.h"


#define TRANSFER_SERVICE_UUID           @"D63D44E5-E798-4EA5-A1C0-3F9EEEC2CDEB"
//#define TRANSFER_SERVICE_UUID           nil
#define TRANSFER_CHARACTERISTIC_UUID    @"1652CAD2-6B0D-4D34-96A0-75058E606A98"


@interface ViewController ()

@property (strong, nonatomic) CBCentralManager  *centralManager;
@property (strong, nonatomic) CBPeripheral      *discoveredPeripheral;
@property (strong, nonatomic) NSMutableData     *data;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;

@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UISwitch *discoverSwitch;

@end

@implementation ViewController


- (IBAction)valueChanged:(UISwitch *)sender {
    self.discoverSwitch = sender;
    
    if (self.discoverSwitch.on) {
        NSLog(@"switch on start scan");
        [self scan];
    } else {
        NSLog(@"switch off cancel connections");
        [self cleanup];
        
    }
}


- (void)cleanup{
    if (!self.discoveredPeripheral.state ) {
        return;
    }
    
    if (self.discoveredPeripheral.services) {
        for (CBService *serivce in self.discoveredPeripheral.services){
            if (serivce.characteristics) {
                for (CBCharacteristic *characteristic in serivce.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
                            [self.discoveredPeripheral setNotifyValue: NO forCharacteristic:characteristic];
                            NSLog(@"cancel peripheral connection");
                            self.textView.text = [self.textView.text stringByAppendingFormat:@"\ndisconnect %@", self.discoveredPeripheral.name];
                            [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
                            return;
                        }
                    }
                }
            }
        }
    }
    NSLog(@"cancel peripheral connection");
    self.textView.text = [self.textView.text stringByAppendingFormat:@"\ndisconnect %@", self.discoveredPeripheral.name];
    [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
}


- (void)viewWillDisappear:(BOOL)animated
{
    [self.centralManager stopScan];
    NSLog(@"Stop Scan");
    
    [super viewWillDisappear:animated];
}


- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    
    NSLog(@"peripheral has disconnected");
    self.textView.text = [self.textView.text stringByAppendingFormat:@"\n%@ has been disconnected", self.discoveredPeripheral.name];
    self.discoveredPeripheral = nil;

}

- (NSMutableData *)data {
    if (!_data) {
        _data = [[NSMutableData alloc]init];
    }
    
    return _data;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    if (!_centralManager){
        _centralManager = [[CBCentralManager alloc]initWithDelegate:self
                                                              queue:nil];
    }

}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    if (central.state != CBCentralManagerStatePoweredOn) {
        return;
    }
    
    [self scan];
}

- (void)scan{
    
//[self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] options:nil];
    
    [self.centralManager scanForPeripheralsWithServices:nil
                                                options:nil];
    
    [self.activityIndicatorView startAnimating];
    
    NSLog(@"Scanning started");
    self.textView.text = [self.textView.text stringByAppendingFormat:@"\nScanning started"];
    
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI{
    
    NSLog(@"peripheral discovered %@ at %@", peripheral.identifier, RSSI);
    self.textView.text = [self.textView.text stringByAppendingFormat:@"\nperipheral discovered %@", peripheral.name];
    
    if (self.discoveredPeripheral != peripheral) {
        self.discoveredPeripheral = peripheral;
    }
    NSLog(@"connecting: %@", peripheral);
        
    [self.centralManager connectPeripheral:peripheral options:nil];
    
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    
    NSLog(@"device connected %@", peripheral.identifier);
    self.textView.text = [self.textView.text stringByAppendingFormat:@"\ndevice connected, %@", peripheral.name];
    
    [self.centralManager stopScan];
    
    peripheral.delegate = self;
    
    [peripheral discoverServices:nil];
}

-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    
    NSLog(@"connect failed %@", peripheral);
    
    return;
}


- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    if (error){
        NSLog(@"service error");
    }else{
        NSLog(@"service found %@", peripheral.services);
        
        self.textView.text = [self.textView.text stringByAppendingFormat:@"\nservice found %@", peripheral];
        
        for (CBService *service in peripheral.services) {
            [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]] forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error){
        NSLog(@"characteristics error");
    }else{
        
        for (CBCharacteristic *characteristic in service.characteristics){
            NSLog(@"characteristics found %@", characteristic);
            self.textView.text = [self.textView.text stringByAppendingFormat:@"\ncharacteristics found, %@", peripheral];
            if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            }
        }
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    
    if (error){
        NSLog(@"error %@", [error localizedDescription]);
        return;
    }
    
    NSString *stringFromData = [[NSString alloc]initWithData:characteristic.value
                                                    encoding:NSUTF8StringEncoding];
    
    if ([stringFromData isEqualToString:@"EOM"]) {
        
        NSString *receivedData = [[NSString alloc]initWithData:self.data encoding:NSUTF8StringEncoding];
        self.textView.text = [self.textView.text stringByAppendingFormat:@"\nReceived Data: %@", receivedData];
        
        self.data = nil;
        
    }else{
        //add new data to buffer
        [self.data appendData:characteristic.value];
    }
    
    NSLog(@"Received: %@", stringFromData);
}


- (void) peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    
    if (error) {
        NSLog(@"error %@", error.localizedDescription);
    }
    
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
        return;
    }
    
    if (characteristic.isNotifying) {
        NSLog(@"characteristics notified, %@", characteristic);
    }else{
        NSLog(@"notification cancelled");
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
