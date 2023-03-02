#import <Foundation/Foundation.h>
#import <vector>

class MovieSampleData {
	
	private:
	
		unsigned long _offset = 0;
		unsigned int _length = 0;
	
		std::vector<bool> _keyframes;
		std::vector<unsigned long> _offsets;
		std::vector<unsigned int> _lengths;
		
	public:
	
		unsigned int length() { return this->_length; }
		unsigned long offset() { return this->_offset; };

		std::vector<bool> *keyframes() { return &this->_keyframes; }
		std::vector<unsigned long> *offsets() { return &this->_offsets; }
		std::vector<unsigned int> *lengths() { return &this->_lengths; };
		
		void writeData(NSFileHandle *handle, unsigned char *bytes, unsigned long length, bool keyframe) {
			this->_offsets.push_back(this->_offset+this->_length);
			this->_lengths.push_back(length);
			[handle writeData:[[NSData alloc] initWithBytes:bytes length:length]];
			[handle seekToEndOfFile];
			this->_length+=length;
			this->_keyframes.push_back(keyframe);
		}
	
		void writeSize(NSFileHandle *handle) {
			[handle seekToFileOffset:this->_offset];
			[handle writeData:[[NSData alloc] initWithBytes:new unsigned char[4]{
				(unsigned char)((this->_length>>24)&0xFF),
				(unsigned char)((this->_length>>16)&0xFF),
				(unsigned char)((this->_length>>8)&0xFF),
				(unsigned char)(this->_length&0xFF)} length:4]];
			[handle seekToEndOfFile];
		}
	
		MovieSampleData(NSFileHandle *handle, unsigned int offset) {
			this->_offset = offset;
			[handle writeData:[[NSData alloc] initWithBytes:new unsigned char[8]{0,0,0,0,'m','d','a','t'} length:8]];
			[handle seekToEndOfFile];
			this->_length+=8;
		}
	
		~MovieSampleData() {
			this->_keyframes.clear();
			this->_offsets.clear();
			this->_lengths.clear();
		}
};

unsigned long totalBytes = 0;

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