//
//  ZHUniversalDBDataModel.h
//  iOSDataBaseSample
//
//  Created by 钟振华 on 2017/9/11.
//  Copyright © 2017年 Xinzhili. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZHUniversalDBDataModel : NSObject
/** 此字段不能为空 */
@property (nonatomic, copy) NSString *itemId;
@property (nonatomic, copy) NSString *json;
@property (nonatomic, copy) NSString *jsonClassName;
@property (nonatomic, copy) NSString *createdTime;
@property (nonatomic, copy) NSString *type;
/** 此字段不能为空必须指定一个值,无用可以指定@“0” */
@property (nonatomic, copy) NSString *position;
@property (nonatomic, copy) NSString *text1;
@property (nonatomic, copy) NSString *text2;
@property (nonatomic, copy) NSString *text3;

@end
