#import <Foundation/Foundation.h>
#import "../libs/MovieSampleData.h"

int main(int argc, char *argv[]) {
	@autoreleasepool {
		
		[[NSFileManager defaultManager] createFileAtPath:@"./test.bin" contents:nil attributes:nil];
		NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:@"./test.bin"];
		
		unsigned long offset = 0;
		
		std::vector<MovieSampleData *> mdat;
		
		if(mdat.size()==0) {
			mdat.push_back(new MovieSampleData(handle,offset));
		}
		
		int frame = 0;
		
		unsigned long length = 10;
		unsigned char *bytes = new unsigned char[length];
		
		const unsigned long MDAT_LIMIT = 50;
		
		for(int k=0; k<10; k++) {
			for(int n=0; n<length; n++) bytes[n] = k; 
			if(mdat[mdat.size()-1]->length()+length>=MDAT_LIMIT) {
				mdat[mdat.size()-1]->writeSize(handle);
				offset+=mdat[mdat.size()-1]->length();
				mdat.push_back(new MovieSampleData(handle,offset));
			}
			mdat[mdat.size()-1]->writeData(handle,bytes,length,true);
		}
		
		if(mdat.size()>=1) mdat[mdat.size()-1]->writeSize(handle);
	
		for(int k=0; k<mdat.size(); k++) {
			NSLog(@"length[] = %u",mdat[k]->length());
			std::vector<bool> *keyframes = mdat[k]->keyframes();
			std::vector<unsigned long> *offsets = mdat[k]->offsets();
			std::vector<unsigned int> *lengths = mdat[k]->lengths();
			
			if(keyframes->size()&&offsets->size()&&lengths->size()) {
				for(int n=0; n<offsets->size(); n++) {
					NSLog(@"%lu,%d",(*offsets)[n],(*lengths)[n]);
				}
			}
		}
		
		for(int k=0; k<mdat.size(); k++) {
			delete mdat[k];
		}
		
		mdat.clear();
	}
}