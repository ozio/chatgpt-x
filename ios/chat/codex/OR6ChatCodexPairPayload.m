#import "OR6ChatCodexPairPayload.h"
#import "../../api/codex/pair/OR6CodexPairCrypto.h"
#include "qr/quirc.h"
#include "qr/quirc_internal.h"
static NSMutableDictionary *QRStats;
NSDictionary *OR6ChatCodexPairQRDiagnostics(void){@synchronized(NSObject.class){return [[QRStats copy]autorelease]?:@{};}}
void OR6ChatCodexPairQRReset(void){@synchronized(NSObject.class){[QRStats release];QRStats=[@{@"frames":@0,@"candidates":@0,@"decoded":@0,@"accepted":@0}mutableCopy];}}
static void QRCount(NSString *key,NSUInteger count){@synchronized(NSObject.class){if(!QRStats)OR6ChatCodexPairQRReset();QRStats[key]=@([QRStats[key]unsignedIntegerValue]+count);}}
static void QRShape(NSString *payload,BOOL accepted){
    NSMutableDictionary *shape=[NSMutableDictionary dictionaryWithDictionary:@{@"characters":@(payload.length),@"accepted":@(accepted)}];
    NSURL *u=[NSURL URLWithString:payload];
    if(u.scheme){shape[@"kind"]=@"URL";shape[@"https"]=@([u.scheme isEqual:@"https"]);shape[@"codex"]=@([u.scheme isEqual:@"codex"]);shape[@"chatgptHost"]=@([u.host isEqual:@"chatgpt.com"]);NSMutableArray *keys=[NSMutableArray array];NSUInteger others=0;for(NSString *part in [u.query componentsSeparatedByString:@"&"]){NSString *key=[[[part componentsSeparatedByString:@"="]objectAtIndex:0]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];if([@[@"pairingCode",@"pairing_code",@"code",@"token",@"v",@"data",@"activate",@"projectPath"]containsObject:key])[keys addObject:key];else others++;}shape[@"queryKeys"]=keys;shape[@"otherQueryKeys"]=@(others);}
    else {id json=payload?[NSJSONSerialization JSONObjectWithData:[payload dataUsingEncoding:NSUTF8StringEncoding]options:NSJSONReadingAllowFragments error:NULL]:nil;shape[@"kind"]=[json isKindOfClass:NSDictionary.class]?@"JSON object":[json isKindOfClass:NSArray.class]?@"JSON array":@"plain";if([json isKindOfClass:NSDictionary.class]){NSMutableArray *keys=[NSMutableArray array];for(NSString *key in @[@"code",@"pairingCode",@"pairing_code",@"version",@"v",@"token",@"type",@"url",@"data"])if(json[key])[keys addObject:key];shape[@"knownJSONKeys"]=keys;shape[@"JSONKeyCount"]=@([json count]);}}
    @synchronized(NSObject.class){QRStats[@"lastPayload"]=shape;}
}
NSString *OR6ChatCodexPairQRPayload(NSString *payload) {
    NSString *code=OR6CodexPairCode(payload);if(code)return code;
    if(!OR6CodexText(payload,4096,NO))return nil;
    NSURL *URL=[NSURL URLWithString:payload];
    // Treat links only as code containers. Never navigate, carry credentials,
    // switch accounts, accept project/activation instructions, or trust a host
    // advertised in QR data. The user still confirms the normal pairing flow.
    BOOL https=[URL.scheme isEqual:@"https"]&&[URL.host isEqual:@"chatgpt.com"]&&(!URL.port||[URL.port isEqual:@443]);
    BOOL desktop=[URL.scheme isEqual:@"codex"]&&[URL.host isEqual:@"settings"]&&[URL.path isEqual:@"/connections/remoteControl/add"]&&!URL.port;
    if((!https&&!desktop)||URL.user||URL.password||URL.fragment||!URL.query)return nil;
    NSMutableDictionary *p=[NSMutableDictionary dictionary];
    for(NSString *part in [URL.query componentsSeparatedByString:@"&"]){NSArray *a=[part componentsSeparatedByString:@"="];if(a.count!=2)return nil;
        NSString *key=[a[0]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding],*value=[a[1]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if(!key||!value||p[key]||![@[@"pairingCode",@"pairing_code"]containsObject:key])return nil;p[key]=value;
    }
    if(p.count!=1)return nil;return OR6CodexPairCode(p[@"pairingCode"]?:p[@"pairing_code"]);
}
NSString *OR6ChatCodexPairDecodeQR(struct quirc *decoder) {
    if(!decoder)return nil;quirc_end(decoder);QRCount(@"frames",1);QRCount(@"candidates",(NSUInteger)quirc_count(decoder));
    for(int i=0;i<quirc_count(decoder)&&i<8;i++){
        struct quirc_code code;struct quirc_data data;quirc_extract(decoder,i,&code);@synchronized(NSObject.class){QRStats[@"lastGridSize"]=@(code.size);}
        quirc_decode_error_t result=quirc_decode(&code,&data);
        if(result){quirc_flip(&code);result=quirc_decode(&code,&data);}if(result){@synchronized(NSObject.class){QRStats[@"decodeError"]=@(result);}continue;}if(data.payload_len<=0||data.payload_len>4096)continue;QRCount(@"decoded",1);
        NSString *payload=[[[NSString alloc]initWithBytes:data.payload length:(NSUInteger)data.payload_len encoding:NSUTF8StringEncoding]autorelease];NSString *value=OR6ChatCodexPairQRPayload(payload);
        QRShape(payload,value!=nil);if(value){QRCount(@"accepted",1);return value;}
    }return nil;
}

// Rounded finders and dotted timing marks can pull quirc's estimated alignment
// corner into a neighbouring dot. Retry its detected geometry using the three
// finder corners as an affine grid. No screen position, version or code is fixed.
static NSString *AffineCandidate(struct quirc *decoder,const unsigned char *gray,int w,int h,BOOL inverse){
    for(int index=0;index<quirc_count(decoder)&&index<8;index++){
        struct quirc_code detected;quirc_extract(decoder,index,&detected);
        if(detected.size<21||detected.size>QUIRC_MAX_GRID_SIZE)continue;
        for(int delta=0;delta<3;delta++){
            int size=detected.size+(delta==1?-4:delta==2?4:0);if(size<21||size>QUIRC_MAX_GRID_SIZE)continue;
            struct quirc_capstone *origin=&decoder->capstones[decoder->grids[index].caps[1]],*right=&decoder->capstones[decoder->grids[index].caps[2]],*down=&decoder->capstones[decoder->grids[index].caps[0]];
            struct quirc_code code=detected;code.size=size;memset(code.cell_bitmap,0,sizeof(code.cell_bitmap));
            unsigned char levels[QUIRC_MAX_GRID_SIZE*QUIRC_MAX_GRID_SIZE];int minimum=255,maximum=0;
            for(int y=0;y<size;y++)for(int x=0;x<size;x++){
                int level=255;
                for(int oy=-1;oy<=1;oy++)for(int ox=-1;ox<=1;ox++){
                    double u=(x-3+ox*.15)/(size-7),v=(y-3+oy*.15)/(size-7);
                    int sx=(int)(origin->center.x+u*(right->center.x-origin->center.x)+v*(down->center.x-origin->center.x)+.5);
                    int sy=(int)(origin->center.y+u*(right->center.y-origin->center.y)+v*(down->center.y-origin->center.y)+.5);
                    if(sx<0||sx>=w||sy<0||sy>=h)continue;int sample=gray[(NSUInteger)sy*w+sx];if(inverse)sample=255-sample;level=MIN(level,sample);
                }
                levels[y*size+x]=(unsigned char)level;minimum=MIN(minimum,level);maximum=MAX(maximum,level);
            }
            if(maximum-minimum<32)continue;int threshold=(minimum+maximum)/2;
            for(int bit=0;bit<size*size;bit++)if(levels[bit]<threshold)code.cell_bitmap[bit>>3]|=(1<<(bit&7));
            struct quirc_data data;quirc_decode_error_t result=quirc_decode(&code,&data);if(result){quirc_flip(&code);result=quirc_decode(&code,&data);}
            if(result||data.payload_len<=0||data.payload_len>4096)continue;
            NSString *payload=[[[NSString alloc]initWithBytes:data.payload length:(NSUInteger)data.payload_len encoding:NSUTF8StringEncoding]autorelease];NSString *value=OR6ChatCodexPairQRPayload(payload);
            QRCount(@"decoded",1);QRShape(payload,value!=nil);if(value){QRCount(@"accepted",1);@synchronized(NSObject.class){QRStats[@"affineRecovery"]=@YES;}return value;}
        }
    }return nil;
}
static NSString *DecodeGrayPasses(struct quirc *decoder,const unsigned char *gray,NSUInteger length){
    if(!decoder||!gray)return nil;int w=0,h=0;unsigned char *pixels=quirc_begin(decoder,&w,&h);
    if(!pixels||w<=0||h<=0||w>2048||h>2048||length!=(NSUInteger)w*(NSUInteger)h)return nil;
    memcpy(pixels,gray,length);NSString *value=OR6ChatCodexPairDecodeQR(decoder);if(value)return value;value=AffineCandidate(decoder,gray,w,h,NO);if(value)return value;
    pixels=quirc_begin(decoder,NULL,NULL);for(NSUInteger i=0;i<length;i++)pixels[i]=(unsigned char)(255-gray[i]);
    value=OR6ChatCodexPairDecodeQR(decoder);if(value)return value;value=AffineCandidate(decoder,gray,w,h,YES);if(value)return value;
    // Retry antialiased/dotted renderings with a hard threshold and bounded
    // separable dilation. Scratch storage is one byte per input pixel.
    int minimum=255,maximum=0;for(NSUInteger i=0;i<length;i++){minimum=MIN(minimum,gray[i]);maximum=MAX(maximum,gray[i]);}
    if(maximum-minimum<32)return nil;int threshold=(minimum+maximum)/2;
    unsigned char *scratch=malloc(length);if(!scratch)return nil;
    for(int radius=0;radius<=2;radius++)for(int polarity=0;polarity<2;polarity++){
        pixels=quirc_begin(decoder,NULL,NULL);
        for(int y=0;y<h;y++)for(int x=0;x<w;x++){
            unsigned char lowest=255;
            for(int dx=-radius;dx<=radius;dx++){int sx=x+dx;if(sx<0||sx>=w)continue;unsigned char sample=gray[(NSUInteger)y*w+sx];if(polarity)sample=255-sample;lowest=MIN(lowest,sample);}
            scratch[(NSUInteger)y*w+x]=lowest;
        }
        for(int y=0;y<h;y++)for(int x=0;x<w;x++){
            unsigned char lowest=255;
            for(int dy=-radius;dy<=radius;dy++){int sy=y+dy;if(sy<0||sy>=h)continue;lowest=MIN(lowest,scratch[(NSUInteger)sy*w+x]);}
            pixels[(NSUInteger)y*w+x]=lowest<(polarity?255-threshold:threshold)?0:255;
        }
        value=OR6ChatCodexPairDecodeQR(decoder);if(!value)value=AffineCandidate(decoder,gray,w,h,polarity);
        if(value){free(scratch);return value;}
    }
    free(scratch);return nil;
}

NSString *OR6ChatCodexPairDecodeGray(struct quirc *decoder,const unsigned char *gray,NSUInteger length){
    NSString *value=DecodeGrayPasses(decoder,gray,length);if(value||!decoder||!gray)return value;
    int w=0,h=0;quirc_begin(decoder,&w,&h);
    // One bounded second resolution for small, antialiased finder rings.
    // A separate decoder preserves the camera's cached input dimensions.
    if(w<=0||h<=0||w>1024||h>1024||length!=(NSUInteger)w*h||length>524288)return nil;
    int minimum=255,maximum=0;for(NSUInteger i=0;i<length;i++){minimum=MIN(minimum,gray[i]);maximum=MAX(maximum,gray[i]);}if(maximum-minimum<32)return nil;
    struct quirc *larger=quirc_new();unsigned char *up=malloc(length*4);
    if(!larger||!up||quirc_resize(larger,w*2,h*2)){if(larger)quirc_destroy(larger);free(up);return nil;}
    for(int y=0;y<h*2;y++)for(int x=0;x<w*2;x++){
        int sx=x/2,sy=y/2,nx=MIN(sx+1,w-1),ny=MIN(sy+1,h-1);int a=gray[(NSUInteger)sy*w+sx],b=gray[(NSUInteger)sy*w+nx],c=gray[(NSUInteger)ny*w+sx],d=gray[(NSUInteger)ny*w+nx];
        up[(NSUInteger)y*w*2+x]=(unsigned char)((x&1)?((y&1)?(a+b+c+d)/4:(a+b)/2):((y&1)?(a+c)/2:a));
    }
    value=DecodeGrayPasses(larger,up,length*4);quirc_destroy(larger);free(up);return value;
}
