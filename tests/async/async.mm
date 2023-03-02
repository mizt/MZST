#import <Cocoa/Cocoa.h>
#import <vector>

#import "Event.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "zstd.h"

#import <algorithm>

#define TOTAL_FRAMES 256

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
            
            int finished;
            
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
    
        const unsigned int SIZE = 4;
	
		NSFileHandle *_handle = nil;

		dispatch_source_t timer = nullptr;
		double then = CFAbsoluteTimeGetCurrent();
    
        const unsigned short width = 3840;
        const unsigned short height = 2160;
        unsigned char *src = nullptr;
        unsigned char *bin = nullptr;
	
		void cleanup() {
            
			if(this->timer){
				dispatch_source_cancel(this->timer);
				this->timer = nullptr;
			}
            
            if(this->src) {
                delete[] this->src;
                this->src = nullptr;
            }
            
            if(this->bin) {
                delete[] this->bin;
                this->bin = nullptr;
            }
		}
	
		unsigned int frame = 0;
		std::vector<std::pair<unsigned char *,unsigned int>> queue;
        
	public:
		
		App() {

            unsigned int size = (this->width*this->height)+(((this->width*this->height)>>2)<<1);
            this->src = new unsigned char[size];
            for(int n=0; n<size; n++) this->src[n] = 128;
            
            this->bin = new unsigned char[SIZE+size];
            for(int n=0; n<SIZE+size; n++) this->bin[n] = 0;
            
			[[NSFileManager defaultManager] createFileAtPath:@"./test.bin" contents:nil attributes:nil];
			
			this->_handle = [NSFileHandle fileHandleForWritingAtPath:@"./test.bin"];
			
			for(int n=0; n<TOTAL_FRAMES; n++) {
				this->queue.push_back(std::make_pair(nullptr,0));
			}
            
            Event::on(Event::SAVE_COMPLETE,^(NSNotification *notification) {
                
                NSData *data = [[NSData alloc] initWithContentsOfFile:@"./test.bin"];
                unsigned char *bytes = (unsigned char *)data.bytes;
                
                unsigned int frame = 255;
                if(frame>=TOTAL_FRAMES) frame = TOTAL_FRAMES-1;
                
                unsigned int offset = 0;
                
                for(int n=0; n<frame; n++) {
                    offset+=SIZE+(*((unsigned int *)(bytes+offset)));
                }
                
                unsigned int length = (*((unsigned int *)(bytes+offset)));                
                unsigned int size = (this->width*this->height)+(((this->width*this->height)>>2)<<1);
                unsigned char *ypbpr = new unsigned char[size];
                
                if(ZSTD_decompress(ypbpr,size,bytes+offset+SIZE,length)) {
                    NSLog(@"%d",*ypbpr);
                    NSLog(@"%d",*(ypbpr+(this->width*this->height)));
                }
                
                delete[] ypbpr;
                    
                Event::emit(Event::RESET);
            });
            
			this->timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_queue_create("ENTER_FRAME",0));
			dispatch_source_set_timer(this->timer,dispatch_time(0,0),(1.0/30)*1000000000,0);
			dispatch_source_set_event_handler(this->timer,^{
				
				if(this->queue[this->frame].first!=nullptr) {
                    	
                    NSLog(@"write %d",this->frame);
                    
					[this->_handle seekToEndOfFile];
					[this->_handle writeData:[[NSData alloc] initWithBytes:this->queue[this->frame].first length:this->queue[this->frame].second]];
							
                    if(this->queue[this->frame].first) {
                        delete[] this->queue[this->frame].first;
                        this->queue[this->frame].first = nullptr;
                    }
					
					this->frame++;
				}
				
				if(this->frame==TOTAL_FRAMES) {
					this->cleanup();
                    Event::emit(Event::SAVE_COMPLETE);
				}
			});
			if(this->timer) dispatch_resume(this->timer);
		}
	
		void set(int frame) {
            
			if(frame<TOTAL_FRAMES) {
                
                for(int n=0; n<this->width*this->height; n++) this->src[n] = frame;
                
                unsigned int size = (this->width*this->height)+(((this->width*this->height)>>2)<<1);
                unsigned int length = compress(this->bin+SIZE,this->src,size,4);
                *((unsigned int *)(this->bin)) = length;
                                
				this->queue[frame].first = new unsigned char[SIZE+length];
				this->queue[frame].second = SIZE+length;
                
				unsigned char *p = this->queue[frame].first;
                for(int n=0; n<SIZE+length; n++) p[n] = this->bin[n];
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
