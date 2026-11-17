#import "OR6CodexDiff.h"
NSArray *OR6CodexDiffCommand(NSString*mode,NSString*base){
 if(![@[@"working",@"staged",@"head",@"base"]containsObject:mode])return nil;
 if([mode isEqual:@"base"]){if(!OR6CodexText(base,40,NO)||base.length!=40||[base rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"]invertedSet]].location!=NSNotFound)return nil;}else if(base)return nil;
 NSMutableArray*a=[NSMutableArray arrayWithArray:@[@"git",@"-c",@"core.fsmonitor=false",@"-c",@"core.hooksPath=/dev/null",@"--no-pager",@"diff",@"--no-ext-diff",@"--no-textconv",@"--no-color",@"--unified=3"]];if([mode isEqual:@"staged"])[a addObject:@"--cached"];else if([mode isEqual:@"head"])[a addObject:@"HEAD"];else if([mode isEqual:@"base"]){if(!base)return nil;[a addObject:[base stringByAppendingString:@"..HEAD"]];}[a addObject:@"--"];return a;
}
NSDictionary *OR6CodexParseDiff(NSString*patch,NSError**error){
 if(!OR6CodexText(patch,131072,YES)||[patch lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>131072){if(error)*error=OR6CodexError(@"size_limit",NO);return nil;}
 NSArray*lines=[patch componentsSeparatedByString:@"\n"];if(lines.count>4096){if(error)*error=OR6CodexError(@"size_limit",NO);return nil;}
 NSMutableArray*files=[NSMutableArray array],*rows=[NSMutableArray array];NSMutableDictionary*file=nil;NSUInteger old=0,new=0,leftOld=0,leftNew=0;BOOL hunk=NO;
 NSRegularExpression*regex=[NSRegularExpression regularExpressionWithPattern:@"^@@ -([0-9]+)(?:,([0-9]+))? \\+([0-9]+)(?:,([0-9]+))? @@(?:.*)$"options:0 error:NULL];
 for(NSUInteger index=0;index<lines.count;index++){NSString*line=lines[index];if(index+1==lines.count&&!line.length)break;
  if([line hasPrefix:@"\\ No newline at end of file"]){if(!hunk)goto malformed;[rows addObject:@{@"kind":@"noNewline",@"text":line,@"file":@(files.count-1)}];continue;}
  if(hunk&&(leftOld||leftNew)&&![line hasPrefix:@"@@ "]){if(!line.length)goto malformed;unichar lead=[line characterAtIndex:0];if(lead!=' '&&lead!='+'&&lead!='-')goto malformed;BOOL takeOld=lead!='+',takeNew=lead!='-';if((takeOld&&!leftOld)||(takeNew&&!leftNew))goto malformed;[rows addObject:@{@"kind":lead==' '?@"context":lead=='+'?@"add":@"delete",@"oldLine":takeOld?@(old++):(id)NSNull.null,@"newLine":takeNew?@(new++):(id)NSNull.null,@"text":[line substringFromIndex:1],@"file":@(files.count-1)}];if(takeOld)leftOld--;if(takeNew)leftNew--;continue;}
  if([line hasPrefix:@"diff --git "]){if(leftOld||leftNew)goto malformed;file=[NSMutableDictionary dictionaryWithDictionary:@{@"header":line,@"binary":@NO}];[files addObject:file];if(files.count>128)goto malformed;hunk=NO;continue;}
  if([line hasPrefix:@"@@"]){if(!file||leftOld||leftNew)goto malformed;NSTextCheckingResult*match=[regex firstMatchInString:line options:0 range:NSMakeRange(0,line.length)];if(!match)goto malformed;unsigned long long counts[4];for(NSUInteger i=0;i<4;i++){NSRange r=[match rangeAtIndex:i+1];if(r.location==NSNotFound){counts[i]=1;continue;}NSString*n=[line substringWithRange:r];if(n.length>9)goto malformed;counts[i]=strtoull(n.UTF8String,NULL,10);if(counts[i]>2147483647)goto malformed;}old=(NSUInteger)counts[0];leftOld=(NSUInteger)counts[1];new=(NSUInteger)counts[2];leftNew=(NSUInteger)counts[3];hunk=YES;[rows addObject:@{@"kind":@"hunk",@"text":line,@"file":@(files.count-1),@"oldStart":@(old),@"newStart":@(new)}];continue;}
  if(!file){if(!line.length)continue;goto malformed;}
  if([line hasPrefix:@"--- "])file[@"oldPath"]=[line substringFromIndex:4];else if([line hasPrefix:@"+++ "])file[@"newPath"]=[line substringFromIndex:4];else if([line hasPrefix:@"Binary files "]||[line isEqual:@"GIT binary patch"])file[@"binary"]=@YES;
  else if(hunk&&line.length)goto malformed;
 }
 if(leftOld||leftNew)goto malformed;
 return@{@"files":files,@"rows":rows,@"patch":patch,@"truncated":@NO};
malformed:if(error)*error=OR6CodexError(@"invalid_response",NO);return nil;
}
