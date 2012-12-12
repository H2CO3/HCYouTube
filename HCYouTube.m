/*
 * HCYouTube.m
 * HCYouTube
 *
 * Created by Arpad Goretity on 22/11/2012
 * Original work by Filippo Bigarella
 * https://github.com/FilippoBiga/ytextract
 */

#include <Foundation/Foundation.h>
#include "HCYouTube.h"

#define HCYouTubeUserAgent @"Mozilla/5.0 (iPad; CPU OS 5_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9B176 Safari/7534.48.3"
#define HCYouTubeJSONStartMark @"\")]}'"
#define HCYouTubeJSONEndMark @"\");"

static NSString *HCYouTubeUnescapeUnicodeString(NSString *str);


CFURLRef HCYouTubeCreateURLWithVideoID(CFStringRef vid)
{
	NSURL *youtubeURL;
	NSMutableURLRequest *request;
	NSData *buffer;
	NSString *html;
	
	NSUInteger startLoc;
	NSUInteger endLoc;
	NSRange jsonRange;
	NSString *jsonString;
	NSDictionary *parsedJSON;
	NSArray *streamMap;
	
	CFStringRef videoURLString;
	
	youtubeURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://youtube.com/watch?v=%@", vid]];
	request = [NSMutableURLRequest requestWithURL:youtubeURL];
	[request setValue:HCYouTubeUserAgent forHTTPHeaderField:@"User-Agent"];
	
	buffer = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL];
	html = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];
	
	startLoc = [html rangeOfString:HCYouTubeJSONStartMark].location;
	endLoc = [html rangeOfString:HCYouTubeJSONEndMark].location;
	if (startLoc == NSNotFound || endLoc == NSNotFound) {
		return nil;
	}
	
	startLoc += [HCYouTubeJSONStartMark length];
	jsonRange = NSMakeRange(startLoc, endLoc - startLoc);
	jsonString = HCYouTubeUnescapeUnicodeString([html substringWithRange:jsonRange]);
	
	[html release];
	if (jsonString == nil) {
		return nil;
	}
	
	Class _NSJSONSerialization = objc_getClass("NSJSONSerialization");
	parsedJSON = [_NSJSONSerialiaztion JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
	if (parsedJSON == nil) {
		return nil;
	}
	
	streamMap = [[[parsedJSON objectForKey:@"content"] objectForKey:@"video"] objectForKey:@"fmt_stream_map"];
	videoURLString = (CFStringRef)[[streamMap objectAtIndex:0] objectForKey:@"url"];
	
	return CFURLCreateWithString(NULL, videoURLString, NULL);
}

static NSString *HCYouTubeUnescapeUnicodeString(NSString *str)
{
	NSMutableString *escaped = [str mutableCopy];
	[escaped replaceOccurrencesOfString:@"\\u" withString:@"\\U" options:0 range:NSMakeRange(0, escaped.length)];
	[escaped replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:NSMakeRange(0, escaped.length)];
	[escaped replaceOccurrencesOfString:@"\\\\\"" withString:@"\\\"" options:0 range:NSMakeRange(0, escaped.length)];
	[escaped insertString:@"\"" atIndex:0];
	[escaped appendString:@"\""];
	NSMutableString *unescaped = [NSPropertyListSerialization propertyListWithData:[escaped dataUsingEncoding:NSUTF8StringEncoding]
		options:NSPropertyListMutableContainersAndLeaves
		format:NULL
		error:NULL
	];
	[escaped release];
	
	if ([unescaped isKindOfClass:[NSString class]] == NO) {
		return nil;
	}
		
	[unescaped replaceOccurrencesOfString:@"\\U" withString:@"\\u" options:0 range:NSMakeRange(0, unescaped.length)];
	return unescaped;
}
