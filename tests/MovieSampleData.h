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