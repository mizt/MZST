#import <Cocoa/Cocoa.h>
#import <vector>

#import "Event.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "zstd.h"

#import <algorithm>

#import "MultiTrackQTMovie.h"
#import "MultiTrackQTMovieParser.h"

#define TOTAL_FRAMES 17

unsigned int compress(unsigned char *dst, unsigned char *src, unsigned int size, int nbThreads) {
      
    unsigned int length = 0;
    unsigned int seek = 0;
    
    const size_t buffInSize = ZSTD_CStreamInSize();
    const size_t buffOutSize = ZSTD_CStreamOutSize();

    void *buffIn = malloc(buffInSize);
    void *buffOut = malloc(buffOutSize);

    ZSTD_CCtx *cctx = ZSTD_createCCtx();
    if(cctx!=NULL) {
        
        ZSTD_CCtx_setParameter(cctx,ZSTD_c_compressionLevel,1);
        ZSTD_CCtx_setParameter(cctx,ZSTD_c_checksumFlag,0);
        ZSTD_CCtx_setParameter(cctx,ZSTD_c_nbWorkers,nbThreads);

        const size_t toRead = buffInSize;
        while(true) {
            
            size_t read = toRead;
            memcpy(buffIn,src+seek,read);
            seek+=toRead;
            if(seek>=size) read = buffInSize - (seek-size);

            int const lastChunk = (read<toRead);
            ZSTD_EndDirective const mode = lastChunk?ZSTD_e_end:ZSTD_e_continue;
            ZSTD_inBuffer input = { buffIn, read, 0 };
            
            bool finished = false;
            
            do {
                
                ZSTD_outBuffer output = { buffOut, buffOutSize, 0 };
                size_t const remaining = ZSTD_compressStream2(cctx,&output,&input,mode);
                
                size_t sizeToWrite = output.pos;
                if(sizeToWrite) {
                    memcpy((void *)(dst+length),buffOut,sizeToWrite);
                    length+=sizeToWrite;
                }
                
                finished = lastChunk?(remaining==0):(input.pos==input.size);
                
            } while (!finished);
            
            if(lastChunk) break;
        }
        
        ZSTD_freeCCtx(cctx);
        
        free(buffIn);
        free(buffOut);
    }
    
    return length;
}

class App {
	
	private:
    	
		NSFileHandle *_handle = nil;

		dispatch_source_t _timer = nullptr;
		double _then = CFAbsoluteTimeGetCurrent();
    
        const unsigned short _width = 3840;
        const unsigned short _height = 2160;
        unsigned char *_src = nullptr;
        unsigned char *_bin = nullptr;
	
		void cleanup() {
            
			if(this->_timer){
				dispatch_source_cancel(this->_timer);
				this->_timer = nullptr;
			}
            
            if(this->_src) {
                delete[] this->_src;
                this->_src = nullptr;
            }
            
            if(this->_bin) {
                delete[] this->_bin;
                this->_bin = nullptr;
            }
		}
	
		unsigned int _frame = 0;
		std::vector<std::pair<unsigned char *,unsigned int>> _queue;
    
        std::vector<MultiTrackQTMovie::TrackInfo> _info;
        MultiTrackQTMovie::Recorder *_recorder = nullptr;
        
	public:
		
		App() {
            
            this->_info.push_back({.width=this->_width,.height=this->_height,.depth=24,.fps=30.,.type="mzst"});
            this->_recorder = new MultiTrackQTMovie::Recorder(@"./test.mov",&this->_info);


            unsigned int size = (this->_width*this->_height)+(((this->_width*this->_height)>>2)<<1);
            this->_src = new unsigned char[size];
            for(int n=0; n<size; n++) this->_src[n] = 128;
            
            this->_bin = new unsigned char[size];
            for(int n=0; n<size; n++) this->_bin[n] = 0;
            
			[[NSFileManager defaultManager] createFileAtPath:@"./test.bin" contents:nil attributes:nil];
			
			this->_handle = [NSFileHandle fileHandleForWritingAtPath:@"./test.bin"];
			
			for(int n=0; n<TOTAL_FRAMES; n++) {
				this->_queue.push_back(std::make_pair(nullptr,0));
			}
            
            Event::on(Event::SAVE_COMPLETE,^(NSNotification *notification) {
                
                if(this->_recorder) {
                    delete this->_recorder;
                    this->_recorder = nullptr;
                }
                
                MultiTrackQTMovie::Parser *parser = new MultiTrackQTMovie::Parser(@"./test.mov");
                NSLog(@"tracks = %d",parser->tracks());
                
                if(parser->type(0)=="mzst") {
                    
                    unsigned int frame = 15;
                    NSData *data = parser->get(frame,0);
                    unsigned char *bytes = (unsigned char *)data.bytes;
                    unsigned long length = data.length;
                    unsigned int size = (this->_width*this->_height)+(((this->_width*this->_height)>>2)<<1);
                    unsigned char *ypbpr = new unsigned char[size];
                    
                    if(ZSTD_decompress(ypbpr,size,bytes,length)) {
                        NSLog(@"%d",*ypbpr);
                        NSLog(@"%d",*(ypbpr+(this->_width*this->_height)));
                    }
                    
                    delete[] ypbpr;
                        
                    Event::emit(Event::RESET);
                }
                
            });
		}
	
		void set(int frame) {
			if(frame<TOTAL_FRAMES) {
                unsigned int size = (this->_width*this->_height)+(((this->_width*this->_height)>>2)<<1);
                for(int n=0; n<this->_width*this->_height; n++) this->_src[n] = frame;
                unsigned int length = compress(this->_bin,this->_src,size,4);
                this->_recorder->add(this->_bin,length,0);
                
                if(frame==TOTAL_FRAMES-1) {
                    this->_recorder->save();
                }
			}
		}
		
		~App() {
            this->cleanup();
		}
};

@interface AppDelegate:NSObject <NSApplicationDelegate> {
	App *app;
	NSTimer *timer;
	double then;
	unsigned int frame;
}
@end

@implementation AppDelegate
-(void)applicationDidFinishLaunching:(NSNotification*)aNotification {
	self->frame = 0;
	self->app = new App();
	self->then = CFAbsoluteTimeGetCurrent();
	self->timer = [NSTimer scheduledTimerWithTimeInterval:1.0/30.0 target:self selector:@selector(update:) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:self->timer forMode:NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:self->timer forMode:NSModalPanelRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:self->timer forMode:NSEventTrackingRunLoopMode];
    
    Event::on(Event::RESET,^(NSNotification *notification) {
        delete self->app;
        self->app = nullptr;
        [NSApp terminate:nil];
    });
}

-(void)applicationWillTerminate:(NSNotification *)aNotification {
	if(self->timer&&[self->timer isValid]) [self->timer invalidate];
	if(self->app) delete self->app;
}

-(void)update:(NSTimer*)timer {
	if(self->app) {
		if(self->frame<TOTAL_FRAMES) {
			double current = CFAbsoluteTimeGetCurrent();
            self->app->set(self->frame++);
			NSLog(@"%f",current-self->then);
			self->then = current;
		}
	}
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
