#import <Foundation/Foundation.h>
#import "zstd.h"
#import "MultiTrackQTMovieParser.h"

#define STBI_ONLY_PNG
#define STB_IMAGE_WRITE_IMPLEMENTATION
#import "stb_image_write.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        MultiTrackQTMovie::Parser *parser = new MultiTrackQTMovie::Parser(@"./test.mov");
        
        NSLog(@"tracks = %d",parser->tracks());
        NSLog(@"length = %d",parser->length(0));
        
        if(parser->type(0)=="mzst"||parser->type(0)=="zstd") {
            
            unsigned short width = parser->width(0);
            unsigned short height = parser->height(0);
            
            unsigned int frame = 0;
            if(frame>=parser->length(0)) frame = parser->length(0)-1;
            NSData *data = parser->get(frame,0);
            unsigned char *bytes = (unsigned char *)data.bytes;
            unsigned long length = data.length;
            unsigned int size = (width*height)+(((width*height)>>2)<<1);
            unsigned char *ypbpr = new unsigned char[size];
            unsigned int *abgr = new unsigned int[width*height];
            
            if(ZSTD_decompress(ypbpr,size,bytes,length)) {
                
                unsigned short *pbpr = (unsigned short *)(ypbpr+(width*height));
                
                for(int i=0; i<height; i++) {
                    
                    unsigned char left = 0;
                    
                    for(int j=0; j<width; j++) {
                        
                        left=(left+ypbpr[i*width+j])&0xFF;
                        int y = left<<10;
                        
                        unsigned int offset = (i>>1)*(width>>1)+(j>>1);
                        
                        int u = (pbpr[offset]&0xFF)-128;
                        int v = (pbpr[offset]>>8)-128;
                        
                        unsigned char r = std::clamp((y+1612*v)>>10,0,255);
                        unsigned char g = std::clamp((y-191*u-479*v)>>10,0,255);
                        unsigned char b = std::clamp((y+1901*u)>>10,0,255);
                        
                        abgr[i*width+j] = 0xFF000000|b<<16|g<<8|r;
                    }
                }
                
                stbi_write_png("test.png",width,height,4,(void const*)abgr,width<<2);
            }
            
            delete[] ypbpr;
        }
    }
    return 0;
}
