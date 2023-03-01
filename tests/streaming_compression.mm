#import <Foundation/Foundation.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "zstd.h"
#include "common.h"

#define STBI_ONLY_PNG
#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#import "stb_image.h"
#import "stb_image_write.h"

#import <algorithm>

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
                CHECK_ZSTD(remaining);
                
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

void convert(unsigned char *ypbpr, unsigned int *abgr, int width, int height, int begin, int end) {
    
    unsigned char *u = ypbpr+(width*height);
    unsigned char *v = u+((width*height)>>2);

    for(int i=begin; i<end; i++) {
        
        unsigned char *y = ypbpr+i*width;
        unsigned char left = 0;
        
        for(int j=0; j<width; j++) {
            
            unsigned int pix = abgr[i*width+j];
            
            unsigned char r = (pix)&0xFF;
            unsigned char g = (pix>>8)&0xFF;
            unsigned char b = (pix>>16)&0xFF;
            
            int luma = ((218*r+732*g+74*b)>>10);
            
            y[j] = (luma-left)&0xFF;
            left = luma;
            
            if(!((i&1)&&(j&1))) {
                u[(i>>1)*(width>>1)+(j>>1)] = ((-118*r-394*g+512*b)>>10)+128;
                v[(i>>1)*(width>>1)+(j>>1)] = ((512*r-465*g-47*b)>>10)+128;
            }
        }
    }
}

dispatch_group_t group = dispatch_group_create();
dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0);

int main(int argc, const char **argv) {

    int nbThreads = 4;
    
    int info[3];
    unsigned int *image = (unsigned int *)stbi_load("./test.png",info,info+1,info+2,4);
        
    if(!image) return 0;
    
    unsigned short width = info[0];
    unsigned short height = info[1];
    
    unsigned int size = width*height+(((width*height)>>2)<<1);
    
    unsigned char *src = new unsigned char[size];
    unsigned char *bin = new unsigned char[size];
    unsigned char *ypbpr = new unsigned char[size];
    
    unsigned int *dst = new unsigned int[width*height];
    
    double then = CFAbsoluteTimeGetCurrent();
        
    int h = height>>2;
    
    for(int n=0; n<4; n++) {

        dispatch_group_async(group,queue,^{
            if(n==3) {
                convert(src,image,width,height,h*n,height);
            }
            else {
                convert(src,image,width,height,h*n,h*(n+1));
            }
        });
    }
    
    dispatch_group_wait(group,DISPATCH_TIME_FOREVER);
    
    unsigned int length = compress(bin,src,size,nbThreads);
    
    NSLog(@"%f %0.2fMB",CFAbsoluteTimeGetCurrent()-then,length/(1024.0*1024.0));

    if(length) {
        
        if(ZSTD_decompress(ypbpr,size,bin,length)) {
            
            unsigned char *y = ypbpr;
            unsigned char *u = y+(width*height);
            unsigned char *v = u+((width*height)>>2);

            for(int i=0; i<height; i++) {
                
                unsigned char left = 0;
                
                for(int j=0; j<width; j++) {
                    
                    left = (left+(*y++));
                    int luma = left<<10;
                    
                    unsigned int offset = (i>>1)*(width>>1)+(j>>1);
                    
                    int pb = u[offset]-128;
                    int pr = v[offset]-128;
                    
                    unsigned char r = std::clamp((luma+1612*pr)>>10,0,255);
                    unsigned char g = std::clamp((luma-191*pb-479*pr)>>10,0,255);
                    unsigned char b = std::clamp((luma+1901*pb)>>10,0,255);
                    
                    dst[i*width+j] = 0xFF000000|b<<16|g<<8|r;
                }
            }
            
            stbi_write_png("dst.png",width,height,4,(void const*)dst,width<<2);
        }
    }

    if(dst) {
        delete[] dst;
        dst = nullptr;
    }
    
    if(ypbpr) {
        delete[] ypbpr;
        ypbpr = nullptr;
    }
    
    if(bin) {
        delete[] bin;
        bin = nullptr;
    }
    
    if(src) {
        delete[] src;
        src = nullptr;
    }
    
    return 0;
}
