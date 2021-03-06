//
//  TLImageMessage.h
//  TLChat
//
//  Created by libokun on 16/3/28.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLMessage.h"

@interface TLImageMessage : TLMessage

@property (nonatomic, strong) NSString *thumbnailImageURL;          //  
@property (nonatomic, strong) NSString *thumbnailImagePath;         // 本地图片Path thumnnail
@property (nonatomic, strong) NSString *imagePath;                  // 本地图片Path
@property (nonatomic, strong) NSString *imageURL;                   // 网络图片URL
@property (nonatomic, strong) NSData *imageData;                    // easier to upload
@property (nonatomic, assign) CGSize imageSize;

@end
