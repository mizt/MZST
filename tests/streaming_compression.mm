#import <Foundation/Foundation.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "zstd.h"
#include "common.h"

static void compressFile_orDie(const char *fname, const char *outName, int cLevel, int nbThreads) {
  
    fprintf (stderr, "Starting compression of %s with level %d, using %d threads\n", fname, cLevel, nbThreads);

    // Open the input and output files.
    FILE *const fin  = fopen_orDie(fname,"rb");
    FILE *const fout = fopen_orDie(outName,"wb");
    /* 
      Create the input and output buffers.
      They may be any size, but we recommend using these functions to size them.
      Performance will only suffer significantly for very tiny buffers.
    */

    size_t const buffInSize = ZSTD_CStreamInSize();
    size_t const buffOutSize = ZSTD_CStreamOutSize();

    void *const buffIn = malloc_orDie(buffInSize);
    void *const buffOut = malloc_orDie(buffOutSize);

    // Create the context.
    ZSTD_CCtx *const cctx = ZSTD_createCCtx();
    CHECK(cctx!=NULL,"ZSTD_createCCtx() failed!");

    /* 
      Set any parameters you want.
      Here we set the compression level, and enable the checksum.
    */
    CHECK_ZSTD(ZSTD_CCtx_setParameter(cctx,ZSTD_c_compressionLevel,cLevel));
    CHECK_ZSTD(ZSTD_CCtx_setParameter(cctx,ZSTD_c_checksumFlag,1));
    ZSTD_CCtx_setParameter(cctx,ZSTD_c_nbWorkers,nbThreads);

    // This loop read from the input file, compresses that entire chunk, and writes all output produced to the output file.
    size_t const toRead = buffInSize;
    for (;;) {
        size_t read = fread_orDie(buffIn,toRead,fin);
        /* 
          Select the flush mode.
          If the read may not be finished (read == toRead) we use ZSTD_e_continue. If this is the last chunk, we use ZSTD_e_end.
          Zstd optimizes the case where the first flush mode is ZSTD_e_end, since it knows it is compressing the entire source in one pass.
        */
        int const lastChunk = (read<toRead);
        ZSTD_EndDirective const mode = lastChunk?ZSTD_e_end:ZSTD_e_continue;
        /* 
          Set the input buffer to what we just read.
          We compress until the input buffer is empty, each time flushing the output.
        */
        ZSTD_inBuffer input = { buffIn, read, 0 };
        int finished;
        do {
            /* 
              Compress into the output buffer and write all of the output to the file so we can reuse the buffer next iteration.
            */
            ZSTD_outBuffer output = { buffOut, buffOutSize, 0 };
            size_t const remaining = ZSTD_compressStream2(cctx,&output,&input,mode);
            CHECK_ZSTD(remaining);
            fwrite_orDie(buffOut,output.pos,fout);
            /* 
              If we're on the last chunk we're finished when zstd returns 0, which means its consumed all the input AND finished the frame.
              Otherwise, we're finished when we've consumed all the input.
            */
            finished = lastChunk?(remaining == 0):(input.pos==input.size);
        } while (!finished);
        CHECK(input.pos == input.size,"Impossible: zstd only returns 0 when the input is completely consumed!");

        if(lastChunk) break;
    }

    ZSTD_freeCCtx(cctx);
    fclose_orDie(fout);
    fclose_orDie(fin);
    free(buffIn);
    free(buffOut);
}

int main(int argc, const char **argv) {
    
    int cLevel = 1;
    int nbThreads = 1;
    
    double then = CFAbsoluteTimeGetCurrent();
    compressFile_orDie("./test.png","./test.zst",cLevel,nbThreads);
    NSLog(@"%f",CFAbsoluteTimeGetCurrent()-then);
    
    nbThreads = 4;
    
    then = CFAbsoluteTimeGetCurrent();
    compressFile_orDie("./test.png","./test.zst",cLevel,nbThreads);
    NSLog(@"%f",CFAbsoluteTimeGetCurrent()-then);
    
    return 0;
}
