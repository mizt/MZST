namespace Event {

    NSString *SAVE_COMPLETE = @"SAVE_COMPLETE";
    NSString *RESET = @"RESET";

    std::vector<std::pair<NSString *,id>> events;

    void on(NSString *event, void (^callback)(NSNotification *)) {
                
        id observer = nil;
        
        long len = events.size();
        while(len--) {
            if(events[len].first&&[event compare:events[len].first]==NSOrderedSame) {
                observer = events[len].second;
                break;
            }
        }
        
        if(observer==nil) {
            id observer = [[NSNotificationCenter defaultCenter]
                addObserverForName:event
                object:nil
                queue:[NSOperationQueue mainQueue]
                usingBlock:callback
            ];
            
            events.push_back(std::make_pair(event,observer));
        }
        else {
            NSLog(@"%@ is already registered",event);
        }
    }

    void off(NSString *event) {
        
        id observer = nil;
        long len = events.size();
        while(len--) {
            if(events[len].first&&[event compare:events[len].first]==NSOrderedSame) {
                observer = events[len].second;
                events.erase(events.begin()+len);
                break;
            }
        }
        
        if(observer) {
            [[NSNotificationCenter defaultCenter] removeObserver:(id)observer];
            observer = nil;
        }
    }

    void emit(NSString *event) {
        [[NSNotificationCenter defaultCenter] postNotificationName:event object:nil];
    }
};

