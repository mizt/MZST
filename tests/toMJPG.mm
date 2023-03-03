#import <Cocoa/Cocoa.h>
#import "zstd.h"

#import "EventEmitter.h"
#import "MultiTrackQTMovieEvent.h"
#import "MultiTrackQTMovieParser.h"
#import "turbojpeg.h"

#import "MultiTrackQTMovie.h"
#import "MultiTrackQTMovieParser.h"

class App {
    
    private:

        MultiTrackQTMovie::Parser *_parser = new MultiTrackQTMovie::Parser(@"./test.mov");
    
        std::vector<MultiTrackQTMovie::TrackInfo> _info;
        MultiTrackQTMovie::Recorder *_recorder = nullptr;
    
    public:
    
        App() {
            
            NSLog(@"tracks = %d",this->_parser->tracks());
            NSLog(@"length = %d",this->_parser->length(0));
            
            if(this->_parser->type(0)=="mzst"||this->_parser->type(0)=="zstd") {
                
                unsigned short width = this->_parser->width(0);
                unsigned short height = this->_parser->height(0);
                
                this->_info.push_back({.width=width,.height=height,.depth=24,.fps=30,.type="jpeg"});
                this->_recorder = new MultiTrackQTMovie::Recorder(@"./test.mov",&this->_info);
                
                unsigned char pad = 2;
                unsigned char quality = 75;
                unsigned long jpgSize = 0;
                unsigned char *jpg = tjAlloc((int)tjBufSizeYUV2(width,pad,height,TJSAMP_420));
                
                unsigned long yuv420Size = (width*height)+(((width*height)>>2)<<1);
                unsigned char *yuv420 = new unsigned char[yuv420Size];
                unsigned char *ypbpr = new unsigned char[yuv420Size];
                
                for(int n=0; n<this->_parser->length(0); n++) {
                    
                    NSLog(@"%d",n);
                    
                    NSData *data = this->_parser->get(n,0);
                    
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
                                
                                this->_recorder->add(jpg,(unsigned int)jpgSize,0);
                                //[[[NSData alloc] initWithBytes:jpg length:jpgSize] writeToFile:@"./test.jpg" options:NSDataWritingAtomic error:nil];
                            }
                            tjDestroy(handle);
                        }
                    }
                }
                
                delete this->_parser;
                
                delete[] yuv420;
                delete[] ypbpr;
                delete[] jpg;

                EventEmitter::on(MultiTrackQTMovie::Event::SAVE_COMPLETE,^(NSNotification *notification) {
                    if(this->_recorder) {
                        delete this->_recorder;
                        this->_recorder = nullptr;
                        [NSApp terminate:nil];
                    }
                });
                
                this->_recorder ->save();
                
                while(true) {
                    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:NSEC_PER_SEC/30.0]];
                }
                
            }
        }
};

@interface AppDelegate:NSObject <NSApplicationDelegate> {
    App *app;
}
@end

@implementation AppDelegate
-(void)applicationDidFinishLaunching:(NSNotification*)aNotification {
    self->app = new App();
}

-(void)applicationWillTerminate:(NSNotification *)aNotification {
    if(self->app) delete self->app;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        id app = [NSApplication sharedApplication];
        id delegat = [AppDelegate alloc];
        [app setDelegate:delegat];
        [app run];
    }
}
