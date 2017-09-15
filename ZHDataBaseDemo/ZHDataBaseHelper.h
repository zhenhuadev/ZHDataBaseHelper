//
//  ZHDataBaseHelper.h
//  iOSDataBaseSample
//
//  Created by 钟振华 on 2017/9/11.
//  Copyright © 2017年 Xinzhili. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZHSingletonMacro.h"

@class ZHUniversalDBDataModel;

@interface ZHDataBaseHelper : NSObject

ZHSingletonInterface(ZHDataBaseHelper)

#pragma mark --> 数据库初始化操作API
/** 打开数据库 */
- (NSString *)openDataBaseWithUserName:(NSString *)userName;
/** 关闭数据库 */
- (void)close;

#pragma mark --> 数据库CRUD操作API
/** 创建一个表 */
- (void)createCustomTableWithName:(NSString *)tableName;
/** 清空表 */
- (void)cleanTable:(NSString *)tableName;

#pragma mark --> 1、增加和插入数据

/**
 插入一条通用型数据到某张表中
 @param universalData 通用型的数据模型
 @param tableName 表名
 */
- (BOOL)insertUniversalDataModel:(ZHUniversalDBDataModel *)universalData
                        toTable:(NSString *)tableName;

#pragma mark --> 2、删除数据
/**
 *  通过条件删除数据
 *  @param condition 类似于 "id＝xx and name=xx"
 *  @param tableName 表名
 */

- (BOOL)deleteUniversalDataByCondition:(NSString *)condition
                             fromTable:(NSString *)tableName;
/**
 删除指定主键id的数据
 @param dataId 主键
 @param tableName 表名称
 */
- (BOOL)deleteUniversalDataById:(NSString *)dataId
                      fromTable:(NSString *)tableName;

/**
 批量删除指定的 一组 主键ID 对应的数据
 @param dataIdsArray 主键id 数组
 @param tableName 表名
 */
- (BOOL)deleteUniversalDatasByIds:(NSArray *)dataIdsArray
                        fromTable:(NSString *)tableName;

/**
 清空表
 @param tableName 表名称
 */
- (BOOL)cleanAllDataForTable:(NSString *)tableName;

#pragma mark --> 3、更改和更新数据
/**
 更新一条数据到目标表里
 @param universalDataModel 通用数据模型
 除了itemID外 其他字段可以任意指定有值或没值，有值就更新，没值不会做任何操作
 @param tableName 表名称
 @return 是否成功
 */
- (BOOL)updateUniversalData:(ZHUniversalDBDataModel *)universalDataModel
                  intoTable:(NSString *)tableName;
#pragma mark --> 4、查找数据
/**
 *  根据某条id  查询某条数据  (返回的是ZHUniversalDBDataModel 模型)
 */
- (ZHUniversalDBDataModel *)searchOneUniversalDataModelById:(NSString *)itemId
                                                  fromTable:(NSString *)tableName;

/**
 查询出所有的通用型数据
 @param tableName 表名称
 @return ZHUniversalDBDataModel数组
 */
- (NSArray *)searchAllUniversalDataModelFromTable:(NSString *)tableName;
/**
 *  根据条件筛选
 *  @param searchCondition 筛选条件 比如 type = 1111 and id > 2 sql条件交给用户
 *  @param searchCount 如果为空默认是所有的数据
 *  @return 返回 这个表中的满足这个查询条件的 数据
 */
- (NSArray *)searchUniversalDataModelWithSearchCondition:(NSString *)searchCondition
                                             searchCount:(int)searchCount
                                               fromTable:(NSString *)tableName;

/** 执行查询SQL语句 */
- (NSArray *)searchUniversalDataModelsWithSQL:(NSString *)sql
                                fromTableName:(NSString *)tableName;

@end
