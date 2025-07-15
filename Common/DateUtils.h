//
//  DateUtils.h
//  SwiftNuShrinkItX
//
//  Created by Mark Lim on 9/4/16.
//  Copyright © 2016 Mark Lim. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NufxLib.h"

void DateTimeToUNIXTime(NuDateTime *pDateTime, time_t *pWhen);
void UNIXTimeToDateTime(const time_t *pWhen, NuDateTime *pDateTime);
