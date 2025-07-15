//
//  DateUtils.c
//  SwiftNuShrinkItX
//
//  Created by Mark Lim on 9/4/16.
//  Copyright © 2016 Mark Lim. All rights reserved.
//

#include "DateUtils.h"
#import "NufxLib.h"		// problem

#pragma mark - C helper function
// Convert from local time in a NuDateTime struct to GMT seconds since 1970.
void DateTimeToUNIXTime(NuDateTime *pDateTime, time_t *pWhen) {
	
	assert(pWhen != nil);
	assert(pDateTime != nil);
	struct tm tmRec;
	
	int year = pDateTime->year;
	if (year < 40)
		year += 100;
	
	tmRec.tm_sec = pDateTime->second;
	tmRec.tm_min = pDateTime->minute;
	tmRec.tm_hour = pDateTime->hour;
	tmRec.tm_mday = pDateTime->day +1;
	tmRec.tm_mon = pDateTime->month;
	tmRec.tm_year = year;
	tmRec.tm_wday = pDateTime->weekDay -1;	// ignored, can be set to 0
	*pWhen = mktime(&tmRec);
	if (*pWhen == (time_t) -1)				// Calendar time cannot be represented
	{
		NSLog(@"Time couldn't be represented");
		*pWhen = 0;
	}
}

void UNIXTimeToDateTime(const time_t* pWhen, NuDateTime *pDateTime) {

    struct tm* ptm;
	
	assert(pWhen != NULL);
	assert(pDateTime != NULL);
	
	ptm = localtime(pWhen);
	pDateTime->second = ptm->tm_sec;
	pDateTime->minute = ptm->tm_min;
	pDateTime->hour = ptm->tm_hour;
	pDateTime->day = ptm->tm_mday -1;
	pDateTime->month = ptm->tm_mon;
	pDateTime->year = ptm->tm_year;
	pDateTime->extra = 0;
	pDateTime->weekDay = ptm->tm_wday +1;
}
