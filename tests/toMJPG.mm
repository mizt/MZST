#import <Foundation/Foundation.h>
#import "zstd.h"

#import "Event.h"

#import "MultiTrackQTMovieParser.h"
#import "turbojpeg.h"

#import "MultiTrackQTMovie.h"
#import "MultiTrackQTMovieParser.h"


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        MultiTrackQTMovie::Parser *parser = new MultiTrackQTMovie::Parser(@"/Users/mizt/Downloads/2023_0302_1950_13_071.mov");
        
        NSLog(@"tracks = %d",parser->tracks());
        NSLog(@"length = %d",parser->length(0));
        
        if(parser->type(0)=="mzst"||parser->type(0)=="zstd") {
            
            unsigned short width = parser->width(0);
            unsigned short height = parser->height(0);
            
            std::vector<MultiTrackQTMovie::TrackInfo> info;
            info.push_back({.width=width,.height=height,.depth=24,.fps=30,.type="jpeg"});
            MultiTrackQTMovie::Recorder *recorder = new MultiTrackQTMovie::Recorder(@"./test.mov",&info);

            
            
            unsigned char pad = 2;
            unsigned char quality = 75;
            unsigned long jpgSize = 0;
            unsigned char *jpg = tjAlloc((int)tjBufSizeYUV2(width,pad,height,TJSAMP_420));

            unsigned long yuv420Size = (width*height)+(((width*height)>>2)<<1);
            unsigned char *yuv420 = new unsigned char[yuv420Size];
            unsigned char *ypbpr = new unsigned char[yuv420Size];

            for(int n=0; n<parser->length(0); n++) {
                
                NSLog(@"%d",n);
                
                NSData *data = parser->get(n,0);
                
                if(ZSTD_decompress(ypbpr,yuv420Size,(unsigned char *)data.bytes,data.length)) {
                    
                    unsigned char *y = yuv420;
                    unsigned char *u = y+(width*height);
                    unsigned char *v = u+((width*height)>>2);
                    
                    unsigned short *pbpr = (unsigned short *)(ypbpr+(width*height));
                    
                    for(int i=0; i<height; i++) {
                        unsigned char left = 0;
                        for(int j=0; j<width; j++) {
                            left=(left+ypbpr[i*width+j])&0xFF;
                            *y++ = left;
                        }
                    }
                    
                    for(int i=0; i<height>>1; i++) {
                        for(int j=0; j<width>>1; j++) {
                            unsigned int offset = i*(width>>1)+j;
                            *u++ = (pbpr[offset]&0xFF);
                            *v++ = (pbpr[offset]>>8);
                        }
                    }
                    
                    tjhandle handle = tjInitCompress();
                    if(handle) {
                        if(tjCompressFromYUV(handle,yuv420,width,pad,height,TJSAMP_420,&jpg,&jpgSize,quality,TJFLAG_NOREALLOC)<0) {
                            jpgSize = 0;
                        }
                        else {
                            
                            recorder->add(jpg,(unsigned int)jpgSize,0);
                            //[[[NSData alloc] initWithBytes:jpg length:jpgSize] writeToFile:@"./test.jpg" options:NSDataWritingAtomic error:nil];
                        }
                        tjDestroy(handle);
                    }
                }
            }
            
            __block bool finished = false;
            
            recorder->save();
            
            Event::on(Event::SAVE_COMPLETE,^(NSNotification *notification) {
                finished = true;
            });
            
            while(true) {
                if(finished) break;
                [NSThread sleepForTimeInterval:(1.0/300.)];
            }
            
            delete[] yuv420;
            delete[] ypbpr;
            delete[] jpg;
        }
    }
    return 0;
}
