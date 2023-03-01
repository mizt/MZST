#import <Cocoa/Cocoa.h>
#import <vector>

#import "Event.h"

class App {
	
	private:
	
		NSFileHandle *_handle = nil;

		dispatch_source_t timer = nullptr;
		double then = CFAbsoluteTimeGetCurrent();
	
		void cleanup() {
			if(this->timer){
				dispatch_source_cancel(this->timer);
				this->timer = nullptr;
			}
		}
	
		const unsigned int totalFrames = 30;
		unsigned int frame = 0;
		
		std::vector<std::pair<unsigned char *,unsigned int>> queue;
	
	public:
		
		App() {
			
			[[NSFileManager defaultManager] createFileAtPath:@"./test.bin" contents:nil attributes:nil];
			
			this->_handle = [NSFileHandle fileHandleForWritingAtPath:@"./test.bin"];
			
			for(int n=0; n<this->totalFrames; n++) {
				this->queue.push_back(std::make_pair(nullptr,0));
			}
            
            Event::on(Event::SAVE_COMPLETE,^(NSNotification *notification) {
                NSLog(@"%@",notification);
                Event::emit(Event::RESET);
            });
            
            
			this->timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_queue_create("ENTER_FRAME",0));
			dispatch_source_set_timer(this->timer,dispatch_time(0,0),(1.0/30)*1000000000,0);
			dispatch_source_set_event_handler(this->timer,^{
				
				if(this->queue[this->frame].first!=nullptr) {
					
                    double current = CFAbsoluteTimeGetCurrent();
                    
					[this->_handle seekToEndOfFile];
					[this->_handle writeData:[[NSData alloc] initWithBytes:this->queue[this->frame].first length:this->queue[this->frame].second]];
					
					usleep(1000000.0/300.0);
					
                    NSLog(@"write %d",this->frame);
                    NSLog(@"%f",CFAbsoluteTimeGetCurrent()-current);
					
					delete[] this->queue[this->frame].first;
					this->queue[this->frame].first = nullptr;
					this->frame++;
				}
				
				if(this->frame==this->totalFrames) {
					this->cleanup();
                    Event::emit(Event::SAVE_COMPLETE);
				}
			});
			if(this->timer) dispatch_resume(this->timer);
		}
	
		void set(int frame) {
			if(frame<this->totalFrames) {
                NSLog(@"set %d",frame);
				unsigned int length = (3840*2160)+((1920*1080)<<1);
				this->queue[frame].first = new unsigned char[length];
				this->queue[frame].second = length;
				unsigned char *p = this->queue[frame].first;
				for(int n=0; n<length; n++) p[n] = frame;
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
        NSLog(@"%@",notification);
    });
    
}
-(void)applicationWillTerminate:(NSNotification *)aNotification {
	if(self->timer&&[self->timer isValid]) [self->timer invalidate];
	if(self->app) delete self->app;
}
-(void)update:(NSTimer*)timer {
	if(self->app) {
		if(self->frame<30) {
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
